package httpapi

import (
	"log/slog"
	"net/http"
	"time"

	"github.com/YuKiBi0/kairos/server/internal/auth"
	"github.com/YuKiBi0/kairos/server/internal/config"
	"github.com/YuKiBi0/kairos/server/internal/store"
	"github.com/go-chi/chi/v5"
)

type API struct {
	store      *store.Store
	tokens     *auth.TokenManager
	refreshTTL time.Duration
	logger     *slog.Logger
	version    string
}

func New(
	store *store.Store,
	config config.Config,
	logger *slog.Logger,
	version string,
) http.Handler {
	api := &API{
		store:      store,
		tokens:     auth.NewTokenManager(config.SessionSecret, config.AccessTTL, "kairos-server"),
		refreshTTL: config.RefreshTTL,
		logger:     logger,
		version:    version,
	}

	router := chi.NewRouter()
	router.Use(func(next http.Handler) http.Handler { return recoverPanics(logger, next) })
	router.Use(func(next http.Handler) http.Handler { return requestMetadata(logger, next) })
	router.Get("/healthz", api.health)
	router.Get("/readyz", api.ready)
	router.Get("/version", api.versionInfo)
	router.Route("/api/v1", func(v1 chi.Router) {
		v1.Post("/auth/login", api.login)
		v1.Post("/auth/refresh", api.refresh)
		v1.Post("/auth/logout", api.logout)
		v1.Group(func(protected chi.Router) {
			protected.Use(api.authenticate)
			protected.Get("/auth/me", api.me)
		})
	})
	return router
}

func (a *API) health(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

func (a *API) ready(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	if err := a.store.Ping(ctx); err != nil {
		writeError(w, r, http.StatusServiceUnavailable, "DATABASE_UNAVAILABLE", "数据库尚未就绪")
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "ready"})
}

func (a *API) versionInfo(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{
		"service_version":   a.version,
		"api_version":       "v1",
		"migration_version": "1",
	})
}
