package httpapi

import (
	"net/http"
	"strconv"

	"github.com/YuKiBi0/kairos/server/internal/realtime"
	"github.com/YuKiBi0/kairos/server/internal/store"
)

type pushRequest struct {
	Operations []store.PushOperation `json:"operations"`
}

func (a *API) snapshot(w http.ResponseWriter, r *http.Request) {
	userID, _, ok := identity(r.Context())
	if !ok {
		writeError(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "需要登录")
		return
	}
	snapshot, err := a.store.Snapshot(r.Context(), userID)
	if err != nil {
		a.logger.ErrorContext(r.Context(), "snapshot_failed", "request_id", requestID(r.Context()))
		writeError(w, r, http.StatusInternalServerError, "SYNC_FAILED", "无法创建同步快照")
		return
	}
	writeJSON(w, http.StatusOK, snapshot)
}

func (a *API) changes(w http.ResponseWriter, r *http.Request) {
	userID, _, ok := identity(r.Context())
	if !ok {
		writeError(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "需要登录")
		return
	}
	after, err := strconv.ParseInt(r.URL.Query().Get("after"), 10, 64)
	if err != nil || after < 0 {
		writeError(w, r, http.StatusBadRequest, "VALIDATION_ERROR", "after 游标无效")
		return
	}
	limit := 200
	if raw := r.URL.Query().Get("limit"); raw != "" {
		parsed, err := strconv.Atoi(raw)
		if err != nil || parsed < 1 || parsed > 200 {
			writeError(w, r, http.StatusBadRequest, "VALIDATION_ERROR", "limit 必须介于 1 和 200")
			return
		}
		limit = parsed
	}
	items, next, hasMore, err := a.store.Changes(r.Context(), userID, after, limit)
	if err != nil {
		a.logger.ErrorContext(r.Context(), "changes_failed", "request_id", requestID(r.Context()))
		writeError(w, r, http.StatusInternalServerError, "SYNC_FAILED", "无法读取增量变更")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"changes":     items,
		"next_cursor": next,
		"has_more":    hasMore,
	})
}

func (a *API) push(w http.ResponseWriter, r *http.Request) {
	userID, deviceID, ok := identity(r.Context())
	if !ok {
		writeError(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "需要登录")
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
		result, err := a.store.ApplyOperation(r.Context(), userID, deviceID, operation)
		if err != nil {
			a.logger.ErrorContext(
				r.Context(),
				"push_operation_failed",
				"request_id", requestID(r.Context()),
				"entity_type", operation.EntityType,
			)
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
		if result.Status == "applied" {
			a.hub.Publish(userID, realtime.ChangeHint{
				Type:          "change_hint",
				Cursor:        result.Cursor,
				EntityType:    result.EntityType,
				EntityID:      result.EntityID,
				EntityVersion: result.Version,
			})
		}
	}
	writeJSON(w, http.StatusOK, map[string]any{"results": results})
}

func (a *API) syncStatus(w http.ResponseWriter, r *http.Request) {
	userID, deviceID, ok := identity(r.Context())
	if !ok {
		writeError(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "需要登录")
		return
	}
	cursor, err := a.store.ServerCursor(r.Context(), userID)
	if err != nil {
		writeError(w, r, http.StatusInternalServerError, "SYNC_FAILED", "无法读取同步状态")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"server_cursor": cursor,
		"device_id":     deviceID,
	})
}
