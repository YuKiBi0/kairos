package httpapi

import (
	"net/http"
	"strconv"

	"github.com/YuKiBi0/kairos/server/internal/store"
	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
)

func (a *API) taskDetail(w http.ResponseWriter, r *http.Request) {
	userID, _, ok := identity(r.Context())
	if !ok {
		writeError(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "需要登录")
		return
	}
	taskID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		writeError(w, r, http.StatusBadRequest, "VALIDATION_ERROR", "任务 ID 无效")
		return
	}
	entity, err := a.store.TaskEntity(r.Context(), userID, taskID)
	if store.IsMissingEntity(err) {
		writeError(w, r, http.StatusNotFound, "NOT_FOUND", "任务不存在")
		return
	}
	if err != nil {
		writeError(w, r, http.StatusInternalServerError, "DATABASE_ERROR", "无法读取任务")
		return
	}
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	_, _ = w.Write(entity)
}

func (a *API) taskDescendants(w http.ResponseWriter, r *http.Request) {
	userID, _, ok := identity(r.Context())
	if !ok {
		writeError(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "需要登录")
		return
	}
	taskID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		writeError(w, r, http.StatusBadRequest, "VALIDATION_ERROR", "任务 ID 无效")
		return
	}
	depth := 5
	if raw := r.URL.Query().Get("depth"); raw != "" {
		depth, err = strconv.Atoi(raw)
		if err != nil || depth < 1 || depth > 5 {
			writeError(w, r, http.StatusBadRequest, "VALIDATION_ERROR", "depth 必须介于 1 和 5")
			return
		}
	}
	entities, err := a.store.TaskDescendants(r.Context(), userID, taskID, depth)
	if err != nil {
		writeError(w, r, http.StatusInternalServerError, "DATABASE_ERROR", "无法读取子任务")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"tasks": entities})
}

func (a *API) taxonomyList(entityType string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID, _, ok := identity(r.Context())
		if !ok {
			writeError(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "需要登录")
			return
		}
		entities, err := a.store.TaxonomyEntities(r.Context(), userID, entityType)
		if err != nil {
			writeError(w, r, http.StatusInternalServerError, "DATABASE_ERROR", "无法读取归类信息")
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"items": entities})
	}
}
