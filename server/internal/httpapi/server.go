package httpapi

import (
	"context"
	"log/slog"
	"net/http"
	"time"

	"github.com/YuKiBi0/kairos/server/internal/auth"
	"github.com/YuKiBi0/kairos/server/internal/config"
	"github.com/YuKiBi0/kairos/server/internal/realtime"
	"github.com/YuKiBi0/kairos/server/internal/store"
	"github.com/go-chi/chi/v5"
)

type API struct {
	store           *store.Store
	tokens          *auth.TokenManager
	refreshTTL      time.Duration
	logger          *slog.Logger
	version         string
	hub             *realtime.Hub
	realtimeOrigins []string
	redis           redisHealth
	redisRequired   bool
	inviteSecret    []byte
}

type redisHealth interface {
	Ping(context.Context) error
}

func New(
	store *store.Store,
	config config.Config,
	logger *slog.Logger,
	version string,
) http.Handler {
	return NewWithRedis(store, config, logger, version, nil)
}

func NewWithRedis(
	store *store.Store,
	config config.Config,
	logger *slog.Logger,
	version string,
	redisClient redisHealth,
) http.Handler {
	api := &API{
		store:           store,
		tokens:          auth.NewTokenManager(config.SessionSecret, config.AccessTTL, "kairos-server"),
		refreshTTL:      config.RefreshTTL,
		logger:          logger,
		version:         version,
		hub:             realtime.NewHub(),
		realtimeOrigins: config.CORSOrigins,
		redis:           redisClient,
		redisRequired:   config.RedisRequired,
		inviteSecret:    append([]byte(nil), config.SessionSecret...),
	}

	router := chi.NewRouter()
	router.Use(func(next http.Handler) http.Handler { return recoverPanics(logger, next) })
	router.Use(func(next http.Handler) http.Handler { return requestMetadata(logger, next) })
	router.Get("/healthz", api.health)
	router.Get("/readyz", api.ready)
	router.Get("/version", api.versionInfo)
	router.Get("/KairosAdmin/", api.adminPage)
	router.Get("/KairosAdmin/assets/{asset}", api.adminAsset)
	router.Post("/KairosAdmin/api/login", api.adminLogin)
	router.Route("/KairosAdmin/api", func(admin chi.Router) {
		admin.Use(api.adminAuthenticate)
		admin.Get("/me", api.adminMe)
		admin.Post("/logout", api.adminLogout)
		admin.Get("/users", api.adminUsers)
		admin.Post("/users", api.adminCreateUser)
		admin.Put("/users/{user_id}/disabled", api.adminSetUserDisabled)
		admin.Put("/users/{user_id}/super-admin", api.adminSetSuperAdmin)
		admin.Get("/groups", api.adminGroups)
		admin.Post("/groups", api.adminCreateGroup)
		admin.Put("/groups/{group_id}/archived", api.adminSetGroupArchived)
		admin.Delete("/groups/{group_id}", api.adminDeleteGroup)
		admin.Get("/groups/{group_id}/accounts", api.adminGroupAccounts)
		admin.Post("/groups/{group_id}/accounts", api.adminCreateGroupAccount)
		admin.Put("/groups/{group_id}/accounts/{account_id}/role", api.adminSetAccountRole)
		admin.Post("/groups/{group_id}/accounts/{account_id}/bind", api.adminBindAccount)
		admin.Post("/groups/{group_id}/accounts/{account_id}/unbind", api.adminUnbindAccount)
		admin.Post("/groups/{group_id}/collaboration", api.adminEnableCollaboration)
		admin.Get("/groups/{group_id}/invites", api.adminListInvites)
		admin.Post("/groups/{group_id}/invites", api.adminCreateInvite)
		admin.Delete("/groups/{group_id}/invites/{invite_id}", api.adminRevokeInvite)
	})
	router.Route("/api/v1", func(v1 chi.Router) {
		v1.Post("/auth/login", api.login)
		v1.Post("/auth/refresh", api.refresh)
		v1.Post("/auth/logout", api.logout)
		v1.Group(func(protected chi.Router) {
			protected.Use(api.authenticate)
			protected.Get("/auth/me", api.me)
			protected.Get("/sync/snapshot", api.snapshot)
			protected.Get("/sync/changes", api.changes)
			protected.Post("/sync/push", api.push)
			protected.Get("/sync/status", api.syncStatus)
			protected.Get("/realtime", api.realtime)
			protected.Get("/tasks/{id}", api.taskDetail)
			protected.Get("/tasks/{id}/descendants", api.taskDescendants)
			protected.Get("/tags", api.taxonomyList("tag"))
			protected.Get("/projects", api.taxonomyList("project"))
			protected.Get("/checklist-groups", api.taxonomyList("checklist_group"))
		})
	})
	router.Route("/api/v2", func(v2 chi.Router) {
		v2.Group(func(protected chi.Router) {
			protected.Use(api.authenticate)
			protected.Get("/workspaces/{workspace_id}/sync/snapshot", api.workspaceSnapshot)
			protected.Get("/workspaces/{workspace_id}/sync/changes", api.workspaceChanges)
			protected.Post("/workspaces/{workspace_id}/sync/push", api.workspacePush)
			protected.Get("/workspaces/{workspace_id}/sync/status", api.workspaceSyncStatus)
			protected.Get("/workspaces", api.workspaces)
			protected.Get("/workspaces/{workspace_id}", api.workspaceDetail)
			protected.Post("/groups", api.createGroup)
			protected.Get("/groups/{group_id}", api.groupDetail)
			protected.Put("/groups/{group_id}/archived", api.setGroupArchived)
			protected.Delete("/groups/{group_id}", api.deleteGroup)
			protected.Get("/groups/{group_id}/accounts", api.groupAccounts)
			protected.Post("/groups/{group_id}/accounts", api.createGroupAccount)
			protected.Post("/groups/{group_id}/accounts/{account_id}/bind", api.bindGroupAccount)
			protected.Post("/groups/{group_id}/accounts/{account_id}/unbind", api.unbindGroupAccount)
			protected.Put("/groups/{group_id}/accounts/{account_id}/role", api.setGroupAccountRole)
			protected.Post("/groups/{group_id}/collaboration", api.enableCollaboration)
			protected.Get("/groups/{group_id}/invites", api.listInvites)
			protected.Post("/groups/{group_id}/invites", api.createInvite)
			protected.Delete("/groups/{group_id}/invites/{invite_id}", api.revokeInvite)
			protected.Post("/group-invites/redeem", api.redeemInvite)
		})
	})
	router.Route("/api/v3", func(v3 chi.Router) {
		v3.With(api.authenticate).Post("/central/tasks", api.centralTaskCreate)
	})
	return router
}

