//go:build integration

package store

import (
	"context"
	"encoding/json"
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

func TestSyncOperationsAndConflicts(t *testing.T) {
	databaseURL := os.Getenv("KAIROS_TEST_DATABASE_URL")
	if databaseURL == "" {
		t.Skip("KAIROS_TEST_DATABASE_URL is not set")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	database, err := Open(ctx, databaseURL)
	if err != nil {
		t.Fatal(err)
	}
	defer database.Close()

	passwordHash, err := auth.HashPassword("integration password 123")
	if err != nil {
		t.Fatal(err)
	}
	user, err := database.CreateUser(ctx, "sync-"+uuid.NewString(), passwordHash)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		_, _ = database.pool.Exec(context.Background(), `DELETE FROM users WHERE id = $1`, user.ID)
	})
	device, err := database.UpsertDevice(ctx, user.ID, nil, "sync test", "windows")
	if err != nil {
		t.Fatal(err)
	}

	tagID := uuid.New()
	tagCreate := operation("tag", tagID, 0, map[string]any{
		"name":        "work",
		"color_token": "moss",
		"archived":    false,
	})
	if result, err := database.ApplyOperation(ctx, user.ID, device.ID, tagCreate); err != nil || result.Status != "applied" {
		t.Fatalf("create tag: result=%#v err=%v", result, err)
	}

	rootID := uuid.New()
	create := operation("task", rootID, 0, map[string]any{
		"title":      "Root task",
		"quadrant":   2,
		"status":     0,
		"sort_order": 0,
		"tag_ids":    []string{tagID.String()},
	})
	created, err := database.ApplyOperation(ctx, user.ID, device.ID, create)
	if err != nil || created.Status != "applied" || created.Version != 1 {
		t.Fatalf("create task: result=%#v err=%v", created, err)
	}
	duplicate, err := database.ApplyOperation(ctx, user.ID, device.ID, create)
	if err != nil || duplicate.Status != "duplicate" || duplicate.Version != 1 {
		t.Fatalf("duplicate task: result=%#v err=%v", duplicate, err)
	}

	titleUpdate := operation("task", rootID, 1, map[string]any{"title": "Renamed root"})
	updated, err := database.ApplyOperation(ctx, user.ID, device.ID, titleUpdate)
	if err != nil || updated.Status != "applied" || updated.Version != 2 {
		t.Fatalf("update title: result=%#v err=%v", updated, err)
	}
	descriptionUpdate := operation(
		"task",
		rootID,
		1,
		map[string]any{"description": "Merged from another device"},
	)
	merged, err := database.ApplyOperation(ctx, user.ID, device.ID, descriptionUpdate)
	if err != nil || merged.Status != "applied" || merged.Version != 3 {
		t.Fatalf("merge description: result=%#v err=%v", merged, err)
	}
	conflictingUpdate := operation("task", rootID, 1, map[string]any{"title": "Conflict"})
	conflict, err := database.ApplyOperation(ctx, user.ID, device.ID, conflictingUpdate)
	if err != nil || conflict.Status != "conflict" || len(conflict.ConflictingFields) != 1 {
		t.Fatalf("title conflict: result=%#v err=%v", conflict, err)
	}

	parentID := rootID
	for depth := 2; depth <= 5; depth++ {
		childID := uuid.New()
		child := operation("task", childID, 0, map[string]any{
			"title":      "Child",
			"parent_id":  parentID.String(),
			"quadrant":   2,
			"status":     0,
			"sort_order": 0,
		})
		result, err := database.ApplyOperation(ctx, user.ID, device.ID, child)
		if err != nil || result.Status != "applied" {
			t.Fatalf("create depth %d: result=%#v err=%v", depth, result, err)
		}
		parentID = childID
	}
	sixth := operation("task", uuid.New(), 0, map[string]any{
		"title":      "Too deep",
		"parent_id":  parentID.String(),
		"quadrant":   2,
		"status":     0,
		"sort_order": 0,
	})
	rejected, err := database.ApplyOperation(ctx, user.ID, device.ID, sixth)
	if err != nil || rejected.Status != "rejected" || rejected.Code != "DEPTH_LIMIT" {
		t.Fatalf("sixth level: result=%#v err=%v", rejected, err)
	}

	blocker := operation("blocker", uuid.New(), 0, map[string]any{
		"task_id":  rootID.String(),
		"body":     "Waiting for review",
		"resolved": false,
	})
	if result, err := database.ApplyOperation(ctx, user.ID, device.ID, blocker); err != nil || result.Status != "applied" {
		t.Fatalf("create blocker: result=%#v err=%v", result, err)
	}

	snapshot, err := database.Snapshot(ctx, user.ID)
	if err != nil {
		t.Fatal(err)
	}
	if len(snapshot.Tasks) != 5 || len(snapshot.Tags) != 1 || len(snapshot.Blockers) != 1 {
		t.Fatalf("unexpected snapshot sizes: tasks=%d tags=%d blockers=%d", len(snapshot.Tasks), len(snapshot.Tags), len(snapshot.Blockers))
	}
	changes, next, hasMore, err := database.Changes(ctx, user.ID, 0, 3)
	if err != nil {
		t.Fatal(err)
	}
	if len(changes) != 3 || next == 0 || !hasMore {
		t.Fatalf("unexpected changes page: count=%d next=%d has_more=%v", len(changes), next, hasMore)
	}
}

func operation(
	entityType string,
	entityID uuid.UUID,
	baseVersion int64,
	changes map[string]any,
) PushOperation {
	encoded := make(map[string]json.RawMessage, len(changes))
	fields := make([]string, 0, len(changes))
	for key, value := range changes {
		raw, err := json.Marshal(value)
		if err != nil {
			panic(err)
		}
		encoded[key] = raw
		fields = append(fields, key)
	}
	return PushOperation{
		OperationID:   uuid.New(),
		EntityType:    entityType,
		EntityID:      entityID,
		BaseVersion:   baseVersion,
		Changes:       encoded,
		ChangedFields: fields,
	}
}
