//go:build integration

package store

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"testing"
	"time"

	"github.com/google/uuid"
)

func TestWorkspaceSnapshotIsolatedFromOtherSpaces(t *testing.T) {
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
	owner, err := database.CreateUser(ctx, "workspace-owner-"+uuid.NewString(), "hash")
	if err != nil {
		t.Fatal(err)
	}
	other, err := database.CreateUser(ctx, "workspace-other-"+uuid.NewString(), "hash")
	if err != nil {
		t.Fatal(err)
	}
	group, _, _, err := database.CreateGroup(ctx, owner.ID, "Workspace group")
	if err != nil {
		t.Fatal(err)
	}
	defer cleanupGroupFixture(database, group.ID, owner.ID, other.ID)
	spaces, err := database.ListAccessibleWorkspaces(ctx, owner.ID)
	if err != nil {
		t.Fatal(err)
	}
	var personal Workspace
	for _, space := range spaces {
		if space.Kind == "personal" {
			personal = space
		}
	}
	if personal.ID == uuid.Nil {
		t.Fatal("personal workspace was not created")
	}
	taskID := uuid.New()
	device, err := database.UpsertDevice(ctx, owner.ID, nil, "workspace-test", "test")
	if err != nil {
		t.Fatal(err)
	}
	result, err := database.ApplyOperation(ctx, owner.ID, device.ID, PushOperation{
		OperationID: uuid.New(),
		EntityType:  "task",
		EntityID:    taskID,
		BaseVersion: 0,
		Changes: map[string]json.RawMessage{
			"title":      json.RawMessage(`"personal task"`),
			"quadrant":   json.RawMessage(`2`),
			"status":     json.RawMessage(`0`),
			"sort_order": json.RawMessage(`0`),
		},
		ChangedFields: []string{"title", "quadrant", "status", "sort_order"},
	})
	if err != nil || result.Status != "applied" {
		t.Fatalf("failed to create personal task: result=%#v err=%v", result, err)
	}
	snapshot, err := database.WorkspaceSnapshot(ctx, personal.ID)
	if err != nil {
		t.Fatal(err)
	}
	if len(snapshot.Tasks) != 1 {
		t.Fatalf("personal snapshot should contain one task: %#v", snapshot.Tasks)
	}
	if _, err := database.WorkspaceForUser(ctx, other.ID, group.WorkspaceID); err == nil {
		t.Fatal("other user should not access group workspace")
	}
	groupSnapshot, err := database.WorkspaceSnapshot(ctx, group.WorkspaceID)
	if err != nil {
		t.Fatal(err)
	}
	if len(groupSnapshot.Tasks) != 0 {
		t.Fatalf("group snapshot should not contain personal task: %#v", groupSnapshot.Tasks)
	}
	changes, _, _, _, err := database.WorkspaceChanges(ctx, personal.ID, 0, 20)
	if err != nil {
		t.Fatal(err)
	}
	if len(changes) != 1 || changes[0].EntityID != taskID {
		t.Fatalf("unexpected workspace changes: %#v", changes)
	}
}

