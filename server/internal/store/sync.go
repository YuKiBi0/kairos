package store

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"sort"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/YuKiBi0/kairos/server/internal/tasks"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

type operationRejection struct {
	code    string
	message string
}

func (e operationRejection) Error() string { return e.message }

func (s *Store) ApplyOperation(
	ctx context.Context,
	userID, deviceID uuid.UUID,
	operation PushOperation,
) (OperationResult, error) {
	workspaceID, err := s.personalWorkspaceID(ctx, userID)
	if err != nil {
		return OperationResult{}, err
	}
	return s.ApplyWorkspaceOperation(ctx, userID, deviceID, workspaceID, operation)
}

func (s *Store) ApplyWorkspaceOperation(
	ctx context.Context,
	userID, deviceID, workspaceID uuid.UUID,
	operation PushOperation,
) (OperationResult, error) {
	base := OperationResult{
		OperationID: operation.OperationID,
		EntityType:  operation.EntityType,
		EntityID:    operation.EntityID,
	}
	if operation.OperationID == uuid.Nil || operation.EntityID == uuid.Nil {
		base.Status = "rejected"
		base.Code = "VALIDATION_ERROR"
		base.Message = "operation_id and entity_id are required"
		return base, nil
	}
	tx, err := s.pool.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return OperationResult{}, err
	}
	defer func() { _ = tx.Rollback(ctx) }()

	var previous []byte
	err = tx.QueryRow(
		ctx,
		`SELECT result FROM sync_operations
		 WHERE workspace_id = $1 AND operation_id = $2`,
		workspaceID,
		operation.OperationID,
	).Scan(&previous)
	if err == nil {
		var result OperationResult
		if err := json.Unmarshal(previous, &result); err != nil {
			return OperationResult{}, fmt.Errorf("decode idempotent result: %w", err)
		}
		result.Status = "duplicate"
		return result, nil
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return OperationResult{}, err
	}

	var result OperationResult
	switch operation.EntityType {
	case "task":
		result, err = s.applyTaskOperation(ctx, tx, userID, deviceID, workspaceID, operation)
	case "blocker":
		result, err = s.applyBlockerOperation(ctx, tx, userID, workspaceID, operation)
	case "tag", "project", "checklist_group":
		result, err = s.applyTaxonomyOperation(ctx, tx, userID, workspaceID, operation)
	default:
		result = base
		result.Status = "rejected"
		result.Code = "UNSUPPORTED_ENTITY"
		result.Message = "unsupported entity type"
	}
	if err != nil {
		var rejected operationRejection
		if errors.As(err, &rejected) {
			result = base
			result.Status = "rejected"
			result.Code = rejected.code
			result.Message = rejected.message
		} else {
			return OperationResult{}, err
		}
	}
	encoded, err := json.Marshal(result)
	if err != nil {
		return OperationResult{}, err
	}
	if _, err := tx.Exec(
		ctx,
		`INSERT INTO sync_operations(user_id, workspace_id, operation_id, result)
		 VALUES($1, $2, $3, $4)`,
		userID,
		workspaceID,
		operation.OperationID,
		encoded,
	); err != nil {
		return OperationResult{}, err
	}
	if err := tx.Commit(ctx); err != nil {
		return OperationResult{}, err
	}
	return result, nil
}

type taskRecord struct {
	ID               uuid.UUID
	OwnerUserID      uuid.UUID
	GroupAccountID   *uuid.UUID
	CreatedByUserID  uuid.UUID
	LastOperatorID   uuid.UUID
	ParentID         *uuid.UUID
	Title            string
	Description      *string
	Quadrant         int16
	Status           int16
	DueAt            *time.Time
	Depth            int16
	SortOrder        int32
	ProjectID        *uuid.UUID
	ChecklistGroupID *uuid.UUID
	Version          int64
	FieldVersions    map[string]int64
	DeletedAt        *time.Time
	CreatedAt        time.Time
	UpdatedAt        time.Time
	CompletedAt      *time.Time
	SharedAt         *time.Time
	UpdatedByDevice  uuid.UUID
	TagIDs           []uuid.UUID
}

type rowScanner interface {
	Scan(dest ...any) error
}

