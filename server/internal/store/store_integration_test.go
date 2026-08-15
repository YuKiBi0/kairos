//go:build integration

package store

import (
	"context"
	"os"
	"testing"
	"time"

	"github.com/YuKiBi0/kairos/server/internal/auth"
	"github.com/google/uuid"
)

func TestAuthenticationPersistence(t *testing.T) {
	databaseURL := os.Getenv("KAIROS_TEST_DATABASE_URL")
	if databaseURL == "" {
		t.Skip("KAIROS_TEST_DATABASE_URL is not set")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()
	database, err := Open(ctx, databaseURL)
	if err != nil {
		t.Fatal(err)
	}
	defer database.Close()

	username := "integration-" + uuid.NewString()
	passwordHash, err := auth.HashPassword("integration password 123")
	if err != nil {
		t.Fatal(err)
	}
	user, err := database.CreateUser(ctx, username, passwordHash)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		_, _ = database.pool.Exec(context.Background(), `DELETE FROM users WHERE id = $1`, user.ID)
	})

	deviceID := uuid.New()
	device, err := database.UpsertDevice(ctx, user.ID, &deviceID, "Windows test", "windows")
	if err != nil {
		t.Fatal(err)
	}
	if device.ID != deviceID {
		t.Fatalf("unexpected device id: %s", device.ID)
	}

	oldRaw, oldHash, err := auth.NewRefreshToken()
	if err != nil {
		t.Fatal(err)
	}
	if _, err := database.CreateSession(
		ctx,
		user.ID,
		device.ID,
		oldHash,
		time.Now().UTC().Add(time.Hour),
	); err != nil {
		t.Fatal(err)
	}
	_, newHash, err := auth.NewRefreshToken()
	if err != nil {
		t.Fatal(err)
	}
	rotated, err := database.RotateSession(
		ctx,
		auth.HashRefreshToken(oldRaw),
		newHash,
		time.Now().UTC().Add(2*time.Hour),
	)
	if err != nil {
		t.Fatal(err)
	}
	if rotated.UserID != user.ID || rotated.DeviceID != device.ID {
		t.Fatalf("unexpected rotated session: %#v", rotated)
	}
	if _, err := database.RotateSession(
		ctx,
		auth.HashRefreshToken(oldRaw),
		newHash,
		time.Now().UTC().Add(2*time.Hour),
	); err == nil {
		t.Fatal("old refresh token remained valid after rotation")
	}
}