func TestGroupTaskSharingRequiresCollaborationAndExplicitShare(t *testing.T) {
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
	owner, err := database.CreateUser(ctx, "sharing-owner-"+uuid.NewString(), "hash")
	if err != nil {
		t.Fatal(err)
	}
	member, err := database.CreateUser(ctx, "sharing-member-"+uuid.NewString(), "hash")
	if err != nil {
		t.Fatal(err)
	}
	group, _, _, err := database.CreateGroup(ctx, owner.ID, "Sharing group")
	if err != nil {
		t.Fatal(err)
	}
	defer cleanupGroupFixture(database, group.ID, owner.ID, member.ID)
	account, err := database.CreateGroupAccount(ctx, owner.ID, group.ID, "member", "Member", "L1")
	if err != nil {
		t.Fatal(err)
	}
	if _, err := database.BindGroupAccount(ctx, owner.ID, group.ID, account.ID, member.ID); err != nil {
		t.Fatal(err)
	}
	ownerDevice, err := database.UpsertDevice(ctx, owner.ID, nil, "sharing-owner", "test")
	if err != nil {
		t.Fatal(err)
	}
	memberDevice, err := database.UpsertDevice(ctx, member.ID, nil, "sharing-member", "test")
	if err != nil {
		t.Fatal(err)
	}
	taskID := uuid.New()
	created, err := database.ApplyWorkspaceOperation(ctx, owner.ID, ownerDevice.ID, group.WorkspaceID, PushOperation{
		OperationID: uuid.New(), EntityType: "task", EntityID: taskID,
		Changes: map[string]json.RawMessage{
			"title": json.RawMessage(`"private task"`), "quadrant": json.RawMessage(`2`),
			"status": json.RawMessage(`0`), "sort_order": json.RawMessage(`0`),
		}, ChangedFields: []string{"title", "quadrant", "status", "sort_order"},
	})
	if err != nil || created.Status != "applied" {
		t.Fatalf("failed to create private group task: result=%#v err=%v", created, err)
	}
	var createdEntity map[string]any
	if err := json.Unmarshal(created.ServerEntity, &createdEntity); err != nil {
		t.Fatal(err)
	}
	for _, field := range []string{"group_account_id", "created_by_user_id", "last_operated_by_user_id"} {
		if createdEntity[field] == nil {
			t.Fatalf("group task should record %s: %#v", field, createdEntity)
		}
	}
	memberSnapshot, err := database.WorkspaceSnapshot(ctx, group.WorkspaceID, member.ID)
	if err != nil {
		t.Fatal(err)
	}
	if len(memberSnapshot.Tasks) != 0 {
		t.Fatalf("private task leaked before sharing: %#v", memberSnapshot.Tasks)
	}
	denied, err := database.ApplyWorkspaceOperation(ctx, member.ID, memberDevice.ID, group.WorkspaceID, PushOperation{
		OperationID: uuid.New(), EntityType: "task", EntityID: taskID, BaseVersion: created.Version,
		Changes: map[string]json.RawMessage{"title": json.RawMessage(`"forbidden"`)}, ChangedFields: []string{"title"},
	})
	if err != nil || denied.Status != "rejected" || denied.Code != "FORBIDDEN_SCOPE" {
		t.Fatalf("private task write should be rejected: result=%#v err=%v", denied, err)
	}
	bypass, err := database.ApplyWorkspaceOperation(ctx, owner.ID, ownerDevice.ID, group.WorkspaceID, PushOperation{
		OperationID: uuid.New(), EntityType: "task", EntityID: taskID, BaseVersion: created.Version,
		Changes: map[string]json.RawMessage{"shared_at": json.RawMessage(fmt.Sprintf("%q", time.Now().UTC().Format(time.RFC3339Nano)))},
	})
	if err != nil || bypass.Status != "rejected" || bypass.Code != "COLLABORATION_DISABLED" {
		t.Fatalf("omitted changed_fields must not bypass collaboration: result=%#v err=%v", bypass, err)
	}
	if err := database.SetCollaborationEnabled(ctx, owner.ID, group.ID); err != nil {
		t.Fatal(err)
	}
	sharedAt := time.Now().UTC().Format(time.RFC3339Nano)
	shared, err := database.ApplyWorkspaceOperation(ctx, owner.ID, ownerDevice.ID, group.WorkspaceID, PushOperation{
		OperationID: uuid.New(), EntityType: "task", EntityID: taskID, BaseVersion: created.Version,
		Changes: map[string]json.RawMessage{"shared_at": json.RawMessage(fmt.Sprintf("%q", sharedAt))}, ChangedFields: []string{"shared_at"},
	})
	if err != nil || shared.Status != "applied" {
		t.Fatalf("explicit sharing failed: result=%#v err=%v", shared, err)
	}
	memberSnapshot, err = database.WorkspaceSnapshot(ctx, group.WorkspaceID, member.ID)
	if err != nil {
		t.Fatal(err)
	}
	if len(memberSnapshot.Tasks) != 1 {
		t.Fatalf("shared task should be visible: %#v", memberSnapshot.Tasks)
	}
	updated, err := database.ApplyWorkspaceOperation(ctx, member.ID, memberDevice.ID, group.WorkspaceID, PushOperation{
		OperationID: uuid.New(), EntityType: "task", EntityID: taskID, BaseVersion: shared.Version,
		Changes: map[string]json.RawMessage{"title": json.RawMessage(`"collaborative task"`)}, ChangedFields: []string{"title"},
	})
	if err != nil || updated.Status != "applied" {
		t.Fatalf("shared task should accept member edits: result=%#v err=%v", updated, err)
	}
	var updatedEntity map[string]any
	if err := json.Unmarshal(updated.ServerEntity, &updatedEntity); err != nil {
		t.Fatal(err)
	}
	if updatedEntity["last_operated_by_user_id"] != member.ID.String() {
		t.Fatalf("member edit should record the last operator: %#v", updatedEntity)
	}
	_, err = database.ApplyWorkspaceOperation(ctx, owner.ID, ownerDevice.ID, group.WorkspaceID, PushOperation{
		OperationID: uuid.New(), EntityType: "task", EntityID: taskID, BaseVersion: updated.Version,
		Changes: map[string]json.RawMessage{"shared_at": json.RawMessage(`null`)}, ChangedFields: []string{"shared_at"},
	})
	if err != nil {
		t.Fatal(err)
	}
	memberSnapshot, err = database.WorkspaceSnapshot(ctx, group.WorkspaceID, member.ID)
	if err != nil {
		t.Fatal(err)
	}
	if len(memberSnapshot.Tasks) != 0 {
		t.Fatalf("unshared task should no longer be visible: %#v", memberSnapshot.Tasks)
	}
	changes, _, _, _, err := database.WorkspaceChanges(ctx, group.WorkspaceID, 0, 20, member.ID)
	if err != nil {
		t.Fatal(err)
	}
	lastTaskChange := SyncChange{}
	for _, change := range changes {
		if change.EntityID == taskID {
			lastTaskChange = change
		}
	}
	if !lastTaskChange.Deleted || len(lastTaskChange.Entity) != 0 {
		t.Fatalf("unshared task should produce a viewer tombstone: %#v", lastTaskChange)
	}
}