func scanTask(row rowScanner) (taskRecord, error) {
	var task taskRecord
	var fieldVersions []byte
	err := row.Scan(
		&task.ID,
		&task.OwnerUserID,
		&task.GroupAccountID,
		&task.CreatedByUserID,
		&task.LastOperatorID,
		&task.ParentID,
		&task.Title,
		&task.Description,
		&task.Quadrant,
		&task.Status,
		&task.DueAt,
		&task.Depth,
		&task.SortOrder,
		&task.ProjectID,
		&task.ChecklistGroupID,
		&task.Version,
		&fieldVersions,
		&task.DeletedAt,
		&task.CreatedAt,
		&task.UpdatedAt,
		&task.CompletedAt,
		&task.SharedAt,
		&task.UpdatedByDevice,
	)
	if err != nil {
		return taskRecord{}, err
	}
	task.FieldVersions = make(map[string]int64)
	if err := json.Unmarshal(fieldVersions, &task.FieldVersions); err != nil {
		return taskRecord{}, err
	}
	return task, nil
}

func (s *Store) applyTaskOperation(
	ctx context.Context,
	tx pgx.Tx,
	userID, deviceID, workspaceID uuid.UUID,
	operation PushOperation,
) (OperationResult, error) {
	current, err := scanTask(tx.QueryRow(
		ctx,
		`SELECT id, user_id, group_account_id, created_by_user_id, last_operated_by_user_id,
		        parent_id, title, description, quadrant, status, due_at,
		        depth, sort_order, project_id, checklist_group_id, version,
		        field_versions, deleted_at, created_at, updated_at, completed_at,
		        shared_at, updated_by_device_id
		 FROM tasks
			 WHERE workspace_id = $1 AND id = $2
			 FOR UPDATE`,
		workspaceID,
		operation.EntityID,
	))
	creating := errors.Is(err, pgx.ErrNoRows)
	if err != nil && !creating {
		return OperationResult{}, err
	}
	if creating {
		if operation.BaseVersion != 0 {
			return OperationResult{}, operationRejection{"MISSING_ENTITY", "task does not exist"}
		}
		now := time.Now().UTC()
		current = taskRecord{
			ID:              operation.EntityID,
			OwnerUserID:     userID,
			CreatedByUserID: userID,
			LastOperatorID:  userID,
			Quadrant:        2,
			Status:          0,
			Depth:           1,
			Version:         0,
			FieldVersions:   make(map[string]int64),
			CreatedAt:       now,
			UpdatedAt:       now,
			UpdatedByDevice: deviceID,
		}
		if err := s.authorizeTaskOperation(ctx, tx, userID, workspaceID, current, operation, true); err != nil {
			return OperationResult{}, err
		}
	} else {
		if err := s.authorizeTaskOperation(ctx, tx, userID, workspaceID, current, operation, false); err != nil {
			return OperationResult{}, err
		}
		entity, err := s.taskJSON(ctx, tx, workspaceID, current.ID)
		if err != nil {
			return OperationResult{}, err
		}
		conflicts := conflictingFields(current.Version, current.FieldVersions, operation)
		if len(conflicts) > 0 {
			return OperationResult{
				OperationID:       operation.OperationID,
				Status:            "conflict",
				EntityType:        operation.EntityType,
				EntityID:          operation.EntityID,
				Version:           current.Version,
				ConflictingFields: conflicts,
				ServerEntity:      entity,
			}, nil
		}
	}
	if creating {
		current.GroupAccountID, err = s.activeGroupAccountForUserTx(ctx, tx, userID, workspaceID)
		if err != nil {
			return OperationResult{}, err
		}
	}
	changedFields := normalizedChangedFields(operation)
	if creating && len(changedFields) == 0 {
		return OperationResult{}, operationRejection{"VALIDATION_ERROR", "task changes are required"}
	}
	oldParentID := current.ParentID
	for _, field := range changedFields {
		if err := applyTaskField(&current, field, operation.Changes[field]); err != nil {
			return OperationResult{}, operationRejection{"VALIDATION_ERROR", err.Error()}
		}
	}
	if strings.TrimSpace(current.Title) == "" || utf8.RuneCountInString(current.Title) > 200 {
		return OperationResult{}, operationRejection{"VALIDATION_ERROR", "task title must contain 1 to 200 characters"}
	}
	if current.Quadrant < 1 || current.Quadrant > 4 || current.Status < 0 || current.Status > 3 {
		return OperationResult{}, operationRejection{"VALIDATION_ERROR", "task enum value is invalid"}
	}
	if err := s.validateOwnedReference(ctx, tx, "projects", workspaceID, current.ProjectID); err != nil {
		return OperationResult{}, err
	}
	if err := s.validateOwnedReference(ctx, tx, "checklist_groups", workspaceID, current.ChecklistGroupID); err != nil {
		return OperationResult{}, err
	}
	if current.ParentID != nil {
		visible, err := s.taskVisibleForUserTx(ctx, tx, userID, workspaceID, *current.ParentID)
		if err != nil {
			return OperationResult{}, err
		}
		if !visible {
			return OperationResult{}, operationRejection{"INVALID_PARENT", "parent task is not visible to this member"}
		}
	}

	nodes, err := s.taskNodes(ctx, tx, workspaceID)
	if err != nil {
		return OperationResult{}, err
	}
	parentValue := ""
	if current.ParentID != nil {
		parentValue = current.ParentID.String()
	}
	depthDelta := 0
	if creating {
		depth, err := tasks.DepthForNewTask(nodes, parentValue)
		if err != nil {
			return OperationResult{}, treeRejection(err)
		}
		current.Depth = int16(depth)
	} else if !sameUUID(oldParentID, current.ParentID) {
		depth, delta, err := tasks.ValidateMove(nodes, current.ID.String(), parentValue)
		if err != nil {
			return OperationResult{}, treeRejection(err)
		}
		current.Depth = int16(depth)
		depthDelta = delta
	}

	newVersion := current.Version + 1
	current.Version = newVersion
	current.UpdatedAt = time.Now().UTC()
	current.UpdatedByDevice = deviceID
	if current.Status == 2 && current.CompletedAt == nil {
		completed := current.UpdatedAt
		current.CompletedAt = &completed
	}
	if current.Status != 2 {
		current.CompletedAt = nil
	}
	for _, field := range changedFields {
		current.FieldVersions[field] = newVersion
	}
	current.FieldVersions["updated_at"] = newVersion
	fieldVersions, err := json.Marshal(current.FieldVersions)
	if err != nil {
		return OperationResult{}, err
	}
	if creating {
		_, err = tx.Exec(
			ctx,
			`INSERT INTO tasks(
			   id, user_id, workspace_id, group_account_id, created_by_user_id,
			   last_operated_by_user_id, parent_id, title, description, quadrant, status,
			   due_at, depth, sort_order, project_id, checklist_group_id,
			   version, field_versions, deleted_at, created_at, updated_at,
			   completed_at, shared_at, updated_by_device_id
			 ) VALUES(
			   $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20,$21,$22,$23,$24
			 )`,
			current.ID, userID, workspaceID, current.GroupAccountID, current.CreatedByUserID,
			current.LastOperatorID, current.ParentID, current.Title, current.Description,
			current.Quadrant, current.Status, current.DueAt, current.Depth,
			current.SortOrder, current.ProjectID, current.ChecklistGroupID,
			current.Version, fieldVersions, current.DeletedAt, current.CreatedAt,
			current.UpdatedAt, current.CompletedAt, current.SharedAt, current.UpdatedByDevice,
		)
	} else {
		_, err = tx.Exec(
			ctx,
			`UPDATE tasks SET
			   parent_id=$3, title=$4, description=$5, quadrant=$6, status=$7,
			   due_at=$8, depth=$9, sort_order=$10, project_id=$11,
			   checklist_group_id=$12, version=$13, field_versions=$14,
			   deleted_at=$15, updated_at=$16, completed_at=$17,
			   shared_at=$18, updated_by_device_id=$19, last_operated_by_user_id=$20
				 WHERE workspace_id=$1 AND id=$2`,
			workspaceID, current.ID, current.ParentID, current.Title, current.Description,
			current.Quadrant, current.Status, current.DueAt, current.Depth,
			current.SortOrder, current.ProjectID, current.ChecklistGroupID,
			current.Version, fieldVersions, current.DeletedAt, current.UpdatedAt,
			current.CompletedAt, current.SharedAt, current.UpdatedByDevice, userID,
		)
	}
	if err != nil {
		return OperationResult{}, err
	}
	if depthDelta != 0 {
		if err := s.updateDescendantDepths(ctx, tx, userID, workspaceID, current.ID, depthDelta); err != nil {
			return OperationResult{}, err
		}
	}
	if contains(changedFields, "tag_ids") {
		if err := s.replaceTaskTags(ctx, tx, userID, workspaceID, current.ID, current.TagIDs); err != nil {
			return OperationResult{}, err
		}
	}
	entity, err := s.taskJSON(ctx, tx, workspaceID, current.ID)
	if err != nil {
		return OperationResult{}, err
	}
	cursor, err := recordChange(
		ctx,
		tx,
		userID,
		workspaceID,
		"task",
		current.ID,
		current.Version,
		current.DeletedAt != nil,
		entity,
	)
	if err != nil {
		return OperationResult{}, err
	}
	return OperationResult{
		OperationID:  operation.OperationID,
		Status:       "applied",
		EntityType:   operation.EntityType,
		EntityID:     operation.EntityID,
		Version:      current.Version,
		Cursor:       cursor,
		ServerEntity: entity,
	}, nil
}

