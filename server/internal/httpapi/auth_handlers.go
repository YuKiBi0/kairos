package httpapi

import (
	"net/http"
	"strings"
	"time"

	"github.com/YuKiBi0/kairos/server/internal/auth"
	"github.com/YuKiBi0/kairos/server/internal/store"
	"github.com/google/uuid"
)

type loginRequest struct {
	Username string `json:"username"`
	Password string `json:"password"`
	Device   struct {
		ID       string `json:"id,omitempty"`
		Name     string `json:"name"`
		Platform string `json:"platform"`
	} `json:"device"`
}

type refreshRequest struct {
	RefreshToken string `json:"refresh_token"`
}

type authResponse struct {
	AccessToken  string       `json:"access_token"`
	ExpiresIn    int64        `json:"expires_in"`
	RefreshToken string       `json:"refresh_token"`
	User         store.User   `json:"user"`
	Device       store.Device `json:"device"`
}

func (a *API) login(w http.ResponseWriter, r *http.Request) {
	var request loginRequest
	if !decodeJSON(w, r, &request) {
		return
	}
	request.Username = strings.TrimSpace(request.Username)
	request.Device.Name = strings.TrimSpace(request.Device.Name)
	request.Device.Platform = strings.TrimSpace(request.Device.Platform)
	if request.Username == "" || request.Password == "" ||
		request.Device.Name == "" || request.Device.Platform == "" {
		writeError(w, r, http.StatusBadRequest, "VALIDATION_ERROR", "登录信息不完整")
		return
	}
	user, err := a.store.UserByUsername(r.Context(), request.Username)
	if err != nil {
		a.rejectLogin(w, r)
		return
	}
	valid, err := auth.VerifyPassword(user.PasswordHash, request.Password)
	if err != nil || !valid {
		a.rejectLogin(w, r)
		return
	}
	var requestedID *uuid.UUID
	if request.Device.ID != "" {
		parsed, err := uuid.Parse(request.Device.ID)
		if err != nil {
			writeError(w, r, http.StatusBadRequest, "VALIDATION_ERROR", "设备 ID 无效")
			return
		}
		requestedID = &parsed
	}
	device, err := a.store.UpsertDevice(
		r.Context(),
		user.ID,
		requestedID,
		request.Device.Name,
		request.Device.Platform,
	)
	if err != nil {
		writeError(w, r, http.StatusInternalServerError, "DATABASE_ERROR", "无法创建设备会话")
		return
	}
	a.issueSession(w, r, user, device)
}

func (a *API) refresh(w http.ResponseWriter, r *http.Request) {
	var request refreshRequest
	if !decodeJSON(w, r, &request) || request.RefreshToken == "" {
		return
	}
	newRaw, newHash, err := auth.NewRefreshToken()
	if err != nil {
		writeError(w, r, http.StatusInternalServerError, "TOKEN_ERROR", "无法刷新会话")
		return
	}
	expiresAt := time.Now().UTC().Add(a.refreshTTL)
	session, err := a.store.RotateSession(
		r.Context(),
		auth.HashRefreshToken(request.RefreshToken),
		newHash,
		expiresAt,
	)
	if err != nil {
		writeError(w, r, http.StatusUnauthorized, "INVALID_REFRESH_TOKEN", "请重新登录同步服务")
		return
	}
	user, err := a.store.UserByID(r.Context(), session.UserID)
	if err != nil {
		writeError(w, r, http.StatusUnauthorized, "INVALID_REFRESH_TOKEN", "请重新登录同步服务")
		return
	}
	device, err := a.store.DeviceByID(r.Context(), session.UserID, session.DeviceID)
	if err != nil {
		writeError(w, r, http.StatusUnauthorized, "INVALID_REFRESH_TOKEN", "请重新登录同步服务")
		return
	}
	access, accessExpiry, err := a.tokens.IssueAccess(user.ID, device.ID)
	if err != nil {
		writeError(w, r, http.StatusInternalServerError, "TOKEN_ERROR", "无法刷新会话")
		return
	}
	writeJSON(w, http.StatusOK, authResponse{
		AccessToken:  access,
		ExpiresIn:    int64(time.Until(accessExpiry).Seconds()),
		RefreshToken: newRaw,
		User:         user,
		Device:       device,
	})
}

func (a *API) logout(w http.ResponseWriter, r *http.Request) {
	var request refreshRequest
	if !decodeJSON(w, r, &request) {
		return
	}
	if request.RefreshToken != "" {
		_ = a.store.RevokeSession(r.Context(), auth.HashRefreshToken(request.RefreshToken))
	}
	w.WriteHeader(http.StatusNoContent)
}

func (a *API) me(w http.ResponseWriter, r *http.Request) {
	userID, deviceID, ok := identity(r.Context())
	if !ok {
		writeError(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "需要登录")
		return
	}
	user, err := a.store.UserByID(r.Context(), userID)
	if err != nil {
		writeError(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "需要登录")
		return
	}
	device, err := a.store.DeviceByID(r.Context(), userID, deviceID)
	if err != nil {
		writeError(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "需要登录")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"user": user, "device": device})
}

func (a *API) issueSession(
	w http.ResponseWriter,
	r *http.Request,
	user store.User,
	device store.Device,
) {
	refreshRaw, refreshHash, err := auth.NewRefreshToken()
	if err != nil {
		writeError(w, r, http.StatusInternalServerError, "TOKEN_ERROR", "无法创建会话")
		return
	}
	if _, err := a.store.CreateSession(
		r.Context(),
		user.ID,
		device.ID,
		refreshHash,
		time.Now().UTC().Add(a.refreshTTL),
	); err != nil {
		writeError(w, r, http.StatusInternalServerError, "DATABASE_ERROR", "无法创建会话")
		return
	}
	access, accessExpiry, err := a.tokens.IssueAccess(user.ID, device.ID)
	if err != nil {
		writeError(w, r, http.StatusInternalServerError, "TOKEN_ERROR", "无法创建会话")
		return
	}
	writeJSON(w, http.StatusOK, authResponse{
		AccessToken:  access,
		ExpiresIn:    int64(time.Until(accessExpiry).Seconds()),
		RefreshToken: refreshRaw,
		User:         user,
		Device:       device,
	})
}

func (a *API) rejectLogin(w http.ResponseWriter, r *http.Request) {
	time.Sleep(150 * time.Millisecond)
	writeError(w, r, http.StatusUnauthorized, "INVALID_CREDENTIALS", "用户名或密码不正确")
}
