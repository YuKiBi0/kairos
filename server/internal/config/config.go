package config

import (
	"errors"
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"
)

type Config struct {
	Environment    string
	HTTPAddr       string
	DatabaseURL    string
	BaseURL        string
	SessionSecret  []byte
	AccessTTL      time.Duration
	RefreshTTL     time.Duration
	LogLevel       string
	CORSOrigins    []string
	RealtimeOrigin []string
}

func Load() (Config, error) {
	accessTTL, err := duration("KAIROS_ACCESS_TTL", 15*time.Minute)
	if err != nil {
		return Config{}, err
	}
	refreshTTL, err := duration("KAIROS_REFRESH_TTL", 30*24*time.Hour)
	if err != nil {
		return Config{}, err
	}

	databaseURL := strings.TrimSpace(os.Getenv("KAIROS_DATABASE_URL"))
	if databaseURL == "" {
		return Config{}, errors.New("KAIROS_DATABASE_URL is required")
	}
	secret := os.Getenv("KAIROS_SESSION_SECRET")
	if len(secret) < 32 {
		return Config{}, errors.New("KAIROS_SESSION_SECRET must be at least 32 characters")
	}

	return Config{
		Environment:   value("KAIROS_ENV", "production"),
		HTTPAddr:      value("KAIROS_HTTP_ADDR", "127.0.0.1:8080"),
		DatabaseURL:   databaseURL,
		BaseURL:       strings.TrimRight(value("KAIROS_BASE_URL", "http://127.0.0.1:8080"), "/"),
		SessionSecret: []byte(secret),
		AccessTTL:     accessTTL,
		RefreshTTL:    refreshTTL,
		LogLevel:      value("KAIROS_LOG_LEVEL", "info"),
		CORSOrigins:   csv(os.Getenv("KAIROS_CORS_ORIGINS")),
	}, nil
}

func value(key, fallback string) string {
	if current := strings.TrimSpace(os.Getenv(key)); current != "" {
		return current
	}
	return fallback
}

func duration(key string, fallback time.Duration) (time.Duration, error) {
	raw := strings.TrimSpace(os.Getenv(key))
	if raw == "" {
		return fallback, nil
	}
	parsed, err := time.ParseDuration(raw)
	if err != nil {
		return 0, fmt.Errorf("%s: %w", key, err)
	}
	return parsed, nil
}

func csv(raw string) []string {
	parts := strings.Split(raw, ",")
	result := make([]string, 0, len(parts))
	for _, part := range parts {
		if value := strings.TrimSpace(part); value != "" {
			result = append(result, value)
		}
	}
	return result
}

func Bool(key string, fallback bool) bool {
	raw := strings.TrimSpace(os.Getenv(key))
	if raw == "" {
		return fallback
	}
	parsed, err := strconv.ParseBool(raw)
	return err == nil && parsed
}