// authorizeTaskOperation keeps group task visibility and mutation scoped to
// the task owner until the owner explicitly shares it after collaboration is
// enabled. L3 retains server-wide access, while L1/L2 members can collaborate
// only on shared tasks.
func (s *Store) authorizeTaskOperation(
	ctx context.Context,
	tx pgx.Tx,
	userID, workspaceID uuid.UUID,
	current taskRecord,
	operation PushOperation,
	creating bool,
) error {
	var kind string
	var groupID *uuid.UUID
	var collaborationEnabledAt *time.Time
	if err := tx.QueryRow(ctx, `
		SELECT workspace.kind, workspace.group_id, group_row.collaboration_enabled_at
		FROM workspaces workspace
		LEFT JOIN groups group_row ON group_row.id = workspace.group_id
		WHERE workspace.id = $1`, workspaceID,
	).Scan(&kind, &groupID, &collaborationEnabledAt); err != nil {
		return err
	}

	if kind == "personal" {
		if !creating && current.OwnerUserID != userID {
			return operationRejection{"FORBIDDEN_SCOPE", "only the task owner can modify a personal task"}
		}
		if current.SharedAt != nil || contains(operation.ChangedFields, "shared_at") {
			return operationRejection{"VALIDATION_ERROR", "personal tasks cannot be shared"}
		}
		return nil
	}
	if groupID == nil {
		return operationRejection{"FORBIDDEN_SCOPE", "workspace group is missing"}
	}
	var archived bool
	if err := tx.QueryRow(ctx, `SELECT archived FROM groups WHERE id = $1`, *groupID).Scan(&archived); err != nil {
		return err
	}
	if archived && creating {
		return operationRejection{"GROUP_ARCHIVED", "archived groups cannot accept new tasks"}
	}

	var role string
	if err := tx.QueryRow(ctx, `
		SELECT CASE
			WHEN EXISTS(SELECT 1 FROM server_roles WHERE user_id=$1 AND role='L3' AND active) THEN 'L3'
			ELSE COALESCE((
				SELECT account.role
				FROM group_account_links link
				JOIN group_accounts account ON account.id=link.group_account_id
				JOIN users member ON member.id=link.user_id AND member.disabled_at IS NULL
				WHERE link.user_id=$1 AND link.group_id=$2 AND link.unbound_at IS NULL AND account.active
			), '')
		END`, userID, *groupID).Scan(&role); err != nil {
		return err
	}
	if role == "" {
		return operationRejection{"FORBIDDEN_SCOPE", "user is not an active group member"}
	}

	owner := creating || current.OwnerUserID == userID
	manager := role == "L2" || role == "L3"
	changedFields := normalizedChangedFields(operation)
	if !creating && !owner && current.SharedAt == nil {
		sharingOnly := contains(changedFields, "shared_at") && len(changedFields) == 1
		if role != "L3" && !(manager && sharingOnly) {
			return operationRejection{"FORBIDDEN_SCOPE", "task is not shared with this group member"}
		}
	}
	if contains(changedFields, "shared_at") {
		if !owner && !manager {
			return operationRejection{"FORBIDDEN_SCOPE", "only the owner or a group manager can change sharing"}
		}
		var target *time.Time
		if raw, ok := operation.Changes["shared_at"]; ok {
			if err := decodeTime(raw, &target); err != nil {
				return operationRejection{"VALIDATION_ERROR", "shared_at must be an RFC3339 time or null"}
			}
		}
		if target != nil && collaborationEnabledAt == nil {
			return operationRejection{"COLLABORATION_DISABLED", "group collaboration must be enabled before sharing tasks"}
		}
	}
	if current.SharedAt != nil && collaborationEnabledAt == nil {
		return operationRejection{"COLLABORATION_DISABLED", "group collaboration is disabled"}
	}
	return nil
}

