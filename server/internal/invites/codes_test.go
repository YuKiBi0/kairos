package invites

import (
	"bytes"
	"testing"
)

func TestGenerateReturnsOpaqueCodeAndStableDigest(t *testing.T) {
	secret := []byte("01234567890123456789012345678901")
	raw, digest, err := Generate(secret)
	if err != nil {
		t.Fatal(err)
	}
	if len(raw) != 32 {
		t.Fatalf("unexpected encoded code length: %d", len(raw))
	}
	if !bytes.Equal(digest, Digest(secret, raw)) {
		t.Fatal("generated digest is not stable")
	}
	if bytes.Contains(digest, []byte(raw)) {
		t.Fatal("digest leaked the raw invite code")
	}
}

func TestGenerateRejectsShortSecret(t *testing.T) {
	if _, _, err := Generate([]byte("short")); err == nil {
		t.Fatal("expected a short secret to fail")
	}
}
