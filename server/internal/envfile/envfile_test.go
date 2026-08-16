package envfile

import (
	"os"
	"path/filepath"
	"testing"
)

func TestLoadOverwritesEnvironmentFromDotenvFile(t *testing.T) {
	path := filepath.Join(t.TempDir(), "kairos.env")
	contents := "\ufeff# comment\r\n" +
		"KAIROS_DATABASE_URL=postgres://kairos:p%40ss@localhost/kairos\r\n" +
		"export KAIROS_BOOTSTRAP_USERNAME='owner'\r\n" +
		"KAIROS_BOOTSTRAP_PASSWORD=\"literal$password\"\r\n" +
		"EMPTY_VALUE= # optional value\r\n"
	if err := os.WriteFile(path, []byte(contents), 0o600); err != nil {
		t.Fatal(err)
	}
	t.Setenv("KAIROS_BOOTSTRAP_USERNAME", "old-value")

	if err := Load(path); err != nil {
		t.Fatal(err)
	}
	if value := os.Getenv("KAIROS_BOOTSTRAP_USERNAME"); value != "owner" {
		t.Fatalf("unexpected username: %q", value)
	}
	if value := os.Getenv("KAIROS_BOOTSTRAP_PASSWORD"); value != "literal$password" {
		t.Fatalf("unexpected password: %q", value)
	}
	if value := os.Getenv("EMPTY_VALUE"); value != "" {
		t.Fatalf("unexpected empty value: %q", value)
	}
}

func TestLoadRejectsInvalidLinesWithoutApplyingPartialValues(t *testing.T) {
	path := filepath.Join(t.TempDir(), "kairos.env")
	if err := os.WriteFile(path, []byte("VALID=value\nnot valid\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	t.Setenv("VALID", "original")

	if err := Load(path); err == nil {
		t.Fatal("expected invalid environment file to fail")
	}
	if value := os.Getenv("VALID"); value != "original" {
		t.Fatalf("partially applied value: %q", value)
	}
}
