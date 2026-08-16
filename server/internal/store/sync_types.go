package store

import (
	"encoding/json"

	"github.com/google/uuid"
)

type PushOperation struct {
	OperationID   uuid.UUID                  `json:"operation_id"`
	EntityType    string                     `json:"entity_type"`
	EntityID      uuid.UUID                  `json:"entity_id"`
	BaseVersion   int64                      `json:"base_version"`
	Action        string                     `json:"action,omitempty"`
	Changes       map[string]json.RawMessage `json:"changes"`
	ChangedFields []string                   `json:"changed_fields"`
}

type OperationResult struct {
	OperationID       uuid.UUID       `json:"operation_id"`
	Status            string          `json:"status"`
	EntityType        string          `json:"entity_type"`
	EntityID          uuid.UUID       `json:"entity_id"`
	Version           int64           `json:"version,omitempty"`
	Cursor            int64           `json:"cursor,omitempty"`
	Code              string          `json:"code,omitempty"`
	Message           string          `json:"message,omitempty"`
	ConflictingFields []string        `json:"conflicting_fields,omitempty"`
	ServerEntity      json.RawMessage `json:"server_entity,omitempty"`
}

type SyncChange struct {
	Cursor        int64           `json:"cursor"`
	EntityType    string          `json:"entity_type"`
	EntityID      uuid.UUID       `json:"entity_id"`
	EntityVersion int64           `json:"entity_version"`
	Deleted       bool            `json:"deleted"`
	Entity        json.RawMessage `json:"entity,omitempty"`
}

type Snapshot struct {
	Tasks           []json.RawMessage `json:"tasks"`
	Blockers        []json.RawMessage `json:"blockers"`
	Tags            []json.RawMessage `json:"tags"`
	Projects        []json.RawMessage `json:"projects"`
	ChecklistGroups []json.RawMessage `json:"checklist_groups"`
	Cursor          int64             `json:"cursor"`
}