func (a *API) health(w http.ResponseWriter, r *http.Request) {
	status := "ok"
	redisStatus := "disabled"
	if a.redis != nil {
		redisStatus = "ok"
		if err := a.redis.Ping(r.Context()); err != nil {
			status = "degraded"
			redisStatus = "unavailable"
		}
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": status, "redis": redisStatus})
}

func (a *API) requireRedisDependency(w http.ResponseWriter, r *http.Request) bool {
	if a.redis == nil {
		writeError(w, r, http.StatusServiceUnavailable, "DEPENDENCY_UNAVAILABLE", "Redis 服务暂时不可用")
		return false
	}
	if err := a.redis.Ping(r.Context()); err != nil {
		writeError(w, r, http.StatusServiceUnavailable, "DEPENDENCY_UNAVAILABLE", "Redis 服务暂时不可用")
		return false
	}
	return true
}

func (a *API) ready(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	if err := a.store.Ping(ctx); err != nil {
		writeError(w, r, http.StatusServiceUnavailable, "DATABASE_UNAVAILABLE", "数据库尚未就绪")
		return
	}
	apiVersion, err := a.store.APIVersion(ctx)
	if err != nil || apiVersion != "v1" {
		writeError(w, r, http.StatusServiceUnavailable, "MIGRATION_REQUIRED", "数据库迁移尚未完成")
		return
	}
	if a.redisRequired {
		if a.redis == nil {
			writeError(w, r, http.StatusServiceUnavailable, "REDIS_UNAVAILABLE", "Redis 尚未就绪")
			return
		}
		if err := a.redis.Ping(ctx); err != nil {
			writeError(w, r, http.StatusServiceUnavailable, "REDIS_UNAVAILABLE", "Redis 尚未就绪")
			return
		}
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "ready"})
}

func (a *API) versionInfo(w http.ResponseWriter, r *http.Request) {
	apiVersion, err := a.store.APIVersion(r.Context())
	if err != nil {
		apiVersion = "unknown"
	}
	writeJSON(w, http.StatusOK, map[string]string{
		"service_version":   a.version,
		"api_version":       apiVersion,
		"migration_version": "1",
	})
}