func (s *Store) activeGroupAccountForUserTx(
	ctx context.Context,
	tx pgx.Tx,
	userID, workspaceID uuid.UUID,
) (*uuid.UUID, error) {
	var accountID uuid.UUID
	err := tx.QueryRow(ctx, `
		SELECT link.group_account_id
		FROM workspaces workspace
		JOIN groups group_row ON group_row.id = workspace.group_id
		JOIN group_account_links link ON link.group_id = group_row.id
		JOIN group_accounts account ON account.id = link.group_account_id
		WHERE workspace.id = $1 AND link.user_id = $2
		  AND link.unbound_at IS NULL AND account.active
		ORDER BY link.bound_at DESC
		LIMIT 1`, workspaceID, userID).Scan(&accountID)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &accountID, nil
}

func conflictingFields(
	currentVersion int64,
	fieldVersions map[string]int64,
	operation PushOperation,
) []string {
	if operation.BaseVersion >= currentVersion {
		return nil
	}
	structural := map[string]bool{
		"parent_id":  true,
		"sort_order": true,
		"tag_ids":    true,
	}
	conflicts := make([]string, 0)
	for _, field := range normalizedChangedFields(operation) {
		if structural[field] || fieldVersions[field] > operation.BaseVersion {
			conflicts = append(conflicts, field)
		}
	}
	sort.Strings(conflicts)
	return conflicts
}

