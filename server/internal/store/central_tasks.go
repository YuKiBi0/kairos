package store

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

var (
	ErrCentralForbidden           = errors.New("central delegation is forbidden")
	ErrCentralTargetNotMember     = errors.New("target user is not an active group member")
	ErrCentralWorkspace           = errors.New("workspace does not belong to group")
	ErrCentralGroupArchived       = errors.New("group is archived")
	ErrCentralIdempotencyConflict = errors.New("idempotency key belongs to another operator")
)

type CentralTask struct {
	Task      json.RawMessage `json:"task"`
	Duplicate bool            `json:"duplicate,omitempty"`
	RequestID string          `json:"request_id,omitempty"`
}

// CreateCentralTask creates a group task on behalf of a target member. The
// actor remains the last operator, while ownership and creation are attributed
// to targetUserID. operationID is also the idempotency key.
func (s *Store) CreateCentralTask(
	ctx context.Context,
	actorID, deviceID, groupID, workspaceID, targetUserID, operationID uuid.UUID,
	title string, description *string, quadrant int16, agentID string,
) (CentralTask, error) {
	title = strings.TrimSpace(title)
	if title == "" || len([]rune(title)) > 200 {
		return CentralTask{}, errors.New("task title must contain 1 to 200 characters")
	}
	if quadrant == 0 {
		quadrant = 2
	}
	if quadrant < 1 || quadrant > 4 {
		return CentralTask{}, errors.New("task quadrant must be between 1 and 4")
	}
	if operationID == uuid.Nil {
		return CentralTask{}, errors.New("idempotency key is required")
	}
	tx, err := s.pool.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return CentralTask{}, err
	}
	defer func() { _ = tx.Rollback(ctx) }()
	// Serialize requests sharing an idempotency key so concurrent retries cannot
	// create two tasks before the unique sync_operations row is written.
	if _, err := tx.Exec(ctx, `SELECT pg_advisory_xact_lock(hashtextextended($1::text, 0))`, operationID.String()); err != nil {
		return CentralTask{}, err
	}
	var isL3 bool
	if err := tx.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM server_roles WHERE user_id=$1 AND role='L3' AND active)`, actorID).Scan(&isL3); err != nil {
		return CentralTask{}, err
	}
	if !isL3 {
		return CentralTask{}, ErrCentralForbidden
	}
	var previous []byte
	var previousActor uuid.UUID
	err = tx.QueryRow(ctx, `SELECT user_id, result FROM sync_operations WHERE workspace_id=$1 AND operation_id=$2`, workspaceID, operationID).Scan(&previousActor, &previous)
	if err == nil {
		if previousActor != actorID {
			return CentralTask{}, ErrCentralIdempotencyConflict
		}
		var result CentralTask
		if err := json.Unmarshal(previous, &result); err != nil {
			return CentralTask{}, fmt.Errorf("decode idempotent result: %w", err)
		}
		result.Duplicate = true
		return result, nil
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return CentralTask{}, err
	}
	var kind string
	var actualGroup *uuid.UUID
	if err := tx.QueryRow(ctx, `SELECT kind, group_id FROM workspaces WHERE id=$1 FOR SHARE`, workspaceID).Scan(&kind, &actualGroup); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return CentralTask{}, ErrCentralWorkspace
		}
		return CentralTask{}, err
	}
	if kind != "group" || actualGroup == nil || *actualGroup != groupID {
		return CentralTask{}, ErrCentralWorkspace
	}
	var archived bool
	if err := tx.QueryRow(ctx, `SELECT archived FROM groups WHERE id=$1 FOR UPDATE`, groupID).Scan(&archived); err != nil {
		return CentralTask{}, err
	}
	if archived {
		return CentralTask{}, ErrCentralGroupArchived
	}
	var accountID uuid.UUID
	err = tx.QueryRow(ctx, `
		SELECT link.group_account_id
		FROM group_account_links link
		JOIN group_accounts account ON account.id=link.group_account_id AND account.active
		JOIN users member ON member.id=link.user_id AND member.disabled_at IS NULL
		WHERE link.group_id=$1 AND link.user_id=$2 AND link.unbound_at IS NULL
		ORDER BY link.bound_at DESC LIMIT 1`, groupID, targetUserID).Scan(&accountID)
	if errors.Is(err, pgx.ErrNoRows) {
		return CentralTask{}, ErrCentralTargetNotMember
	}
	if err != nil {
		return CentralTask{}, err
	}
	now := time.Now().UTC()
	taskID := uuid.New()
	fieldVersions, _ := json.Marshal(map[string]int64{"title": 1, "description": 1, "quadrant": 1})
	var sortOrder int32
	if err := tx.QueryRow(ctx, `SELECT COALESCE(MAX(sort_order), -1)+1 FROM tasks WHERE workspace_id=$1 AND parent_id IS NULL`, workspaceID).Scan(&sortOrder); err != nil {
		return CentralTask{}, err
	}
	_, err = tx.Exec(ctx, `
		INSERT INTO tasks(
			id,user_id,workspace_id,group_account_id,created_by_user_id,last_operated_by_user_id,
			parent_id,title,description,quadrant,status,due_at,depth,sort_order,project_id,
			checklist_group_id,version,field_versions,deleted_at,created_at,updated_at,completed_at,shared_at,updated_by_device_id
		) VALUES($1,$2,$3,$4,$5,$6,NULL,$7,$8,$9,0,NULL,1,$10,NULL,NULL,1,$11,NULL,$12,$12,NULL,NULL,$13)`,
		taskID, targetUserID, workspaceID, accountID, targetUserID, actorID, title, description,
		quadrant, sortOrder, fieldVersions, now, deviceID)
	if err != nil {
		return CentralTask{}, err
	}
	entity, err := s.taskJSON(ctx, tx, workspaceID, taskID)
	if err != nil {
		return CentralTask{}, err
	}
	if _, err := recordChange(ctx, tx, targetUserID, workspaceID, "task", taskID, 1, false, entity); err != nil {
		return CentralTask{}, err
	}
	details, _ := json.Marshal(map[string]any{
		"central_operator_user_id": actorID,
		"target_user_id":           targetUserID,
		"workspace_id":             workspaceID,
		"agent_id":                 strings.TrimSpace(agentID),
		"idempotency_key":          operationID,
	})
	if _, err := tx.Exec(ctx, `INSERT INTO audit_events(id,actor_user_id,group_id,action,target_type,target_id,outcome,request_id,details) VALUES($1,$2,$3,'central.task.create','task',$4,'success',$5,$6)`, uuid.New(), actorID, groupID, taskID, auditRequestID(ctx), details); err != nil {
		return CentralTask{}, err
	}
	result := CentralTask{Task: entity, RequestID: auditRequestID(ctx)}
	encoded, _ := json.Marshal(result)
	if _, err := tx.Exec(ctx, `INSERT INTO sync_operations(user_id,workspace_id,operation_id,result) VALUES($1,$2,$3,$4)`, actorID, workspaceID, operationID, encoded); err != nil {
		return CentralTask{}, err
	}
	if err := tx.Commit(ctx); err != nil {
		return CentralTask{}, err
	}
	return result, nil
}
