package auth

import (
	"testing"
	"time"

	"github.com/google/uuid"
)

func TestAccessTokenScopesRoundTrip(t *testing.T) {
	manager := NewTokenManager([]byte("test-secret"), time.Hour, "kairos-server")
	userID, deviceID := uuid.New(), uuid.New()
	raw, _, err := manager.IssueAccessWithScopes(userID, deviceID, []string{"central:tasks:create"})
	if err != nil {
		t.Fatal(err)
	}
	gotUser, gotDevice, scopes, err := manager.ParseAccessWithScopes(raw)
	if err != nil {
		t.Fatal(err)
	}
	if gotUser != userID || gotDevice != deviceID || len(scopes) != 1 || scopes[0] != "central:tasks:create" {
		t.Fatalf("unexpected scoped claims: user=%s device=%s scopes=%v", gotUser, gotDevice, scopes)
	}
	plainUser, plainDevice, err := manager.ParseAccess(raw)
	if err != nil || plainUser != userID || plainDevice != deviceID {
		t.Fatalf("backward-compatible ParseAccess failed: %v", err)
	}
}