func normalizedChangedFields(operation PushOperation) []string {
	seen := make(map[string]bool)
	fields := make([]string, 0, len(operation.ChangedFields)+len(operation.Changes))
	for _, field := range operation.ChangedFields {
		if _, exists := operation.Changes[field]; exists && !seen[field] {
			seen[field] = true
			fields = append(fields, field)
		}
	}
	if len(fields) == 0 {
		for field := range operation.Changes {
			fields = append(fields, field)
		}
		sort.Strings(fields)
	}
	return fields
}

func applyTaskField(task *taskRecord, field string, raw json.RawMessage) error {
	switch field {
	case "id", "depth", "updated_by_device_id", "updated_at":
		return nil
	case "title":
		return decodeRequired(raw, &task.Title)
	case "description":
		return decodeNullable(raw, &task.Description)
	case "quadrant":
		return decodeNumber(raw, &task.Quadrant)
	case "status":
		return decodeNumber(raw, &task.Status)
	case "due_at":
		return decodeTime(raw, &task.DueAt)
	case "parent_id":
		return decodeUUID(raw, &task.ParentID)
	case "sort_order":
		return decodeNumber(raw, &task.SortOrder)
	case "project_id":
		return decodeUUID(raw, &task.ProjectID)
	case "checklist_group_id":
		return decodeUUID(raw, &task.ChecklistGroupID)
	case "deleted_at":
		return decodeTime(raw, &task.DeletedAt)
	case "created_at":
		var value *time.Time
		if err := decodeTime(raw, &value); err != nil {
			return err
		}
		if value != nil {
			task.CreatedAt = *value
		}
		return nil
	case "completed_at":
		return decodeTime(raw, &task.CompletedAt)
	case "shared_at":
		return decodeTime(raw, &task.SharedAt)
	case "tag_ids":
		var values []string
		if err := json.Unmarshal(raw, &values); err != nil {
			return fmt.Errorf("tag_ids must be an array")
		}
		task.TagIDs = make([]uuid.UUID, 0, len(values))
		for _, value := range values {
			parsed, err := uuid.Parse(value)
			if err != nil {
				return fmt.Errorf("tag_ids contains an invalid UUID")
			}
			task.TagIDs = append(task.TagIDs, parsed)
		}
		return nil
	default:
		return fmt.Errorf("unsupported task field %q", field)
	}
}

