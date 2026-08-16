package store

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

func (s *Store) TaskEntity(
	ctx context.Context,
	userID, taskID uuid.UUID,
) (json.RawMessage, error) {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer func() { _ = tx.Rollback(ctx) }()
	entity, err := s.taskJSON(ctx, tx, userID, taskID)
	if err != nil {
		return nil, err
	}
	if err := tx.Commit(ctx); err != nil {
		return nil, err
	}
	return entity, nil
}

func (s *Store) TaskDescendants(
	ctx context.Context,
	userID, taskID uuid.UUID,
	depthLimit int,
) ([]json.RawMessage, error) {
	if depthLimit < 1 || depthLimit > 5 {
		return nil, errors.New("depth limit must be between 1 and 5")
	}
	rows, err := s.pool.Query(
		ctx,
		`WITH RECURSIVE descendants AS (
		   SELECT child.*, 1 AS relative_depth
		   FROM tasks child
		   WHERE child.user_id=$1 AND child.parent_id=$2 AND child.deleted_at IS NULL
		   UNION ALL
		   SELECT child.*, parent.relative_depth+1
		   FROM tasks child
		   JOIN descendants parent ON child.parent_id=parent.id
		   WHERE child.user_id=$1 AND child.deleted_at IS NULL
		     AND parent.relative_depth < $3
		 )
		 SELECT (to_jsonb(descendants) - 'user_id' - 'field_versions' - 'relative_depth') ||
		 jsonb_build_object(
		   'tag_ids', COALESCE((
		     SELECT jsonb_agg(tag_id ORDER BY tag_id)
		     FROM task_tags WHERE user_id=$1 AND task_id=descendants.id
		   ), '[]'::jsonb)
		 )
		 FROM descendants
		 ORDER BY depth, parent_id, sort_order, id`,
		userID,
		taskID,
		depthLimit,
	)
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
		result = append(result, json.RawMessage(encoded))
	}
	return result, rows.Err()
}

func (s *Store) TaxonomyEntities(
	ctx context.Context,
	userID uuid.UUID,
	entityType string,
) ([]json.RawMessage, error) {
	table := ""
	switch entityType {
	case "tag":
		table = "tags"
	case "project":
		table = "projects"
	case "checklist_group":
		table = "checklist_groups"
	default:
		return nil, errors.New("unsupported taxonomy entity")
	}
	query := fmt.Sprintf(
		`SELECT to_jsonb(entity_row) - 'user_id' - 'field_versions'
		 FROM %s entity_row WHERE user_id=$1 ORDER BY name,id`,
		table,
	)
	rows, err := s.pool.Query(ctx, query, userID)
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
		result = append(result, json.RawMessage(encoded))
	}
	return result, rows.Err()
}

func IsMissingEntity(err error) bool {
	return errors.Is(err, pgx.ErrNoRows)
}
