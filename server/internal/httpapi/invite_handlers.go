package httpapi

import (
	"errors"
	"net/http"
	"strings"
	"time"

	"github.com/YuKiBi0/kairos/server/internal/invites"
	"github.com/YuKiBi0/kairos/server/internal/store"
	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
)

type createInviteRequest struct {
	TargetGroupAccountID string `json:"target_group_account_id,omitempty"`
	MaxUses              *int   `json:"max_uses,omitempty"`
	ExpiresAt            string `json:"expires_at"`
}

func (a *API) createInvite(w http.ResponseWriter, r *http.Request) {
	actorID, _, ok := identity(r.Context())
	if !ok {
		writeError(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "需要登录")
		return
	}
	groupID, ok := groupIDParam(w, r)
	if !ok {
		return
	}
	var request createInviteRequest
	if !decodeJSON(w, r, &request) {
		return
	}
	expiresAt, err := time.Parse(time.RFC3339, strings.TrimSpace(request.ExpiresAt))
	if err != nil {
		writeError(w, r, http.StatusBadRequest, "VALIDATION_ERROR", "expires_at 必须是 RFC3339 时间")
		return
	}
	var targetID *uuid.UUID
	if strings.TrimSpace(request.TargetGroupAccountID) != "" {
		parsed, err := uuid.Parse(request.TargetGroupAccountID)
		if err != nil {
			writeError(w, r, http.StatusBadRequest, "VALIDATION_ERROR", "目标群组账号 ID 无效")
			return
		}
		targetID = &parsed
	}
	rawCode, digest, err := invites.Generate(a.inviteSecret)
	if err != nil {
		writeError(w, r, http.StatusInternalServerError, "INVITE_UNAVAILABLE", "无法生成邀请码")
		return
	}
	created, err := a.store.CreateGroupInvite(r.Context(), actorID, groupID, digest, targetID, request.MaxUses, expiresAt)
	if handleInviteError(w, r, err) {
		return
	}
	writeJSON(w, http.StatusCreated, map[string]any{"invite": created, "code": rawCode})
}

func (a *API) listInvites(w http.ResponseWriter, r *http.Request) {
	actorID, _, ok := identity(r.Context())
	if !ok {
		writeError(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "需要登录")
		return
	}
	groupID, ok := groupIDParam(w, r)
	if !ok {
		return
	}
	items, err := a.store.ListGroupInvites(r.Context(), actorID, groupID)
	if handleInviteError(w, r, err) {
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"invites": items})
}

func (a *API) revokeInvite(w http.ResponseWriter, r *http.Request) {
	actorID, _, ok := identity(r.Context())
	if !ok {
		writeError(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "需要登录")
		return
	}
	groupID, inviteID, ok := inviteParams(w, r)
	if !ok {
		return
	}
	if handleInviteError(w, r, a.store.RevokeGroupInvite(r.Context(), actorID, groupID, inviteID)) {
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

type redeemInviteRequest struct {
	Code           string `json:"code"`
	IdempotencyKey string `json:"idempotency_key"`
}

func (a *API) redeemInvite(w http.ResponseWriter, r *http.Request) {
	userID, _, ok := identity(r.Context())
	if !ok {
		writeError(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "需要登录")
		return
	}
	var request redeemInviteRequest
	if !decodeJSON(w, r, &request) {
		return
	}
	key, err := uuid.Parse(strings.TrimSpace(request.IdempotencyKey))
	if err != nil {
		writeError(w, r, http.StatusBadRequest, "VALIDATION_ERROR", "idempotency_key 必须是 UUID")
		return
	}
	code := strings.TrimSpace(request.Code)
	if code == "" || len(code) > 128 {
		writeError(w, r, http.StatusBadRequest, "VALIDATION_ERROR", "邀请码无效")
		return
	}
	redemption, err := a.store.RedeemGroupInvite(r.Context(), userID, invites.Digest(a.inviteSecret, code), key)
	if handleInviteError(w, r, err) {
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"redemption": redemption})
}

func inviteParams(w http.ResponseWriter, r *http.Request) (uuid.UUID, uuid.UUID, bool) {
	groupID, ok := groupIDParam(w, r)
	if !ok {
		return uuid.Nil, uuid.Nil, false
	}
	inviteID, err := uuid.Parse(chi.URLParam(r, "invite_id"))
	if err != nil {
		writeError(w, r, http.StatusBadRequest, "VALIDATION_ERROR", "邀请码 ID 无效")
		return uuid.Nil, uuid.Nil, false
	}
	return groupID, inviteID, true
}

func handleInviteError(w http.ResponseWriter, r *http.Request, err error) bool {
	if err == nil {
		return false
	}
	switch {
	case errors.Is(err, store.ErrGroupForbidden):
		writeError(w, r, http.StatusForbidden, "FORBIDDEN_SCOPE", "无权管理此群组")
	case errors.Is(err, store.ErrGroupAccountNotFound):
		writeError(w, r, http.StatusNotFound, "NOT_FOUND", "群组账号不存在")
	case errors.Is(err, store.ErrInviteInvalid):
		writeError(w, r, http.StatusNotFound, "INVITE_INVALID", "邀请码不存在")
	case errors.Is(err, store.ErrInviteExpired):
		writeError(w, r, http.StatusGone, "INVITE_EXPIRED", "邀请码已过期")
	case errors.Is(err, store.ErrInviteRevoked):
		writeError(w, r, http.StatusGone, "INVITE_REVOKED", "邀请码已撤销")
	case errors.Is(err, store.ErrInviteExhausted):
		writeError(w, r, http.StatusGone, "INVITE_EXHAUSTED", "邀请码已用尽")
	case errors.Is(err, store.ErrInviteAccountBound):
		writeError(w, r, http.StatusConflict, "INVITE_ACCOUNT_BOUND", "目标群组账号已绑定")
	case errors.Is(err, store.ErrAlreadyGroupMember):
		writeError(w, r, http.StatusConflict, "ALREADY_GROUP_MEMBER", "该账号已经加入群组")
	default:
		writeError(w, r, http.StatusInternalServerError, "DATABASE_ERROR", "邀请码操作失败")
	}
	return true
}