func decodeRequired(raw json.RawMessage, target *string) error {
	if len(raw) == 0 || string(raw) == "null" || json.Unmarshal(raw, target) != nil {
		return errors.New("field must be a string")
	}
	*target = strings.TrimSpace(*target)
	return nil
}

func decodeNullable(raw json.RawMessage, target **string) error {
	if string(raw) == "null" {
		*target = nil
		return nil
	}
	var value string
	if err := json.Unmarshal(raw, &value); err != nil {
		return errors.New("field must be a string or null")
	}
	*target = &value
	return nil
}

func decodeNumber[T ~int16 | ~int32](raw json.RawMessage, target *T) error {
	var value int64
	if err := json.Unmarshal(raw, &value); err != nil {
		return errors.New("field must be an integer")
	}
	*target = T(value)
	return nil
}

func decodeUUID(raw json.RawMessage, target **uuid.UUID) error {
	if string(raw) == "null" {
		*target = nil
		return nil
	}
	var value string
	if err := json.Unmarshal(raw, &value); err != nil {
		return errors.New("field must be a UUID or null")
	}
	parsed, err := uuid.Parse(value)
	if err != nil {
		return errors.New("field must be a UUID or null")
	}
	*target = &parsed
	return nil
}

func decodeTime(raw json.RawMessage, target **time.Time) error {
	if string(raw) == "null" {
		*target = nil
		return nil
	}
	var value string
	if err := json.Unmarshal(raw, &value); err != nil {
		return errors.New("field must be RFC3339 time or null")
	}
	parsed, err := time.Parse(time.RFC3339Nano, value)
	if err != nil {
		return errors.New("field must be RFC3339 time or null")
	}
	parsed = parsed.UTC()
	*target = &parsed
	return nil
}

