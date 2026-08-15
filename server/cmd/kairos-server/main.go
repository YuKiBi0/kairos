package main

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"net/url"
	"os"
	"os/signal"
	"path/filepath"
	"strings"
	"syscall"
	"time"

	"github.com/YuKiBi0/kairos/server/internal/auth"
	"github.com/YuKiBi0/kairos/server/internal/config"
	"github.com/YuKiBi0/kairos/server/internal/httpapi"
	"github.com/YuKiBi0/kairos/server/internal/store"
	"github.com/golang-migrate/migrate/v4"
	_ "github.com/golang-migrate/migrate/v4/database/postgres"
	_ "github.com/golang-migrate/migrate/v4/source/file"
)

const version = "0.1.0"

func main() {
	if err := run(os.Args[1:]); err != nil {
		slog.Error("command_failed", "error", err.Error())
		os.Exit(1)
	}
}

func run(arguments []string) error {
	command := "serve"
	if len(arguments) > 0 {
		command = arguments[0]
	}
	cfg, err := config.Load()
	if err != nil {
		return err
	}
	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level: parseLogLevel(cfg.LogLevel),
	}))
	slog.SetDefault(logger)

	switch command {
	case "serve":
		return serve(cfg, logger)
	case "migrate":
		return migrateDatabase(cfg.DatabaseURL)
	case "create-user":
		if len(arguments) != 2 {
			return errors.New("usage: kairos-server create-user <username>")
		}
		return createUser(cfg, arguments[1])
	case "version":
		fmt.Println(version)
		return nil
	default:
		return fmt.Errorf("unknown command %q", command)
	}
}

func serve(cfg config.Config, logger *slog.Logger) error {
	ctx, cancel := signal.NotifyContext(
		context.Background(),
		os.Interrupt,
		syscall.SIGTERM,
	)
	defer cancel()

	database, err := store.Open(ctx, cfg.DatabaseURL)
	if err != nil {
		return err
	}
	defer database.Close()
	if err := database.Ping(ctx); err != nil {
		return fmt.Errorf("database readiness check: %w", err)
	}

	server := &http.Server{
		Addr:              cfg.HTTPAddr,
		Handler:           httpapi.New(database, cfg, logger, version),
		ReadHeaderTimeout: 10 * time.Second,
		ReadTimeout:       30 * time.Second,
		WriteTimeout:      30 * time.Second,
		IdleTimeout:       2 * time.Minute,
	}
	result := make(chan error, 1)
	go func() {
		logger.Info("server_started", "address", cfg.HTTPAddr, "version", version)
		result <- server.ListenAndServe()
	}()

	select {
	case <-ctx.Done():
		shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer shutdownCancel()
		return server.Shutdown(shutdownCtx)
	case err := <-result:
		if errors.Is(err, http.ErrServerClosed) {
			return nil
		}
		return err
	}
}

func migrateDatabase(databaseURL string) error {
	root, err := filepath.Abs("migrations")
	if err != nil {
		return fmt.Errorf("resolve migrations path: %w", err)
	}
	sourceURL := (&url.URL{Scheme: "file", Path: filepath.ToSlash(root)}).String()
	migrator, err := migrate.New(sourceURL, databaseURL)
	if err != nil {
		return fmt.Errorf("initialize migrations: %w", err)
	}
	defer func() {
		_, _ = migrator.Close()
	}()
	if err := migrator.Up(); err != nil && !errors.Is(err, migrate.ErrNoChange) {
		return fmt.Errorf("apply migrations: %w", err)
	}
	return nil
}

func createUser(cfg config.Config, username string) error {
	username = strings.TrimSpace(username)
	if username == "" || len(username) > 100 {
		return errors.New("username must contain between 1 and 100 characters")
	}
	password := os.Getenv("KAIROS_BOOTSTRAP_PASSWORD")
	if password == "" {
		return errors.New("KAIROS_BOOTSTRAP_PASSWORD is required for create-user")
	}
	hash, err := auth.HashPassword(password)
	if err != nil {
		return err
	}
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	database, err := store.Open(ctx, cfg.DatabaseURL)
	if err != nil {
		return err
	}
	defer database.Close()
	user, err := database.CreateUser(ctx, username, hash)
	if err != nil {
		return err
	}
	fmt.Printf("created user %s (%s)\n", user.Username, user.ID)
	return nil
}

func parseLogLevel(raw string) slog.Level {
	switch strings.ToLower(strings.TrimSpace(raw)) {
	case "debug":
		return slog.LevelDebug
	case "warn":
		return slog.LevelWarn
	case "error":
		return slog.LevelError
	default:
		return slog.LevelInfo
	}
}
