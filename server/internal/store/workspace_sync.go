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

func (s *Store) taskVisibleForUserTx(
	ctx context.Context,
	tx pgx.Tx,
	userID, workspaceID, taskID uuid.UUID,
) (bool, error) {
	var visible bool
	err := tx.QueryRow(ctx, `
		SELECT EXISTS(
			SELECT 1
			FROM tasks task_row
			JOIN workspaces workspace ON workspace.id = task_row.workspace_id
			LEFT JOIN groups group_row ON group_row.id = workspace.group_id
			WHERE task_row.workspace_id=$1 AND task_row.id=$2
			  AND (
				 task_row.user_id=$3
				 OR task_row.shared_at IS NOT NULL
				 OR EXISTS(SELECT 1 FROM server_roles role
				           WHERE role.user_id=$3 AND role.role='L3' AND role.active)
			  )
		)`, workspaceID, taskID, userID).Scan(&visible)
	return visible, err
}

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
				JOIN group_accounts account ON account.id = link.group_account_id
				JOIN users member ON member.id = link.user_id AND member.disabled_at IS NULL
				WHERE link.group_id = group_row.id AND link.user_id = $2 AND link.unbound_at IS NULL AND account.active
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

func (s *Store) WorkspaceSnapshot(ctx context.Context, workspaceID uuid.UUID, viewerIDs ...uuid.UUID) (Snapshot, error) {
	tx, err := s.pool.BeginTx(ctx, pgx.TxOptions{IsoLevel: pgx.RepeatableRead})
	if err != nil {
		return Snapshot{}, err
	}
	defer func() { _ = tx.Rollback(ctx) }()
	snapshot := Snapshot{}
	viewerID := uuid.Nil
	if len(viewerIDs) > 0 {
		viewerID = viewerIDs[0]
	}
	snapshot.Tasks, err = queryJSONList(ctx, tx, `
		SELECT (to_jsonb(task_row) - 'user_id' - 'workspace_id' - 'field_versions') ||
			jsonb_build_object('tag_ids', COALESCE((
				SELECT jsonb_agg(tag_id ORDER BY tag_id) FROM task_tags
				WHERE workspace_id = $1 AND task_id = task_row.id
			), '[]'::jsonb))
		FROM tasks task_row WHERE workspace_id = $1 AND deleted_at IS NULL
		  AND ($2 = $3::uuid OR task_row.user_id = $2 OR task_row.shared_at IS NOT NULL OR EXISTS(
			SELECT 1 FROM server_roles role WHERE role.user_id=$2 AND role.role='L3' AND role.active
		  ))
		ORDER BY parent_id NULLS FIRST, sort_order, id`, workspaceID, viewerID, uuid.Nil)
	if err != nil {
		return Snapshot{}, err
	}
	snapshot.Blockers, err = queryJSONList(ctx, tx, `
		SELECT to_jsonb(entity_row) - 'user_id' - 'workspace_id' - 'field_versions'
		FROM blockers entity_row WHERE workspace_id = $1 AND deleted_at IS NULL
		  AND ($2 = $3::uuid OR EXISTS(
			SELECT 1 FROM tasks task_row
			WHERE task_row.workspace_id=$1 AND task_row.id=entity_row.task_id
			  AND (task_row.user_id=$2 OR task_row.shared_at IS NOT NULL OR EXISTS(
				SELECT 1 FROM server_roles role WHERE role.user_id=$2 AND role.role='L3' AND role.active
			  ))
		  ))
		ORDER BY created_at, id`, workspaceID, viewerID, uuid.Nil)
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

func (s *Store) WorkspaceChanges(ctx context.Context, workspaceID uuid.UUID, after int64, limit int, viewerIDs ...uuid.UUID) ([]SyncChange, int64, int64, bool, error) {
	if limit < 1 || limit > 200 {
		return nil, after, 0, false, fmt.Errorf("limit must be between 1 and 200")
	}
	viewerID := uuid.Nil
	if len(viewerIDs) > 0 {
		viewerID = viewerIDs[0]
	}
	var serverCursor int64
	if err := s.pool.QueryRow(ctx, `SELECT COALESCE(MAX(cursor), 0) FROM sync_changes WHERE workspace_id = $1`, workspaceID).Scan(&serverCursor); err != nil {
		return nil, after, 0, false, err
	}
	if after > serverCursor {
		return []SyncChange{}, after, serverCursor, false, nil
	}
	rows, err := s.pool.Query(ctx, `
		SELECT cursor, entity_type, entity_id, entity_version,
		       CASE WHEN $4 = $5::uuid THEN deleted
		            WHEN entity_type = 'task' AND NOT EXISTS(
		              SELECT 1 FROM tasks task_row
		              WHERE task_row.workspace_id=$1 AND task_row.id=sync_changes.entity_id
		                AND (task_row.user_id=$4 OR task_row.shared_at IS NOT NULL OR EXISTS(
		                  SELECT 1 FROM server_roles role WHERE role.user_id=$4 AND role.role='L3' AND role.active
		                ))
		            ) THEN true
		            WHEN entity_type = 'blocker' AND NOT EXISTS(
		              SELECT 1 FROM blockers blocker_row
		              JOIN tasks task_row ON task_row.workspace_id=blocker_row.workspace_id AND task_row.id=blocker_row.task_id
		              WHERE blocker_row.workspace_id=$1 AND blocker_row.id=sync_changes.entity_id
		                AND (task_row.user_id=$4 OR task_row.shared_at IS NOT NULL OR EXISTS(
		                  SELECT 1 FROM server_roles role WHERE role.user_id=$4 AND role.role='L3' AND role.active
		                ))
		            ) THEN true
		            ELSE deleted END AS deleted,
		       CASE WHEN $4 = $5::uuid THEN entity
		            WHEN entity_type IN ('task', 'blocker') AND (
		              (entity_type='task' AND NOT EXISTS(
		                SELECT 1 FROM tasks task_row
		                WHERE task_row.workspace_id=$1 AND task_row.id=sync_changes.entity_id
		                  AND (task_row.user_id=$4 OR task_row.shared_at IS NOT NULL OR EXISTS(
		                    SELECT 1 FROM server_roles role WHERE role.user_id=$4 AND role.role='L3' AND role.active
		                  ))
		              )) OR
		              (entity_type='blocker' AND NOT EXISTS(
		                SELECT 1 FROM blockers blocker_row
		                JOIN tasks task_row ON task_row.workspace_id=blocker_row.workspace_id AND task_row.id=blocker_row.task_id
		                WHERE blocker_row.workspace_id=$1 AND blocker_row.id=sync_changes.entity_id
		                  AND (task_row.user_id=$4 OR task_row.shared_at IS NOT NULL OR EXISTS(
		                    SELECT 1 FROM server_roles role WHERE role.user_id=$4 AND role.role='L3' AND role.active
		                  ))
		              ))
		            ) THEN NULL ELSE entity END AS entity
		FROM sync_changes WHERE workspace_id = $1 AND cursor > $2
		ORDER BY cursor LIMIT $3`, workspaceID, after, limit+1, viewerID, uuid.Nil)
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
