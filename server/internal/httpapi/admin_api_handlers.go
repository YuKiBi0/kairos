package httpapi

import (
	"errors"
	"net/http"
	"strings"

	"github.com/YuKiBi0/kairos/server/internal/auth"
	"github.com/YuKiBi0/kairos/server/internal/store"
	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
)

func (a *API) adminMe(w http.ResponseWriter, r *http.Request) {
	session, _ := r.Context().Value(adminSessionKey{}).(adminSession)
	user, err := a.store.AdminUserByID(r.Context(), session.UserID)
	if err != nil {
		writeError(w, r, http.StatusUnauthorized, "ADMIN_UNAUTHORIZED", "账号不可用")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"user": user, "role": adminRole(r.Context()), "csrf_token": session.CSRF})
}

func (a *API) adminUsers(w http.ResponseWriter, r *http.Request) {
	if adminRole(r.Context()) != "L3" {
		writeError(w, r, http.StatusForbidden, "ADMIN_FORBIDDEN", "只有超级管理员可以管理服务器账号")
		return
	}
	users, err := a.store.AdminUsers(r.Context())
	if err != nil {
		writeError(w, r, http.StatusInternalServerError, "DATABASE_ERROR", "无法读取服务器账号")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"users": users})
}

func (a *API) adminGroups(w http.ResponseWriter, r *http.Request) {
	groups, err := a.store.AdminGroups(r.Context(), adminUserID(r), adminRole(r.Context()))
	if err != nil {
		writeError(w, r, http.StatusInternalServerError, "DATABASE_ERROR", "无法读取群组")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"groups": groups})
}

func (a *API) adminCreateGroup(w http.ResponseWriter, r *http.Request) {
	var request createGroupRequest
	if !decodeJSON(w, r, &request) {
		return
	}
	group, account, _, err := a.store.CreateGroup(r.Context(), adminUserID(r), request.Name)
	if err != nil {
		writeError(w, r, http.StatusBadRequest, "VALIDATION_ERROR", "无法创建群组")
		return
	}
	writeJSON(w, http.StatusCreated, map[string]any{"group": group, "group_account": account})
}

func (a *API) adminGroupAccounts(w http.ResponseWriter, r *http.Request) {
	groupID, err := uuid.Parse(chi.URLParam(r, "group_id"))
	if err != nil {
		writeError(w, r, http.StatusBadRequest, "VALIDATION_ERROR", "群组 ID 无效")
		return
	}
	accounts, err := a.store.AdminGroupAccounts(r.Context(), adminUserID(r), groupID, adminRole(r.Context()))
	if errors.Is(err, store.ErrAdminForbidden) {
		writeError(w, r, http.StatusForbidden, "ADMIN_FORBIDDEN", "无权管理此群组")
		return
	}
	if err != nil {
		writeError(w, r, http.StatusInternalServerError, "DATABASE_ERROR", "无法读取群组花名册")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"accounts": accounts})
}

func (a *API) adminCreateGroupAccount(w http.ResponseWriter, r *http.Request) {
	groupID, err := uuid.Parse(chi.URLParam(r, "group_id"))
	if err != nil {
		writeError(w, r, http.StatusBadRequest, "VALIDATION_ERROR", "群组 ID 无效")
		return
	}
	var request struct {
		AccountCode string `json:"account_code"`
		DisplayName string `json:"display_name"`
		Role        string `json:"role"`
	}
	if !decodeJSON(w, r, &request) {
		return
	}
	if adminRole(r.Context()) != "L3" {
		if _, err := a.store.AdminGroupAccounts(r.Context(), adminUserID(r), groupID, adminRole(r.Context())); err != nil {
			writeError(w, r, http.StatusForbidden, "ADMIN_FORBIDDEN", "无权管理此群组")
			return
		}
	}
	account, err := a.store.CreateGroupAccount(r.Context(), adminUserID(r), groupID, request.AccountCode, request.DisplayName, request.Role)
	if err != nil {
		handleGroupError(w, r, err)
		return
	}
	writeJSON(w, http.StatusCreated, map[string]any{"account": account})
}

