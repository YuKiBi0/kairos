package auth

import (
	"testing"
	"time"

	"github.com/google/uuid"
)

func TestAccessTokenContainsOnlySessionIdentity(t *testing.T) {
	manager := NewTokenManager([]byte("test-secret"), time.Hour, "kairos-server")
	userID, deviceID := uuid.New(), uuid.New()
	raw, _, err := manager.IssueAccess(userID, deviceID)
	if err != nil {
		t.Fatal(err)
	}
	gotUser, gotDevice, err := manager.ParseAccess(raw)
	if err != nil {
		t.Fatal(err)
	}
	if gotUser != userID || gotDevice != deviceID {
		t.Fatalf("unexpected claims: user=%s device=%s", gotUser, gotDevice)
	}
}
