package httpapi

import (
	"encoding/json"
	"errors"
	"net/http"
	"strings"
	"time"

	"github.com/YuKiBi0/kairos/server/internal/store"
	"github.com/google/uuid"
)

type centralTokenRequest struct {
	ExpiresIn string `json:"expires_in"`
	Scope     string `json:"scope"`
}

func (a *API) centralToken(w http.ResponseWriter, r *http.Request) {
	actorID, deviceID, ok := identity(r.Context())
	if !ok {
		writeError(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "需要登录")
		return
	}
	role, err := a.store.AdminRole(r.Context(), actorID)
	if err != nil || role != "L3" {
		writeError(w, r, http.StatusForbidden, "FORBIDDEN_SCOPE", "只有 L3 可以签发中央委派令牌")
		return
	}
	if _, err := a.store.DeviceByID(r.Context(), actorID, deviceID); err != nil {
		writeError(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "登录设备已撤销或不存在")
		return
	}
	if hasScope(r.Context(), "central:tasks:create") {
		writeError(w, r, http.StatusForbidden, "FORBIDDEN_SCOPE", "中央委派令牌不能继续签发中央令牌")
		return
	}
	var request centralTokenRequest
	if !decodeJSON(w, r, &request) {
		return
	}
	ttl := 15 * time.Minute
	if strings.TrimSpace(request.ExpiresIn) != "" {
		ttl, err = time.ParseDuration(request.ExpiresIn)
		if err != nil || ttl <= 0 || ttl > 24*time.Hour {
			writeError(w, r, http.StatusBadRequest, "VALIDATION_ERROR", "expires_in 必须为正且不超过 24h")
			return
		}
	}
	scope := strings.TrimSpace(request.Scope)
	if scope == "" {
		writeError(w, r, http.StatusBadRequest, "VALIDATION_ERROR", "scope 不能为空")
		return
	}
	scopes := make([]string, 0, 2)
	for _, value := range strings.Split(scope, ",") {
		value = strings.TrimSpace(value)
		if value != "" {
			scopes = append(scopes, value)
		}
	}
	if len(scopes) == 0 {
		writeError(w, r, http.StatusBadRequest, "VALIDATION_ERROR", "scope 不能为空")
		return
	}
	if len(scopes) != 1 || scopes[0] != "central:tasks:create" {
		writeError(w, r, http.StatusBadRequest, "UNSUPPORTED_SCOPE", "中央令牌只允许 central:tasks:create scope")
		return
	}
	token, expiry, err := a.tokens.IssueAccessWithScopesTTL(actorID, deviceID, scopes, ttl)
	if err != nil {
		writeError(w, r, http.StatusInternalServerError, "TOKEN_ERROR", "无法签发中央令牌")
		return
	}
	writeJSON(w, http.StatusCreated, map[string]any{"access_token": token, "expires_at": expiry, "scope": strings.Join(scopes, ",")})
}

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
	if !hasScope(r.Context(), "central:tasks:create") {
		writeError(w, r, http.StatusForbidden, "FORBIDDEN_SCOPE", "需要 central:tasks:create 委派权限")
		return
	}
	if _, err := a.store.DeviceByID(r.Context(), actorID, deviceID); err != nil {
		writeError(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "中央令牌设备已撤销或不存在")
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
		case errors.Is(err, store.ErrCentralForbidden), errors.Is(err, store.ErrCentralScopeRequired):
			status, code, message = http.StatusForbidden, "FORBIDDEN_SCOPE", "中央委派权限不足"
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