func TestWorkspacePushWritesOnlyToSelectedGroupWorkspace(t *testing.T) {
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
	owner, err := database.CreateUser(ctx, "workspace-push-owner-"+uuid.NewString(), "hash")
	if err != nil {
		t.Fatal(err)
	}
	group, _, _, err := database.CreateGroup(ctx, owner.ID, "workspace push group")
	if err != nil {
		t.Fatal(err)
	}
	defer func() {
		_, _ = database.pool.Exec(ctx, `DELETE FROM task_tags WHERE workspace_id = $1`, group.WorkspaceID)
		_, _ = database.pool.Exec(ctx, `DELETE FROM blockers WHERE workspace_id = $1`, group.WorkspaceID)
		_, _ = database.pool.Exec(ctx, `DELETE FROM tasks WHERE workspace_id = $1`, group.WorkspaceID)
		_, _ = database.pool.Exec(ctx, `DELETE FROM tags WHERE workspace_id = $1`, group.WorkspaceID)
		_, _ = database.pool.Exec(ctx, `DELETE FROM projects WHERE workspace_id = $1`, group.WorkspaceID)
		_, _ = database.pool.Exec(ctx, `DELETE FROM checklist_groups WHERE workspace_id = $1`, group.WorkspaceID)
		cleanupGroupFixture(database, group.ID, owner.ID)
	}()
	device, err := database.UpsertDevice(ctx, owner.ID, nil, "workspace-push", "test")
	if err != nil {
		t.Fatal(err)
	}
	taskID := uuid.New()
	result, err := database.ApplyWorkspaceOperation(ctx, owner.ID, device.ID, group.WorkspaceID, PushOperation{
		OperationID: uuid.New(), EntityType: "task", EntityID: taskID,
		Changes: map[string]json.RawMessage{
			"title": json.RawMessage(`"group task"`), "quadrant": json.RawMessage(`2`),
			"status": json.RawMessage(`0`), "sort_order": json.RawMessage(`0`),
		}, ChangedFields: []string{"title", "quadrant", "status", "sort_order"},
	})
	if err != nil || result.Status != "applied" {
		t.Fatalf("group push failed: result=%#v err=%v", result, err)
	}
	personalID, err := database.personalWorkspaceID(ctx, owner.ID)
	if err != nil {
		t.Fatal(err)
	}
	personal, err := database.WorkspaceSnapshot(ctx, personalID)
	if err != nil {
		t.Fatal(err)
	}
	groupSnapshot, err := database.WorkspaceSnapshot(ctx, group.WorkspaceID)
	if err != nil {
		t.Fatal(err)
	}
	if len(personal.Tasks) != 0 || len(groupSnapshot.Tasks) != 1 {
		t.Fatalf("workspace push leaked across scopes: personal=%d group=%d", len(personal.Tasks), len(groupSnapshot.Tasks))
	}
	duplicate, err := database.ApplyWorkspaceOperation(ctx, owner.ID, device.ID, group.WorkspaceID, PushOperation{
		OperationID: result.OperationID, EntityType: "task", EntityID: taskID,
	})
	if err != nil || duplicate.Status != "duplicate" {
		t.Fatalf("group push idempotency failed: result=%#v err=%v", duplicate, err)
	}
}