func (a *API) adminSetAccountRole(w http.ResponseWriter, r *http.Request) {
	groupID, accountID, ok := adminGroupAccountParams(w, r)
	if !ok {
		return
	}
	var request struct {
		Role string `json:"role"`
	}
	if !decodeJSON(w, r, &request) {
		return
	}
	if err := a.store.SetGroupAccountRole(r.Context(), adminUserID(r), groupID, accountID, request.Role); err != nil {
		handleGroupError(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (a *API) adminBindAccount(w http.ResponseWriter, r *http.Request) {
	groupID, accountID, ok := adminGroupAccountParams(w, r)
	if !ok {
		return
	}
	var request struct {
		Username string `json:"username"`
	}
	if !decodeJSON(w, r, &request) {
		return
	}
	username := strings.TrimSpace(request.Username)
	if username == "" {
		writeError(w, r, http.StatusBadRequest, "VALIDATION_ERROR", "必须提供精确账号名")
		return
	}
	targetID, err := a.store.UserIDByExactUsername(r.Context(), username)
	if err != nil {
		writeError(w, r, http.StatusNotFound, "NOT_FOUND", "账号不存在")
		return
	}
	link, err := a.store.BindGroupAccount(r.Context(), adminUserID(r), groupID, accountID, targetID)
	if err != nil {
		handleGroupError(w, r, err)
		return
	}
	writeJSON(w, http.StatusCreated, map[string]any{"link": link})
}

func (a *API) adminUnbindAccount(w http.ResponseWriter, r *http.Request) {
	groupID, accountID, ok := adminGroupAccountParams(w, r)
	if !ok {
		return
	}
	var request struct {
		Reason string `json:"reason"`
	}
	if !decodeJSON(w, r, &request) {
		return
	}
	if err := a.store.UnbindGroupAccount(r.Context(), adminUserID(r), groupID, accountID, request.Reason); err != nil {
		handleGroupError(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (a *API) adminEnableCollaboration(w http.ResponseWriter, r *http.Request) {
	groupID, err := uuid.Parse(chi.URLParam(r, "group_id"))
	if err != nil {
		writeError(w, r, http.StatusBadRequest, "VALIDATION_ERROR", "群组 ID 无效")
		return
	}
	if err := a.store.SetCollaborationEnabled(r.Context(), adminUserID(r), groupID); err != nil {
		handleGroupError(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (a *API) adminCreateUser(w http.ResponseWriter, r *http.Request) {
	if adminRole(r.Context()) != "L3" {
		writeError(w, r, http.StatusForbidden, "ADMIN_FORBIDDEN", "只有超级管理员可以创建服务器账号")
		return
	}
	var request struct {
		Username string `json:"username"`
		Password string `json:"password"`
	}
	if !decodeJSON(w, r, &request) {
		return
	}
	username := strings.TrimSpace(request.Username)
	if username == "" || len(username) > 100 || len(request.Password) < 12 {
		writeError(w, r, http.StatusBadRequest, "VALIDATION_ERROR", "账号名不能为空，密码至少 12 位")
		return
	}
	hash, err := auth.HashPassword(request.Password)
	if err != nil {
		writeError(w, r, http.StatusInternalServerError, "PASSWORD_ERROR", "无法处理密码")
		return
	}
	user, err := a.store.CreateUser(r.Context(), username, hash)
	if err != nil {
		writeError(w, r, http.StatusConflict, "USERNAME_EXISTS", "账号名已存在")
		return
	}
	writeJSON(w, http.StatusCreated, map[string]any{"user": user})
}

func (a *API) adminSetUserDisabled(w http.ResponseWriter, r *http.Request) {
	if adminRole(r.Context()) != "L3" {
		writeError(w, r, http.StatusForbidden, "ADMIN_FORBIDDEN", "只有超级管理员可以停用服务器账号")
		return
	}
	targetID, err := uuid.Parse(chi.URLParam(r, "user_id"))
	if err != nil {
		writeError(w, r, http.StatusBadRequest, "VALIDATION_ERROR", "账号 ID 无效")
		return
	}
	var request struct {
		Disabled bool `json:"disabled"`
	}
	if !decodeJSON(w, r, &request) {
		return
	}
	if err := a.store.SetUserDisabled(r.Context(), adminUserID(r), targetID, request.Disabled); err != nil {
		handleGroupError(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (a *API) adminSetSuperAdmin(w http.ResponseWriter, r *http.Request) {
	if adminRole(r.Context()) != "L3" {
		writeError(w, r, http.StatusForbidden, "ADMIN_FORBIDDEN", "只有超级管理员可以分配超级管理员")
		return
	}
	targetID, err := uuid.Parse(chi.URLParam(r, "user_id"))
	if err != nil {
		writeError(w, r, http.StatusBadRequest, "VALIDATION_ERROR", "账号 ID 无效")
		return
	}
	var request struct {
		Active bool `json:"active"`
	}
	if !decodeJSON(w, r, &request) {
		return
	}
	if err := a.store.SetServerSuperAdmin(r.Context(), adminUserID(r), targetID, request.Active); err != nil {
		handleGroupError(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func adminUserID(r *http.Request) uuid.UUID {
	session, _ := r.Context().Value(adminSessionKey{}).(adminSession)
	return session.UserID
}

func adminGroupAccountParams(w http.ResponseWriter, r *http.Request) (uuid.UUID, uuid.UUID, bool) {
	groupID, err := uuid.Parse(chi.URLParam(r, "group_id"))
	if err != nil {
		writeError(w, r, http.StatusBadRequest, "VALIDATION_ERROR", "群组 ID 无效")
		return uuid.Nil, uuid.Nil, false
	}
	accountID, err := uuid.Parse(chi.URLParam(r, "account_id"))
	if err != nil {
		writeError(w, r, http.StatusBadRequest, "VALIDATION_ERROR", "群组账号 ID 无效")
		return uuid.Nil, uuid.Nil, false
	}
	return groupID, accountID, true
}