func (s *Store) taskNodes(
	ctx context.Context,
	tx pgx.Tx,
	workspaceID uuid.UUID,
) ([]tasks.Node, error) {
	rows, err := tx.Query(
		ctx,
		`SELECT id, parent_id, depth FROM tasks
			 WHERE workspace_id = $1 AND deleted_at IS NULL`,
		workspaceID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var nodes []tasks.Node
	for rows.Next() {
		var id uuid.UUID
		var parentID *uuid.UUID
		var depth int
		if err := rows.Scan(&id, &parentID, &depth); err != nil {
			return nil, err
		}
		parent := ""
		if parentID != nil {
			parent = parentID.String()
		}
		nodes = append(nodes, tasks.Node{ID: id.String(), ParentID: parent, Depth: depth})
	}
	return nodes, rows.Err()
}

func treeRejection(err error) operationRejection {
	switch {
	case errors.Is(err, tasks.ErrCycle):
		return operationRejection{"TASK_CYCLE", "task parent would create a cycle"}
	case errors.Is(err, tasks.ErrDepthLimit):
		return operationRejection{"DEPTH_LIMIT", "task tree can contain at most five levels"}
	default:
		return operationRejection{"INVALID_PARENT", "parent task does not exist"}
	}
}

func (s *Store) validateOwnedReference(
	ctx context.Context,
	tx pgx.Tx,
	table string,
	workspaceID uuid.UUID,
	entityID *uuid.UUID,
) error {
	if entityID == nil {
		return nil
	}
	query := ""
	switch table {
	case "projects":
		query = `SELECT EXISTS(SELECT 1 FROM projects WHERE workspace_id=$1 AND id=$2)`
	case "checklist_groups":
		query = `SELECT EXISTS(SELECT 1 FROM checklist_groups WHERE workspace_id=$1 AND id=$2)`
	default:
		return errors.New("invalid owned reference table")
	}
	var exists bool
	if err := tx.QueryRow(ctx, query, workspaceID, *entityID).Scan(&exists); err != nil {
		return err
	}
	if !exists {
		return operationRejection{"INVALID_REFERENCE", "referenced entity does not exist"}
	}
	return nil
}

func (s *Store) updateDescendantDepths(
	ctx context.Context,
	tx pgx.Tx,
	userID, workspaceID, rootID uuid.UUID,
	delta int,
) error {
	rows, err := tx.Query(
		ctx,
		`WITH RECURSIVE descendants AS (
		   SELECT id FROM tasks WHERE workspace_id=$1 AND parent_id=$2
		   UNION ALL
		   SELECT child.id FROM tasks child
		   JOIN descendants parent ON child.parent_id=parent.id
		   WHERE child.workspace_id=$1
		 )
		 UPDATE tasks SET
		   depth=depth+$3,
		   version=version+1,
		   updated_at=now(),
		   last_operated_by_user_id=$4,
		   field_versions=jsonb_set(
		     field_versions, '{depth}', to_jsonb(version+1), true
		   )
		 WHERE workspace_id=$1 AND id IN (SELECT id FROM descendants)
		 RETURNING id, version`,
		workspaceID,
		rootID,
		delta,
		userID,
	)
	if err != nil {
		return err
	}
	defer rows.Close()
	type changed struct {
		id      uuid.UUID
		version int64
	}
	var changedRows []changed
	for rows.Next() {
		var item changed
		if err := rows.Scan(&item.id, &item.version); err != nil {
			return err
		}
		changedRows = append(changedRows, item)
	}
	if err := rows.Err(); err != nil {
		return err
	}
	for _, item := range changedRows {
		entity, err := s.taskJSON(ctx, tx, workspaceID, item.id)
		if err != nil {
			return err
		}
		if _, err := recordChange(
			ctx,
			tx,
			userID,
			workspaceID,
			"task",
			item.id,
			item.version,
			false,
			entity,
		); err != nil {
			return err
		}
	}
	return nil
}

func (s *Store) replaceTaskTags(
	ctx context.Context,
	tx pgx.Tx,
	userID, workspaceID, taskID uuid.UUID,
	tagIDs []uuid.UUID,
) error {
	if _, err := tx.Exec(
		ctx,
		`DELETE FROM task_tags WHERE workspace_id=$1 AND task_id=$2`,
		workspaceID,
		taskID,
	); err != nil {
		return err
	}
	for _, tagID := range tagIDs {
		var exists bool
		if err := tx.QueryRow(
			ctx,
			`SELECT EXISTS(SELECT 1 FROM tags WHERE workspace_id=$1 AND id=$2 AND archived=false)`,
			workspaceID,
			tagID,
		).Scan(&exists); err != nil {
			return err
		}
		if !exists {
			return operationRejection{"INVALID_TAG", "tag does not exist"}
		}
		if _, err := tx.Exec(
			ctx,
			`INSERT INTO task_tags(user_id, workspace_id, task_id, tag_id) VALUES($1,$2,$3,$4)
			 ON CONFLICT (workspace_id, task_id, tag_id) DO NOTHING`,
			userID,
			workspaceID,
			taskID,
			tagID,
		); err != nil {
			return err
		}
	}
	return nil
}

func (s *Store) taskJSON(
	ctx context.Context,
	tx pgx.Tx,
	workspaceID, taskID uuid.UUID,
) (json.RawMessage, error) {
	var entity []byte
	err := tx.QueryRow(
		ctx,
		`SELECT (
			to_jsonb(task_row) - 'user_id' - 'workspace_id' - 'field_versions'
		 ) || jsonb_build_object(
		   'tag_ids', COALESCE((
		     SELECT jsonb_agg(tag_id ORDER BY tag_id)
			 FROM task_tags WHERE workspace_id=$1 AND task_id=$2
		   ), '[]'::jsonb)
		 )
		 FROM tasks task_row
		 WHERE workspace_id=$1 AND id=$2`,
		workspaceID,
		taskID,
	).Scan(&entity)
	return entity, err
}

func recordChange(
	ctx context.Context,
	tx pgx.Tx,
	userID uuid.UUID,
	workspaceID uuid.UUID,
	entityType string,
	entityID uuid.UUID,
	version int64,
	deleted bool,
	entity json.RawMessage,
) (int64, error) {
	var cursor int64
	err := tx.QueryRow(
		ctx,
		`INSERT INTO sync_changes(
		   user_id, workspace_id, entity_type, entity_id, entity_version, deleted, entity
		 ) VALUES($1,$2,$3,$4,$5,$6,$7)
		 RETURNING cursor`,
		userID,
		workspaceID,
		entityType,
		entityID,
		version,
		deleted,
		entity,
	).Scan(&cursor)
	return cursor, err
}

func sameUUID(left, right *uuid.UUID) bool {
	if left == nil || right == nil {
		return left == nil && right == nil
	}
	return *left == *right
}

func contains(values []string, target string) bool {
	for _, value := range values {
		if value == target {
			return true
		}
	}
	return false
}
