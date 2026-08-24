package httpapi

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/hex"
	"encoding/json"
	"errors"
	"net/http"
	"strings"
	"time"

	"github.com/YuKiBi0/kairos/server/internal/auth"
	"github.com/YuKiBi0/kairos/server/internal/store"
	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
)

const (
	adminSessionCookie = "kairos_admin_session"
	adminSessionTTL    = 8 * time.Hour
	adminLoginLimit    = int64(10)
)

const adminLoginRateScript = `local current = redis.call('INCR', KEYS[1]); if current == 1 then redis.call('EXPIRE', KEYS[1], '60'); end; return current`

type adminSession struct {
	UserID    uuid.UUID `json:"user_id"`
	CSRF      string    `json:"csrf"`
	CreatedAt int64     `json:"created_at"`
}

type adminSessionKey struct{}

func (a *API) adminPage(w http.ResponseWriter, r *http.Request) {
	data, err := adminFile("index.html")
	if err != nil {
		writeError(w, r, http.StatusInternalServerError, "ADMIN_UNAVAILABLE", "管理后台不可用")
		return
	}
	a.adminHeaders(w)
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	_, _ = w.Write(data)
}

func (a *API) adminAsset(w http.ResponseWriter, r *http.Request) {
	name := strings.TrimPrefix(chi.URLParam(r, "asset"), "/")
	if name != "app.css" && name != "app.js" {
		http.NotFound(w, r)
		return
	}
	data, err := adminFile(name)
	if err != nil {
		http.NotFound(w, r)
		return
	}
	a.adminHeaders(w)
	if name == "app.css" {
		w.Header().Set("Content-Type", "text/css; charset=utf-8")
	} else {
		w.Header().Set("Content-Type", "text/javascript; charset=utf-8")
	}
	_, _ = w.Write(data)
}

func (a *API) adminHeaders(w http.ResponseWriter) {
	w.Header().Set("Content-Security-Policy", "default-src 'self'; connect-src 'self'; style-src 'self'; script-src 'self'; base-uri 'none'; frame-ancestors 'none'; form-action 'self'")
	w.Header().Set("X-Frame-Options", "DENY")
	w.Header().Set("X-Content-Type-Options", "nosniff")
	w.Header().Set("Referrer-Policy", "no-referrer")
}

func (a *API) adminLogin(w http.ResponseWriter, r *http.Request) {
	a.adminHeaders(w)
	if a.redis == nil {
		writeError(w, r, http.StatusServiceUnavailable, "DEPENDENCY_UNAVAILABLE", "管理会话存储不可用")
		return
	}
	var request struct {
		Username string `json:"username"`
		Password string `json:"password"`
	}
	if !decodeJSON(w, r, &request) {
		return
	}
	allowed, err := a.allowAdminLogin(r, request.Username)
	if err != nil {
		writeError(w, r, http.StatusServiceUnavailable, "DEPENDENCY_UNAVAILABLE", "管理登录服务暂时不可用")
		return
	}
	if !allowed {
		writeError(w, r, http.StatusTooManyRequests, "RATE_LIMITED", "管理登录尝试过于频繁")
		return
	}
	user, err := a.store.UserByUsername(r.Context(), strings.TrimSpace(request.Username))
	if err != nil {
		a.rejectLogin(w, r)
		return
	}
	valid, err := auth.VerifyPassword(user.PasswordHash, request.Password)
	if err != nil || !valid {
		a.rejectLogin(w, r)
		return
	}
	role, err := a.store.AdminRole(r.Context(), user.ID)
	if err != nil {
		if errors.Is(err, store.ErrAdminForbidden) {
			writeError(w, r, http.StatusForbidden, "ADMIN_FORBIDDEN", "该账号没有管理后台权限")
			return
		}
		writeError(w, r, http.StatusInternalServerError, "DATABASE_ERROR", "无法读取管理权限")
		return
	}
	csrf, err := randomToken(32)
	if err != nil {
		writeError(w, r, http.StatusInternalServerError, "TOKEN_ERROR", "无法创建管理会话")
		return
	}
	sessionID, err := randomToken(32)
	if err != nil {
		writeError(w, r, http.StatusInternalServerError, "TOKEN_ERROR", "无法创建管理会话")
		return
	}
	session := adminSession{UserID: user.ID, CSRF: csrf, CreatedAt: time.Now().UTC().Unix()}
	encoded, _ := json.Marshal(session)
	if _, err := a.redisCommand(r, "SET", "kairos:admin:session:"+sessionID, string(encoded), "EX", "28800"); err != nil {
		writeError(w, r, http.StatusServiceUnavailable, "DEPENDENCY_UNAVAILABLE", "无法保存管理会话")
		return
	}
	http.SetCookie(w, &http.Cookie{Name: adminSessionCookie, Value: sessionID, Path: "/KairosAdmin/", HttpOnly: true, Secure: true, SameSite: http.SameSiteStrictMode, MaxAge: int(adminSessionTTL.Seconds())})
	http.SetCookie(w, &http.Cookie{Name: "kairos_admin_csrf", Value: csrf, Path: "/KairosAdmin/", Secure: true, SameSite: http.SameSiteStrictMode, MaxAge: int(adminSessionTTL.Seconds())})
	writeJSON(w, http.StatusOK, map[string]any{"user": user, "role": role, "csrf_token": csrf, "expires_in": int64(adminSessionTTL.Seconds())})
}

