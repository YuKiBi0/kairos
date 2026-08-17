package store

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

func (s *Store) Snapshot(ctx context.Context, userID uuid.UUID) (Snapshot, error) {
	tx, err := s.pool.BeginTx(ctx, pgx.TxOptions{IsoLevel: pgx.RepeatableRead})
	if err != nil {
		return Snapshot{}, err
	}
	defer func() { _ = tx.Rollback(ctx) }()

	snapshot := Snapshot{}
	snapshot.Tasks, err = queryJSONList(
		ctx,
		tx,
		`SELECT (to_jsonb(task_row) - 'user_id' - 'field_versions') ||
		 jsonb_build_object(
		   'tag_ids', COALESCE((
		     SELECT jsonb_agg(tag_id ORDER BY tag_id)
		     FROM task_tags WHERE user_id=$1 AND task_id=task_row.id
		   ), '[]'::jsonb)
		 )
		 FROM tasks task_row
		 WHERE user_id=$1 AND deleted_at IS NULL
		 ORDER BY parent_id NULLS FIRST, sort_order, id`,
		userID,
	)
	if err != nil {
		return Snapshot{}, err
	}
	snapshot.Blockers, err = queryJSONList(
		ctx,
		tx,
		`SELECT to_jsonb(entity_row) - 'user_id' - 'field_versions'
		 FROM blockers entity_row
		 WHERE user_id=$1 AND deleted_at IS NULL
		 ORDER BY created_at, id`,
		userID,
	)
	if err != nil {
		return Snapshot{}, err
	}
	snapshot.Tags, err = queryJSONList(
		ctx,
		tx,
		`SELECT to_jsonb(entity_row) - 'user_id' - 'field_versions'
		 FROM tags entity_row WHERE user_id=$1 ORDER BY name, id`,
		userID,
	)
	if err != nil {
		return Snapshot{}, err
	}
	snapshot.Projects, err = queryJSONList(
		ctx,
		tx,
		`SELECT to_jsonb(entity_row) - 'user_id' - 'field_versions'
		 FROM projects entity_row WHERE user_id=$1 ORDER BY name, id`,
		userID,
	)
	if err != nil {
		return Snapshot{}, err
	}
	snapshot.ChecklistGroups, err = queryJSONList(
		ctx,
		tx,
		`SELECT to_jsonb(entity_row) - 'user_id' - 'field_versions'
		 FROM checklist_groups entity_row WHERE user_id=$1 ORDER BY name, id`,
		userID,
	)
	if err != nil {
		return Snapshot{}, err
	}
	if err := tx.QueryRow(
		ctx,
		`SELECT COALESCE(MAX(cursor), 0) FROM sync_changes WHERE user_id=$1`,
		userID,
	).Scan(&snapshot.Cursor); err != nil {
		return Snapshot{}, err
	}
	if err := tx.Commit(ctx); err != nil {
		return Snapshot{}, err
	}
	return snapshot, nil
}

func (s *Store) Changes(
	ctx context.Context,
	userID uuid.UUID,
	after int64,
	limit int,
) ([]SyncChange, int64, int64, bool, error) {
	tx, err := s.pool.BeginTx(ctx, pgx.TxOptions{IsoLevel: pgx.RepeatableRead})
	if err != nil {
		return nil, after, 0, false, err
	}
	defer func() { _ = tx.Rollback(ctx) }()

	var serverCursor int64
	if err := tx.QueryRow(
		ctx,
		`SELECT COALESCE(MAX(cursor), 0) FROM sync_changes WHERE user_id=$1`,
		userID,
	).Scan(&serverCursor); err != nil {
		return nil, after, 0, false, err
	}
	if after > serverCursor {
		if err := tx.Commit(ctx); err != nil {
			return nil, after, 0, false, err
		}
		return []SyncChange{}, after, serverCursor, false, nil
	}

	rows, err := tx.Query(
		ctx,
		`SELECT cursor,entity_type,entity_id,entity_version,deleted,entity
		 FROM sync_changes
		 WHERE user_id=$1 AND cursor>$2 AND cursor<=$3
		 ORDER BY cursor
		 LIMIT $4`,
		userID,
		after,
		serverCursor,
		limit+1,
	)
	if err != nil {
		return nil, after, 0, false, err
	}
	defer rows.Close()
	changes := make([]SyncChange, 0, limit+1)
	for rows.Next() {
		var change SyncChange
		var entity []byte
		if err := rows.Scan(
			&change.Cursor,
			&change.EntityType,
			&change.EntityID,
			&change.EntityVersion,
			&change.Deleted,
			&entity,
		); err != nil {
			return nil, after, 0, false, err
		}
		if !change.Deleted && len(entity) > 0 {
			change.Entity = json.RawMessage(entity)
		}
		changes = append(changes, change)
	}
	if err := rows.Err(); err != nil {
		return nil, after, 0, false, err
	}
	rows.Close()
	hasMore := len(changes) > limit
	if hasMore {
		changes = changes[:limit]
	}
	next := after
	if len(changes) > 0 {
		next = changes[len(changes)-1].Cursor
	}
	if err := tx.Commit(ctx); err != nil {
		return nil, after, 0, false, err
	}
	return changes, next, serverCursor, hasMore, nil
}

func (s *Store) ServerCursor(ctx context.Context, userID uuid.UUID) (int64, error) {
	var cursor int64
	err := s.pool.QueryRow(
		ctx,
		`SELECT COALESCE(MAX(cursor), 0) FROM sync_changes WHERE user_id=$1`,
		userID,
	).Scan(&cursor)
	return cursor, err
}

func queryJSONList(
	ctx context.Context,
	tx pgx.Tx,
	query string,
	arguments ...any,
) ([]json.RawMessage, error) {
	rows, err := tx.Query(ctx, query, arguments...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	result := make([]json.RawMessage, 0)
	for rows.Next() {
		var encoded []byte
		if err := rows.Scan(&encoded); err != nil {
			return nil, err
		}
		if !json.Valid(encoded) {
			return nil, fmt.Errorf("database returned invalid JSON")
		}
		result = append(result, json.RawMessage(encoded))
	}
	return result, rows.Err()
}
