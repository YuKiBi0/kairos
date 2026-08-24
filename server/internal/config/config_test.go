package config

import "testing"

func TestLoadRejectsMissingSecrets(t *testing.T) {
	t.Setenv("KAIROS_DATABASE_URL", "")
	t.Setenv("KAIROS_SESSION_SECRET", "")
	if _, err := Load(); err == nil {
		t.Fatal("expected missing database URL to fail")
	}
}

func TestLoadAcceptsExplicitConfiguration(t *testing.T) {
	t.Setenv("KAIROS_DATABASE_URL", "postgres://example.invalid/kairos")
	t.Setenv("KAIROS_SESSION_SECRET", "01234567890123456789012345678901")
	t.Setenv("KAIROS_ACCESS_TTL", "5m")
	t.Setenv("KAIROS_MIGRATIONS_DIR", "custom-migrations")
	t.Setenv("KAIROS_BOOTSTRAP_USERNAME", "owner")
	t.Setenv("KAIROS_BOOTSTRAP_PASSWORD", "account-password")
	config, err := Load()
	if err != nil {
		t.Fatal(err)
	}
	if config.AccessTTL.String() != "5m0s" {
		t.Fatalf("unexpected access ttl: %s", config.AccessTTL)
	}
	if config.MigrationsDir != "custom-migrations" {
		t.Fatalf("unexpected migrations directory: %s", config.MigrationsDir)
	}
	if config.BootstrapUsername != "owner" || config.BootstrapPassword != "account-password" {
		t.Fatal("bootstrap credentials were not loaded")
	}
	if config.RedisURL != "redis://127.0.0.1:6379/0" || config.RedisRequired {
		t.Fatalf("unexpected redis defaults: url=%q required=%v", config.RedisURL, config.RedisRequired)
	}
}

func TestLoadAcceptsRedisConfiguration(t *testing.T) {
	t.Setenv("KAIROS_DATABASE_URL", "postgres://example.invalid/kairos")
	t.Setenv("KAIROS_SESSION_SECRET", "01234567890123456789012345678901")
	t.Setenv("KAIROS_REDIS_URL", "rediss://:secret@example.invalid:6380/2")
	t.Setenv("KAIROS_REDIS_REQUIRED", "true")
	t.Setenv("KAIROS_REDIS_DIAL_TIMEOUT", "2s")
	t.Setenv("KAIROS_REDIS_COMMAND_TIMEOUT", "3s")
	config, err := Load()
	if err != nil {
		t.Fatal(err)
	}
	if config.RedisURL != "rediss://:secret@example.invalid:6380/2" || !config.RedisRequired {
		t.Fatalf("redis configuration was not loaded: %+v", config)
	}
	if config.RedisDialTimeout.String() != "2s" || config.RedisCommandTimeout.String() != "3s" {
		t.Fatalf("unexpected redis timeouts: %s %s", config.RedisDialTimeout, config.RedisCommandTimeout)
	}
}

func TestLoadRejectsInvalidRedisRequired(t *testing.T) {
	t.Setenv("KAIROS_DATABASE_URL", "postgres://example.invalid/kairos")
	t.Setenv("KAIROS_SESSION_SECRET", "01234567890123456789012345678901")
	t.Setenv("KAIROS_REDIS_REQUIRED", "sometimes")
	if _, err := Load(); err == nil {
		t.Fatal("expected invalid redis required value to fail")
	}
}