func (a *API) allowAdminLogin(r *http.Request, username string) (bool, error) {
	digest := sha256.Sum256([]byte(strings.ToLower(strings.TrimSpace(username))))
	value, err := a.redisCommand(r, "EVAL", adminLoginRateScript, "1", "kairos:admin:login:"+hex.EncodeToString(digest[:]))
	if err != nil {
		return false, err
	}
	count, ok := value.(int64)
	if !ok || count < 1 {
		return false, errors.New("unexpected admin login rate limit response")
	}
	return count <= adminLoginLimit, nil
}

func (a *API) adminLogout(w http.ResponseWriter, r *http.Request) {
	if session, ok := r.Context().Value(adminSessionKey{}).(adminSession); ok {
		if cookie, err := r.Cookie(adminSessionCookie); err == nil {
			_, _ = a.redisCommand(r, "DEL", "kairos:admin:session:"+cookie.Value)
		}
		_ = session
	}
	http.SetCookie(w, &http.Cookie{Name: adminSessionCookie, Value: "", Path: "/KairosAdmin/", HttpOnly: true, Secure: true, SameSite: http.SameSiteStrictMode, MaxAge: -1})
	http.SetCookie(w, &http.Cookie{Name: "kairos_admin_csrf", Value: "", Path: "/KairosAdmin/", Secure: true, SameSite: http.SameSiteStrictMode, MaxAge: -1})
	w.WriteHeader(http.StatusNoContent)
}

func (a *API) adminAuthenticate(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		a.adminHeaders(w)
		cookie, err := r.Cookie(adminSessionCookie)
		if err != nil || cookie.Value == "" || a.redis == nil {
			writeError(w, r, http.StatusUnauthorized, "ADMIN_UNAUTHORIZED", "请登录管理后台")
			return
		}
		value, err := a.redisCommand(r, "GET", "kairos:admin:session:"+cookie.Value)
		if err != nil {
			writeError(w, r, http.StatusServiceUnavailable, "DEPENDENCY_UNAVAILABLE", "管理会话存储不可用")
			return
		}
		raw, ok := value.(string)
		if !ok || raw == "" {
			writeError(w, r, http.StatusUnauthorized, "ADMIN_UNAUTHORIZED", "管理会话已过期")
			return
		}
		var session adminSession
		if json.Unmarshal([]byte(raw), &session) != nil || session.UserID == uuid.Nil || session.CSRF == "" {
			writeError(w, r, http.StatusUnauthorized, "ADMIN_UNAUTHORIZED", "管理会话无效")
			return
		}
		if _, err := a.store.UserByID(r.Context(), session.UserID); err != nil {
			writeError(w, r, http.StatusUnauthorized, "ADMIN_UNAUTHORIZED", "账号不可用")
			return
		}
		role, err := a.store.AdminRole(r.Context(), session.UserID)
		if err != nil {
			writeError(w, r, http.StatusForbidden, "ADMIN_FORBIDDEN", "账号没有管理后台权限")
			return
		}
		ctx := contextWithAdmin(r.Context(), session, role)
		if r.Method != http.MethodGet && r.Method != http.MethodHead && r.Method != http.MethodOptions {
			if err := a.redis.Ping(r.Context()); err != nil {
				writeError(w, r, http.StatusServiceUnavailable, "DEPENDENCY_UNAVAILABLE", "管理会话存储不可用")
				return
			}
			csrf := r.Header.Get("X-CSRF-Token")
			if len(csrf) != len(session.CSRF) || subtle.ConstantTimeCompare([]byte(csrf), []byte(session.CSRF)) != 1 {
				writeError(w, r, http.StatusForbidden, "CSRF_FAILED", "请求校验失败")
				return
			}
		}
		ctx = contextWithAdminRole(ctx, role)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

func contextWithAdmin(ctx context.Context, session adminSession, role string) context.Context {
	ctx = context.WithValue(ctx, adminSessionKey{}, session)
	return context.WithValue(ctx, adminRoleKey{}, role)
}

type adminRoleKey struct{}

func contextWithAdminRole(ctx context.Context, role string) context.Context {
	return context.WithValue(ctx, adminRoleKey{}, role)
}

func adminRole(ctx context.Context) string {
	role, _ := ctx.Value(adminRoleKey{}).(string)
	return role
}

func (a *API) redisCommand(r *http.Request, command string, args ...string) (any, error) {
	client, ok := a.redis.(interface {
		Command(context.Context, string, ...string) (any, error)
	})
	if !ok {
		return nil, errors.New("redis command interface unavailable")
	}
	return client.Command(r.Context(), command, args...)
}

func randomToken(size int) (string, error) {
	buf := make([]byte, size)
	if _, err := rand.Read(buf); err != nil {
		return "", err
	}
	return hex.EncodeToString(buf), nil
}
