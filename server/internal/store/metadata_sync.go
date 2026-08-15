package store

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

type blockerRecord struct {
	ID            uuid.UUID
	TaskID        uuid.UUID
	Body          string
	Resolved      bool
	ResolvedAt    *time.Time
	Version       int64
	FieldVersions map[string]int64
	DeletedAt     *time.Time
	CreatedAt     time.Time
	UpdatedAt     time.Time
}

func (s *Store) applyBlockerOperation(
	ctx context.Context,
	tx pgx.Tx,
	userID uuid.UUID,
	operation PushOperation,
) (OperationResult, error) {
	var current blockerRecord
	var fieldVersions []byte
	err := tx.QueryRow(
		ctx,
		`SELECT id, task_id, body, resolved, resolved_at, version,
		        field_versions, deleted_at, created_at, updated_at
		 FROM blockers WHERE user_id=$1 AND id=$2 FOR UPDATE`,
		userID,
		operation.EntityID,
	).Scan(
		&current.ID,
		&current.TaskID,
		&current.Body,
		&current.Resolved,
		&current.ResolvedAt,
		&current.Version,
		&fieldVersions,
		&current.DeletedAt,
		&current.CreatedAt,
		&current.UpdatedAt,
	)
	creating := errors.Is(err, pgx.ErrNoRows)
	if err != nil && !creating {
		return OperationResult{}, err
	}
	if creating {
		if operation.BaseVersion != 0 {
			return OperationResult{}, operationRejection{"MISSING_ENTITY", "blocker does not exist"}
		}
		now := time.Now().UTC()
		current = blockerRecord{
			ID:            operation.EntityID,
			FieldVersions: make(map[string]int64),
			CreatedAt:     now,
			UpdatedAt:     now,
		}
	} else {
		current.FieldVersions = make(map[string]int64)
		if err := json.Unmarshal(fieldVersions, &current.FieldVersions); err != nil {
			return OperationResult{}, err
		}
		conflicts := conflictingFields(current.Version, current.FieldVersions, operation)
		if len(conflicts) > 0 {
			entity, err := s.blockerJSON(ctx, tx, userID, current.ID)
			if err != nil {
				return OperationResult{}, err
			}
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

	fields := normalizedChangedFields(operation)
	for _, field := range fields {
		raw := operation.Changes[field]
		switch field {
		case "id", "updated_at":
		case "task_id":
			var taskID *uuid.UUID
			if err := decodeUUID(raw, &taskID); err != nil || taskID == nil {
				return OperationResult{}, operationRejection{"VALIDATION_ERROR", "task_id must be a UUID"}
			}
			current.TaskID = *taskID
		case "body":
			if err := decodeRequired(raw, &current.Body); err != nil {
				return OperationResult{}, operationRejection{"VALIDATION_ERROR", err.Error()}
			}
		case "resolved":
			if err := json.Unmarshal(raw, &current.Resolved); err != nil {
				return OperationResult{}, operationRejection{"VALIDATION_ERROR", "resolved must be boolean"}
			}
		case "resolved_at":
			if err := decodeTime(raw, &current.ResolvedAt); err != nil {
				return OperationResult{}, operationRejection{"VALIDATION_ERROR", err.Error()}
			}
		case "deleted_at":
			if err := decodeTime(raw, &current.DeletedAt); err != nil {
				return OperationResult{}, operationRejection{"VALIDATION_ERROR", err.Error()}
			}
		case "created_at":
			var value *time.Time
			if err := decodeTime(raw, &value); err != nil {
				return OperationResult{}, operationRejection{"VALIDATION_ERROR", err.Error()}
			}
			if value != nil {
				current.CreatedAt = *value
			}
		default:
			return OperationResult{}, operationRejection{"VALIDATION_ERROR", fmt.Sprintf("unsupported blocker field %q", field)}
		}
	}
	if operation.Action == "delete" && current.DeletedAt == nil {
		now := time.Now().UTC()
		current.DeletedAt = &now
		fields = append(fields, "deleted_at")
	}
	if current.TaskID == uuid.Nil || strings.TrimSpace(current.Body) == "" ||
		utf8.RuneCountInString(current.Body) > 1000 {
		return OperationResult{}, operationRejection{"VALIDATION_ERROR", "blocker fields are invalid"}
	}
	var taskExists bool
	if err := tx.QueryRow(
		ctx,
		`SELECT EXISTS(
		   SELECT 1 FROM tasks WHERE user_id=$1 AND id=$2 AND deleted_at IS NULL
		 )`,
		userID,
		current.TaskID,
	).Scan(&taskExists); err != nil {
		return OperationResult{}, err
	}
	if !taskExists {
		return OperationResult{}, operationRejection{"INVALID_TASK", "blocker task does not exist"}
	}
	current.Version++
	current.UpdatedAt = time.Now().UTC()
	if current.Resolved && current.ResolvedAt == nil {
		value := current.UpdatedAt
		current.ResolvedAt = &value
	}
	if !current.Resolved {
		current.ResolvedAt = nil
	}
	for _, field := range fields {
		current.FieldVersions[field] = current.Version
	}
	current.FieldVersions["updated_at"] = current.Version
	encodedVersions, err := json.Marshal(current.FieldVersions)
	if err != nil {
		return OperationResult{}, err
	}
	if creating {
		_, err = tx.Exec(
			ctx,
			`INSERT INTO blockers(
			   id,user_id,task_id,body,resolved,resolved_at,version,field_versions,
			   deleted_at,created_at,updated_at
			 ) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)`,
			current.ID,
			userID,
			current.TaskID,
			current.Body,
			current.Resolved,
			current.ResolvedAt,
			current.Version,
			encodedVersions,
			current.DeletedAt,
			current.CreatedAt,
			current.UpdatedAt,
		)
	} else {
		_, err = tx.Exec(
			ctx,
			`UPDATE blockers SET
			   task_id=$3,body=$4,resolved=$5,resolved_at=$6,version=$7,
			   field_versions=$8,deleted_at=$9,updated_at=$10
			 WHERE user_id=$1 AND id=$2`,
			userID,
			current.ID,
			current.TaskID,
			current.Body,
			current.Resolved,
			current.ResolvedAt,
			current.Version,
			encodedVersions,
			current.DeletedAt,
			current.UpdatedAt,
		)
	}
	if err != nil {
		return OperationResult{}, err
	}
	entity, err := s.blockerJSON(ctx, tx, userID, current.ID)
	if err != nil {
		return OperationResult{}, err
	}
	cursor, err := recordChange(
		ctx,
		tx,
		userID,
		"blocker",
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

func (s *Store) blockerJSON(
	ctx context.Context,
	tx pgx.Tx,
	userID, blockerID uuid.UUID,
) (json.RawMessage, error) {
	var entity []byte
	err := tx.QueryRow(
		ctx,
		`SELECT to_jsonb(blocker_row) - 'user_id' - 'field_versions'
		 FROM blockers blocker_row WHERE user_id=$1 AND id=$2`,
		userID,
		blockerID,
	).Scan(&entity)
	return entity, err
}

type taxonomyRecord struct {
	ID            uuid.UUID
	Name          string
	ColorToken    *string
	Archived      bool
	Version       int64
	FieldVersions map[string]int64
	UpdatedAt     time.Time
}

func (s *Store) applyTaxonomyOperation(
	ctx context.Context,
	tx pgx.Tx,
	userID uuid.UUID,
	operation PushOperation,
) (OperationResult, error) {
	current, err := loadTaxonomy(ctx, tx, userID, operation.EntityType, operation.EntityID)
	creating := errors.Is(err, pgx.ErrNoRows)
	if err != nil && !creating {
		return OperationResult{}, err
	}
	if creating {
		if operation.BaseVersion != 0 {
			return OperationResult{}, operationRejection{"MISSING_ENTITY", "entity does not exist"}
		}
		current = taxonomyRecord{
			ID:            operation.EntityID,
			FieldVersions: make(map[string]int64),
			UpdatedAt:     time.Now().UTC(),
		}
	} else {
		conflicts := conflictingFields(current.Version, current.FieldVersions, operation)
		if len(conflicts) > 0 {
			entity, err := taxonomyJSON(ctx, tx, userID, operation.EntityType, current.ID)
			if err != nil {
				return OperationResult{}, err
			}
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
	fields := normalizedChangedFields(operation)
	for _, field := range fields {
		switch field {
		case "id", "updated_at":
		case "name":
			if err := decodeRequired(operation.Changes[field], &current.Name); err != nil {
				return OperationResult{}, operationRejection{"VALIDATION_ERROR", err.Error()}
			}
		case "archived":
			if err := json.Unmarshal(operation.Changes[field], &current.Archived); err != nil {
				return OperationResult{}, operationRejection{"VALIDATION_ERROR", "archived must be boolean"}
			}
		case "color_token":
			if operation.EntityType != "tag" {
				return OperationResult{}, operationRejection{"VALIDATION_ERROR", "color_token is only valid for tags"}
			}
			if err := decodeNullable(operation.Changes[field], &current.ColorToken); err != nil {
				return OperationResult{}, operationRejection{"VALIDATION_ERROR", err.Error()}
			}
		default:
			return OperationResult{}, operationRejection{"VALIDATION_ERROR", fmt.Sprintf("unsupported field %q", field)}
		}
	}
	deleted := operation.Action == "delete"
	if deleted {
		current.Archived = true
		fields = append(fields, "archived")
	}
	if strings.TrimSpace(current.Name) == "" || utf8.RuneCountInString(current.Name) > 100 {
		return OperationResult{}, operationRejection{"VALIDATION_ERROR", "name must contain 1 to 100 characters"}
	}
	current.Version++
	current.UpdatedAt = time.Now().UTC()
	for _, field := range fields {
		current.FieldVersions[field] = current.Version
	}
	current.FieldVersions["updated_at"] = current.Version
	if err := writeTaxonomy(ctx, tx, userID, operation.EntityType, current, creating); err != nil {
		return OperationResult{}, err
	}
	if deleted && operation.EntityType == "tag" {
		if _, err := tx.Exec(
			ctx,
			`DELETE FROM task_tags WHERE user_id=$1 AND tag_id=$2`,
			userID,
			current.ID,
		); err != nil {
			return OperationResult{}, err
		}
	}
	entity, err := taxonomyJSON(ctx, tx, userID, operation.EntityType, current.ID)
	if err != nil {
		return OperationResult{}, err
	}
	cursor, err := recordChange(
		ctx,
		tx,
		userID,
		operation.EntityType,
		current.ID,
		current.Version,
		deleted,
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

func loadTaxonomy(
	ctx context.Context,
	tx pgx.Tx,
	userID uuid.UUID,
	entityType string,
	entityID uuid.UUID,
) (taxonomyRecord, error) {
	query := ""
	switch entityType {
	case "tag":
		query = `SELECT id,name,color_token,archived,version,field_versions,updated_at
		 FROM tags WHERE user_id=$1 AND id=$2 FOR UPDATE`
	case "project":
		query = `SELECT id,name,NULL::text,archived,version,field_versions,updated_at
		 FROM projects WHERE user_id=$1 AND id=$2 FOR UPDATE`
	case "checklist_group":
		query = `SELECT id,name,NULL::text,archived,version,field_versions,updated_at
		 FROM checklist_groups WHERE user_id=$1 AND id=$2 FOR UPDATE`
	default:
		return taxonomyRecord{}, operationRejection{"UNSUPPORTED_ENTITY", "unsupported taxonomy entity"}
	}
	var current taxonomyRecord
	var encoded []byte
	err := tx.QueryRow(ctx, query, userID, entityID).Scan(
		&current.ID,
		&current.Name,
		&current.ColorToken,
		&current.Archived,
		&current.Version,
		&encoded,
		&current.UpdatedAt,
	)
	if err != nil {
		return taxonomyRecord{}, err
	}
	current.FieldVersions = make(map[string]int64)
	if err := json.Unmarshal(encoded, &current.FieldVersions); err != nil {
		return taxonomyRecord{}, err
	}
	return current, nil
}

func writeTaxonomy(
	ctx context.Context,
	tx pgx.Tx,
	userID uuid.UUID,
	entityType string,
	current taxonomyRecord,
	creating bool,
) error {
	encoded, err := json.Marshal(current.FieldVersions)
	if err != nil {
		return err
	}
	var query string
	var arguments []any
	if entityType == "tag" {
		if creating {
			query = `INSERT INTO tags(
			 id,user_id,name,color_token,archived,version,field_versions,updated_at
			) VALUES($1,$2,$3,$4,$5,$6,$7,$8)`
		} else {
			query = `UPDATE tags SET name=$3,color_token=$4,archived=$5,
			 version=$6,field_versions=$7,updated_at=$8
			 WHERE id=$1 AND user_id=$2`
		}
		arguments = []any{
			current.ID, userID, current.Name, current.ColorToken, current.Archived,
			current.Version, encoded, current.UpdatedAt,
		}
	} else {
		table := "projects"
		if entityType == "checklist_group" {
			table = "checklist_groups"
		}
		if creating {
			query = fmt.Sprintf(
				`INSERT INTO %s(id,user_id,name,archived,version,field_versions,updated_at)
				 VALUES($1,$2,$3,$4,$5,$6,$7)`,
				table,
			)
		} else {
			query = fmt.Sprintf(
				`UPDATE %s SET name=$3,archived=$4,version=$5,field_versions=$6,
				 updated_at=$7 WHERE id=$1 AND user_id=$2`,
				table,
			)
		}
		arguments = []any{
			current.ID, userID, current.Name, current.Archived,
			current.Version, encoded, current.UpdatedAt,
		}
	}
	_, err = tx.Exec(ctx, query, arguments...)
	return err
}

func taxonomyJSON(
	ctx context.Context,
	tx pgx.Tx,
	userID uuid.UUID,
	entityType string,
	entityID uuid.UUID,
) (json.RawMessage, error) {
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
		 FROM %s entity_row WHERE user_id=$1 AND id=$2`,
		table,
	)
	var entity []byte
	err := tx.QueryRow(ctx, query, userID, entityID).Scan(&entity)
	return entity, err
}
