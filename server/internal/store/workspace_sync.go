package store

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

var ErrWorkspaceForbidden = errors.New("workspace operation forbidden")

func (s *Store) WorkspaceForUser(ctx context.Context, userID, workspaceID uuid.UUID) (Workspace, error) {
	var workspace Workspace
	err := s.pool.QueryRow(ctx, `
		SELECT workspace.id, workspace.kind, workspace.owner_user_id, workspace.group_id, workspace.created_at
		FROM workspaces workspace
		LEFT JOIN groups group_row ON group_row.id = workspace.group_id
		WHERE workspace.id = $1 AND (
			workspace.owner_user_id = $2
			OR EXISTS (
				SELECT 1 FROM group_account_links link
				WHERE link.group_id = group_row.id AND link.user_id = $2 AND link.unbound_at IS NULL
			)
			OR EXISTS (
				SELECT 1 FROM server_roles role
				WHERE role.user_id = $2 AND role.role = 'L3' AND role.active
			)
		)`, workspaceID, userID,
	).Scan(&workspace.ID, &workspace.Kind, &workspace.OwnerUserID, &workspace.GroupID, &workspace.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return Workspace{}, ErrWorkspaceForbidden
	}
	if err != nil {
		return Workspace{}, err
	}
	return workspace, nil
}

func (s *Store) WorkspaceSnapshot(ctx context.Context, workspaceID uuid.UUID) (Snapshot, error) {
	tx, err := s.pool.BeginTx(ctx, pgx.TxOptions{IsoLevel: pgx.RepeatableRead})
	if err != nil {
		return Snapshot{}, err
	}
	defer func() { _ = tx.Rollback(ctx) }()
	snapshot := Snapshot{}
	snapshot.Tasks, err = queryJSONList(ctx, tx, `
		SELECT (to_jsonb(task_row) - 'user_id' - 'workspace_id' - 'field_versions') ||
			jsonb_build_object('tag_ids', COALESCE((
				SELECT jsonb_agg(tag_id ORDER BY tag_id) FROM task_tags
				WHERE workspace_id = $1 AND task_id = task_row.id
			), '[]'::jsonb))
		FROM tasks task_row WHERE workspace_id = $1 AND deleted_at IS NULL
		ORDER BY parent_id NULLS FIRST, sort_order, id`, workspaceID)
	if err != nil {
		return Snapshot{}, err
	}
	snapshot.Blockers, err = queryJSONList(ctx, tx, `
		SELECT to_jsonb(entity_row) - 'user_id' - 'workspace_id' - 'field_versions'
		FROM blockers entity_row WHERE workspace_id = $1 AND deleted_at IS NULL
		ORDER BY created_at, id`, workspaceID)
	if err != nil {
		return Snapshot{}, err
	}
	snapshot.Tags, err = queryJSONList(ctx, tx, `
		SELECT to_jsonb(entity_row) - 'user_id' - 'workspace_id' - 'field_versions'
		FROM tags entity_row WHERE workspace_id = $1 ORDER BY name, id`, workspaceID)
	if err != nil {
		return Snapshot{}, err
	}
	snapshot.Projects, err = queryJSONList(ctx, tx, `
		SELECT to_jsonb(entity_row) - 'user_id' - 'workspace_id' - 'field_versions'
		FROM projects entity_row WHERE workspace_id = $1 ORDER BY name, id`, workspaceID)
	if err != nil {
		return Snapshot{}, err
	}
	snapshot.ChecklistGroups, err = queryJSONList(ctx, tx, `
		SELECT to_jsonb(entity_row) - 'user_id' - 'workspace_id' - 'field_versions'
		FROM checklist_groups entity_row WHERE workspace_id = $1 ORDER BY name, id`, workspaceID)
	if err != nil {
		return Snapshot{}, err
	}
	if err := tx.QueryRow(ctx, `SELECT COALESCE(MAX(cursor), 0) FROM sync_changes WHERE workspace_id = $1`, workspaceID).Scan(&snapshot.Cursor); err != nil {
		return Snapshot{}, err
	}
	if err := tx.Commit(ctx); err != nil {
		return Snapshot{}, err
	}
	return snapshot, nil
}

func (s *Store) WorkspaceChanges(ctx context.Context, workspaceID uuid.UUID, after int64, limit int) ([]SyncChange, int64, int64, bool, error) {
	if limit < 1 || limit > 200 {
		return nil, after, 0, false, fmt.Errorf("limit must be between 1 and 200")
	}
	var serverCursor int64
	if err := s.pool.QueryRow(ctx, `SELECT COALESCE(MAX(cursor), 0) FROM sync_changes WHERE workspace_id = $1`, workspaceID).Scan(&serverCursor); err != nil {
		return nil, after, 0, false, err
	}
	if after > serverCursor {
		return []SyncChange{}, after, serverCursor, false, nil
	}
	rows, err := s.pool.Query(ctx, `
		SELECT cursor, entity_type, entity_id, entity_version, deleted, entity
		FROM sync_changes WHERE workspace_id = $1 AND cursor > $2
		ORDER BY cursor LIMIT $3`, workspaceID, after, limit+1)
	if err != nil {
		return nil, after, serverCursor, false, err
	}
	defer rows.Close()
	changes := make([]SyncChange, 0, limit)
	for rows.Next() {
		var change SyncChange
		var encoded []byte
		if err := rows.Scan(&change.Cursor, &change.EntityType, &change.EntityID, &change.EntityVersion, &change.Deleted, &encoded); err != nil {
			return nil, after, serverCursor, false, err
		}
		if len(encoded) > 0 && json.Valid(encoded) {
			change.Entity = json.RawMessage(encoded)
		}
		changes = append(changes, change)
	}
	if err := rows.Err(); err != nil {
		return nil, after, serverCursor, false, err
	}
	hasMore := len(changes) > limit
	if hasMore {
		changes = changes[:limit]
	}
	next := after
	if len(changes) > 0 {
		next = changes[len(changes)-1].Cursor
	}
	return changes, next, serverCursor, hasMore, nil
}
