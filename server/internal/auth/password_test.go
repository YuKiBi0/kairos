package auth

import (
	"testing"
	"time"

	"github.com/google/uuid"
)

func TestPasswordHashAndVerification(t *testing.T) {
	hash, err := HashPassword("correct horse battery staple")
	if err != nil {
		t.Fatal(err)
	}
	valid, err := VerifyPassword(hash, "correct horse battery staple")
	if err != nil || !valid {
		t.Fatalf("expected password to verify: valid=%v err=%v", valid, err)
	}
	valid, err = VerifyPassword(hash, "incorrect password")
	if err != nil {
		t.Fatal(err)
	}
	if valid {
		t.Fatal("incorrect password verified")
	}
}

func TestAccessTokenRoundTrip(t *testing.T) {
	manager := NewTokenManager([]byte("01234567890123456789012345678901"), time.Minute, "kairos-test")
	userID := uuid.New()
	deviceID := uuid.New()
	raw, _, err := manager.IssueAccess(userID, deviceID)
	if err != nil {
		t.Fatal(err)
	}
	actualUserID, actualDeviceID, err := manager.ParseAccess(raw)
	if err != nil {
		t.Fatal(err)
	}
	if actualUserID != userID || actualDeviceID != deviceID {
		t.Fatalf("unexpected claims: user=%s device=%s", actualUserID, actualDeviceID)
	}
}
