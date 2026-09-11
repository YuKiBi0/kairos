//go:build !windows

package app

import (
	"os"
	"testing"
)

func TestUnixCredentialsPersistWithoutExternalKey(t *testing.T) {
	t.Setenv("XDG_CONFIG_HOME", t.TempDir())
	want := Credentials{AccessToken: "access", RefreshToken: "refresh", ExpiresAt: "2099-01-01T00:00:00Z"}
	if err := SaveCredentials("prod", want); err != nil {
		t.Fatal(err)
	}
	got, err := LoadCredentials("prod")
	if err != nil {
		t.Fatal(err)
	}
	if got != want {
		t.Fatalf("credentials did not persist: got %#v want %#v", got, want)
	}
	info, err := os.Stat(credentialPath())
	if err != nil {
		t.Fatal(err)
	}
	if info.Mode().Perm() != 0o600 {
		t.Fatalf("credential permissions = %o, want 600", info.Mode().Perm())
	}
}
