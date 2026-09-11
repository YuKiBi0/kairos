package httpapi

import (
	"encoding/json"
	"errors"
	"net/http"
	"strings"

	"github.com/YuKiBi0/kairos/server/internal/store"
	"github.com/google/uuid"
)

type centralTaskRequest struct {
	WorkspaceID     string  `json:"workspace_id"`
	GroupID         string  `json:"group_id"`
	CreatorUserID   string  `json:"creator_user_id"`
	CreatorUsername string  `json:"creator_username,omitempty"`
	Title           string  `json:"title"`
	Description     *string `json:"description,omitempty"`
	Quadrant        int16   `json:"quadrant,omitempty"`
	SourceAgentID   string  `json:"source_agent_id,omitempty"`
	IdempotencyKey  string  `json:"idempotency_key,omitempty"`
}

func (a *API) centralTaskCreate(w http.ResponseWriter, r *http.Request) {
	actorID, deviceID, ok := identity(r.Context())
	if !ok {
		writeError(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "需要登录")
		return
	}
	role, err := a.store.AdminRole(r.Context(), actorID)
	if err != nil || role != "L3" {
		writeError(w, r, http.StatusForbidden, "FORBIDDEN_ROLE", "中央 CLI 仅允许 L3 账号使用")
		return
	}
	if _, err := a.store.DeviceByID(r.Context(), actorID, deviceID); err != nil {
		writeError(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "登录设备已撤销或不存在")
		return
	}
	var request centralTaskRequest
	if !decodeJSON(w, r, &request) {
		return
	}
	workspaceID, err := uuid.Parse(strings.TrimSpace(request.WorkspaceID))
	if err != nil {
		writeError(w, r, http.StatusBadRequest, "VALIDATION_ERROR", "workspace_id 无效")
		return
	}
	groupID, err := uuid.Parse(strings.TrimSpace(request.GroupID))
	if err != nil {
		writeError(w, r, http.StatusBadRequest, "VALIDATION_ERROR", "group_id 无效")
		return
	}
	var targetID uuid.UUID
	if strings.TrimSpace(request.CreatorUserID) != "" {
		targetID, err = uuid.Parse(strings.TrimSpace(request.CreatorUserID))
		if err != nil {
			writeError(w, r, http.StatusBadRequest, "VALIDATION_ERROR", "creator_user_id 无效")
			return
		}
	} else if strings.TrimSpace(request.CreatorUsername) != "" {
		targetID, err = a.store.UserIDByExactUsername(r.Context(), strings.TrimSpace(request.CreatorUsername))
		if err != nil {
			writeError(w, r, http.StatusNotFound, "TARGET_USER_NOT_FOUND", "目标用户名不存在或已禁用")
			return
		}
	} else {
		writeError(w, r, http.StatusBadRequest, "VALIDATION_ERROR", "必须指定 creator_user_id 或 creator_username")
		return
	}
	key := strings.TrimSpace(request.IdempotencyKey)
	headerKey := strings.TrimSpace(r.Header.Get("Idempotency-Key"))
	if key != "" && headerKey != "" && key != headerKey {
		writeError(w, r, http.StatusBadRequest, "VALIDATION_ERROR", "JSON 和 Idempotency-Key 必须使用同一个 UUID")
		return
	}
	if key == "" {
		key = headerKey
	}
	operationID, err := uuid.Parse(key)
	if err != nil {
		writeError(w, r, http.StatusBadRequest, "VALIDATION_ERROR", "必须提供 UUID 格式的 idempotency_key")
		return
	}
	result, err := a.store.CreateCentralTask(r.Context(), actorID, deviceID, groupID, workspaceID, targetID, operationID, request.Title, request.Description, request.Quadrant, request.SourceAgentID)
	if err != nil {
		status, code, message := http.StatusInternalServerError, "DATABASE_ERROR", "无法创建中央任务"
		switch {
		case errors.Is(err, store.ErrCentralForbidden):
			status, code, message = http.StatusForbidden, "FORBIDDEN_ROLE", "中央 CLI 仅允许 L3 账号使用"
		case errors.Is(err, store.ErrCentralTargetNotMember):
			status, code, message = http.StatusForbidden, "TARGET_NOT_GROUP_MEMBER", "目标用户不是该群组的有效成员"
		case errors.Is(err, store.ErrCentralWorkspace):
			status, code, message = http.StatusBadRequest, "WORKSPACE_GROUP_MISMATCH", "工作空间不属于指定群组"
		case errors.Is(err, store.ErrCentralGroupArchived):
			status, code, message = http.StatusConflict, "GROUP_ARCHIVED", "归档群组不能创建任务"
		case errors.Is(err, store.ErrCentralIdempotencyConflict):
			status, code, message = http.StatusConflict, "IDEMPOTENCY_KEY_REUSED", "幂等键已被其他中央操作者使用"
		default:
			if strings.Contains(err.Error(), "task title") || strings.Contains(err.Error(), "quadrant") {
				status, code, message = http.StatusBadRequest, "VALIDATION_ERROR", err.Error()
			}
		}
		failureDetails, _ := json.Marshal(map[string]any{
			"target_user_id":  targetID,
			"workspace_id":    workspaceID,
			"source_agent_id": strings.TrimSpace(request.SourceAgentID),
			"idempotency_key": operationID,
			"error_code":      code,
		})
		_ = a.store.WriteAuditEvent(r.Context(), &actorID, &groupID, "central.task.create", "task", nil, "failure", requestID(r.Context()), failureDetails)
		writeError(w, r, status, code, message)
		return
	}
	status := http.StatusCreated
	if result.Duplicate {
		status = http.StatusOK
	}
	writeJSON(w, status, result)
}
