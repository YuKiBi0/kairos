package httpapi

import (
	"net/http"
	"strconv"

	"github.com/YuKiBi0/kairos/server/internal/store"
	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
)

func (a *API) workspaceSnapshot(w http.ResponseWriter, r *http.Request) {
	userID, _, ok := identity(r.Context())
	if !ok {
		writeError(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "需要登录")
		return
	}
	workspaceID, ok := workspaceIDParam(w, r)
	if !ok {
		return
	}
	if _, err := a.store.WorkspaceForUser(r.Context(), userID, workspaceID); handleWorkspaceError(w, r, err) {
		return
	}
	snapshot, err := a.store.WorkspaceSnapshot(r.Context(), workspaceID, userID)
	if handleWorkspaceError(w, r, err) {
		return
	}
	writeJSON(w, http.StatusOK, snapshot)
}

func (a *API) workspaceChanges(w http.ResponseWriter, r *http.Request) {
	userID, _, ok := identity(r.Context())
	if !ok {
		writeError(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "需要登录")
		return
	}
	workspaceID, ok := workspaceIDParam(w, r)
	if !ok {
		return
	}
	if _, err := a.store.WorkspaceForUser(r.Context(), userID, workspaceID); handleWorkspaceError(w, r, err) {
		return
	}
	after, err := strconv.ParseInt(r.URL.Query().Get("after"), 10, 64)
	if err != nil || after < 0 {
		writeError(w, r, http.StatusBadRequest, "VALIDATION_ERROR", "after 游标无效")
		return
	}
	limit := 200
	if raw := r.URL.Query().Get("limit"); raw != "" {
		limit, err = strconv.Atoi(raw)
		if err != nil || limit < 1 || limit > 200 {
			writeError(w, r, http.StatusBadRequest, "VALIDATION_ERROR", "limit 必须介于 1 和 200")
			return
		}
	}
	items, next, serverCursor, hasMore, err := a.store.WorkspaceChanges(r.Context(), workspaceID, after, limit, userID)
	if handleWorkspaceError(w, r, err) {
		return
	}
	if after > serverCursor {
		writeError(w, r, http.StatusConflict, "CURSOR_AHEAD", "本机游标高于服务端，请重新获取同步快照")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"changes": items, "next_cursor": next, "server_cursor": serverCursor, "has_more": hasMore})
}

func (a *API) workspaceSyncStatus(w http.ResponseWriter, r *http.Request) {
	userID, deviceID, ok := identity(r.Context())
	if !ok {
		writeError(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "需要登录")
		return
	}
	workspaceID, ok := workspaceIDParam(w, r)
	if !ok {
		return
	}
	if _, err := a.store.WorkspaceForUser(r.Context(), userID, workspaceID); handleWorkspaceError(w, r, err) {
		return
	}
	cursor, err := a.store.WorkspaceCursor(r.Context(), workspaceID)
	if handleWorkspaceError(w, r, err) {
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"workspace_id": workspaceID, "server_cursor": cursor, "device_id": deviceID})
}

func (a *API) workspacePush(w http.ResponseWriter, r *http.Request) {
	userID, deviceID, ok := identity(r.Context())
	if !ok {
		writeError(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "需要登录")
		return
	}
	workspaceID, ok := workspaceIDParam(w, r)
	if !ok {
		return
	}
	if _, err := a.store.WorkspaceForUser(r.Context(), userID, workspaceID); handleWorkspaceError(w, r, err) {
		return
	}
	var request pushRequest
	if !decodeJSON(w, r, &request) {
		return
	}
	if len(request.Operations) == 0 || len(request.Operations) > 50 {
		writeError(w, r, http.StatusBadRequest, "VALIDATION_ERROR", "每批必须包含 1 到 50 个操作")
		return
	}
	results := make([]store.OperationResult, 0, len(request.Operations))
	for _, operation := range request.Operations {
		result, err := a.store.ApplyWorkspaceOperation(r.Context(), userID, deviceID, workspaceID, operation)
		if err != nil {
			a.logger.ErrorContext(r.Context(), "workspace_push_operation_failed", "request_id", requestID(r.Context()), "entity_type", operation.EntityType)
			result = store.OperationResult{
				OperationID: operation.OperationID,
				Status:      "rejected",
				EntityType:  operation.EntityType,
				EntityID:    operation.EntityID,
				Code:        "SERVER_ERROR",
				Message:     "服务暂时无法应用该操作",
			}
		}
		results = append(results, result)
	}
	writeJSON(w, http.StatusOK, map[string]any{"results": results})
}

func workspaceIDParam(w http.ResponseWriter, r *http.Request) (uuid.UUID, bool) {
	value, err := uuid.Parse(chi.URLParam(r, "workspace_id"))
	if err != nil {
		writeError(w, r, http.StatusBadRequest, "VALIDATION_ERROR", "工作空间 ID 无效")
		return uuid.Nil, false
	}
	return value, true
}

func handleWorkspaceError(w http.ResponseWriter, r *http.Request, err error) bool {
	if err == nil {
		return false
	}
	if err == store.ErrWorkspaceForbidden {
		writeError(w, r, http.StatusForbidden, "FORBIDDEN_SCOPE", "无权访问此工作空间")
		return true
	}
	writeError(w, r, http.StatusInternalServerError, "SYNC_FAILED", "无法处理工作空间同步")
	return true
}
