package httpapi

import (
	"errors"
	"net/http"
	"strings"

	"github.com/YuKiBi0/kairos/server/internal/store"
	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
)

func (a *API) workspaces(w http.ResponseWriter, r *http.Request) {
	userID, _, ok := identity(r.Context())
	if !ok {
		writeError(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "需要登录")
		return
	}
	workspaces, err := a.store.ListAccessibleWorkspaces(r.Context(), userID)
	if err != nil {
		writeError(w, r, http.StatusInternalServerError, "DATABASE_ERROR", "无法读取工作空间")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"workspaces": workspaces})
}

type createGroupRequest struct {
	Name string `json:"name"`
}

func (a *API) createGroup(w http.ResponseWriter, r *http.Request) {
	userID, _, ok := identity(r.Context())
	if !ok {
		writeError(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "需要登录")
		return
	}
	var request createGroupRequest
	if !decodeJSON(w, r, &request) {
		return
	}
	group, account, _, err := a.store.CreateGroup(r.Context(), userID, request.Name)
	if err != nil {
		writeError(w, r, http.StatusBadRequest, "VALIDATION_ERROR", "无法创建群组")
		return
	}
	writeJSON(w, http.StatusCreated, map[string]any{"group": group, "group_account": account})
}

func (a *API) groupDetail(w http.ResponseWriter, r *http.Request) {
	userID, _, authenticated := identity(r.Context())
	if !authenticated {
		writeError(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "需要登录")
		return
	}
	groupID, ok := groupIDParam(w, r)
	if !ok {
		return
	}
	if _, err := a.store.GroupAccessRole(r.Context(), userID, groupID); handleGroupError(w, r, err) {
		return
	}
	group, err := a.store.GroupByID(r.Context(), groupID)
	if errors.Is(err, store.ErrGroupNotFound) {
		writeError(w, r, http.StatusNotFound, "NOT_FOUND", "群组不存在")
		return
	}
	if err != nil {
		writeError(w, r, http.StatusInternalServerError, "DATABASE_ERROR", "无法读取群组")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"group": group})
}

func (a *API) groupAccounts(w http.ResponseWriter, r *http.Request) {
	userID, _, authenticated := identity(r.Context())
	if !authenticated {
		writeError(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "需要登录")
		return
	}
	groupID, ok := groupIDParam(w, r)
	if !ok {
		return
	}
	role, err := a.store.GroupAccessRole(r.Context(), userID, groupID)
	if handleGroupError(w, r, err) {
		return
	}
	if role != "L2" && role != "L3" {
		writeError(w, r, http.StatusForbidden, "FORBIDDEN_SCOPE", "无权查看花名册")
		return
	}
	accounts, err := a.store.ListGroupAccounts(r.Context(), groupID)
	if err != nil {
		writeError(w, r, http.StatusInternalServerError, "DATABASE_ERROR", "无法读取花名册")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"group_accounts": accounts})
}

type createGroupAccountRequest struct {
	AccountCode string `json:"account_code"`
	DisplayName string `json:"display_name"`
	Role        string `json:"role"`
}

func (a *API) createGroupAccount(w http.ResponseWriter, r *http.Request) {
	actorID, _, ok := identity(r.Context())
	if !ok {
		writeError(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "需要登录")
		return
	}
	groupID, ok := groupIDParam(w, r)
	if !ok {
		return
	}
	var request createGroupAccountRequest
	if !decodeJSON(w, r, &request) {
		return
	}
	account, err := a.store.CreateGroupAccount(r.Context(), actorID, groupID, request.AccountCode, request.DisplayName, request.Role)
	if handleGroupError(w, r, err) {
		return
	}
	writeJSON(w, http.StatusCreated, map[string]any{"group_account": account})
}

type bindGroupAccountRequest struct {
	UserID string `json:"user_id"`
}

func (a *API) bindGroupAccount(w http.ResponseWriter, r *http.Request) {
	actorID, _, ok := identity(r.Context())
	if !ok {
		writeError(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "需要登录")
		return
	}
	groupID, accountID, ok := groupAccountParams(w, r)
	if !ok {
		return
	}
	var request bindGroupAccountRequest
	if !decodeJSON(w, r, &request) {
		return
	}
	targetUserID, err := uuid.Parse(strings.TrimSpace(request.UserID))
	if err != nil {
		writeError(w, r, http.StatusBadRequest, "VALIDATION_ERROR", "真实账号 ID 无效")
		return
	}
	link, err := a.store.BindGroupAccount(r.Context(), actorID, groupID, accountID, targetUserID)
	if handleGroupError(w, r, err) {
		return
	}
	writeJSON(w, http.StatusCreated, map[string]any{"link": link})
}

