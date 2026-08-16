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
}