type unbindGroupAccountRequest struct {
	Reason string `json:"reason"`
}

func (a *API) unbindGroupAccount(w http.ResponseWriter, r *http.Request) {
	actorID, _, ok := identity(r.Context())
	if !ok {
		writeError(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "需要登录")
		return
	}
	groupID, accountID, ok := groupAccountParams(w, r)
	if !ok {
		return
	}
	var request unbindGroupAccountRequest
	if !decodeJSON(w, r, &request) {
		return
	}
	if handleGroupError(w, r, a.store.UnbindGroupAccount(r.Context(), actorID, groupID, accountID, request.Reason)) {
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

type setGroupRoleRequest struct {
	Role string `json:"role"`
}

func (a *API) setGroupAccountRole(w http.ResponseWriter, r *http.Request) {
	actorID, _, ok := identity(r.Context())
	if !ok {
		writeError(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "需要登录")
		return
	}
	groupID, accountID, ok := groupAccountParams(w, r)
	if !ok {
		return
	}
	var request setGroupRoleRequest
	if !decodeJSON(w, r, &request) {
		return
	}
	if handleGroupError(w, r, a.store.SetGroupAccountRole(r.Context(), actorID, groupID, accountID, request.Role)) {
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (a *API) enableCollaboration(w http.ResponseWriter, r *http.Request) {
	actorID, _, ok := identity(r.Context())
	if !ok {
		writeError(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "需要登录")
		return
	}
	groupID, ok := groupIDParam(w, r)
	if !ok {
		return
	}
	if handleGroupError(w, r, a.store.SetCollaborationEnabled(r.Context(), actorID, groupID)) {
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func groupIDParam(w http.ResponseWriter, r *http.Request) (uuid.UUID, bool) {
	value, err := uuid.Parse(chi.URLParam(r, "group_id"))
	if err != nil {
		writeError(w, r, http.StatusBadRequest, "VALIDATION_ERROR", "群组 ID 无效")
		return uuid.Nil, false
	}
	return value, true
}

func groupAccountParams(w http.ResponseWriter, r *http.Request) (uuid.UUID, uuid.UUID, bool) {
	groupID, ok := groupIDParam(w, r)
	if !ok {
		return uuid.Nil, uuid.Nil, false
	}
	accountID, err := uuid.Parse(chi.URLParam(r, "account_id"))
	if err != nil {
		writeError(w, r, http.StatusBadRequest, "VALIDATION_ERROR", "群组账号 ID 无效")
		return uuid.Nil, uuid.Nil, false
	}
	return groupID, accountID, true
}

func handleGroupError(w http.ResponseWriter, r *http.Request, err error) bool {
	if err == nil {
		return false
	}
	switch {
	case errors.Is(err, store.ErrAdminForbidden):
		writeError(w, r, http.StatusForbidden, "FORBIDDEN_SCOPE", "无权管理此资源")
	case errors.Is(err, store.ErrGroupForbidden):
		writeError(w, r, http.StatusForbidden, "FORBIDDEN_SCOPE", "无权管理此群组")
	case errors.Is(err, store.ErrRoleEscalation):
		writeError(w, r, http.StatusForbidden, "ROLE_ESCALATION", "不能分配此角色")
	case errors.Is(err, store.ErrLastGroupAdmin):
		writeError(w, r, http.StatusConflict, "LAST_GROUP_ADMIN", "必须保留至少一个群组管理员")
	case errors.Is(err, store.ErrAlreadyGroupMember):
		writeError(w, r, http.StatusConflict, "ALREADY_GROUP_MEMBER", "该账号已经加入群组")
	case errors.Is(err, store.ErrLastSuperAdmin):
		writeError(w, r, http.StatusConflict, "LAST_SUPER_ADMIN", "必须保留至少一个超级管理员")
	case errors.Is(err, store.ErrGroupAccountNotFound):
		writeError(w, r, http.StatusNotFound, "NOT_FOUND", "群组账号不存在")
	default:
		writeError(w, r, http.StatusInternalServerError, "DATABASE_ERROR", "群组操作失败")
	}
	return true
}
