//go:build integration

package httpapi

import (
	"bytes"
	"context"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"
	"time"

	"github.com/YuKiBi0/kairos/server/internal/auth"
	"github.com/YuKiBi0/kairos/server/internal/config"
	"github.com/YuKiBi0/kairos/server/internal/store"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

func TestWorkspaceSyncRoutesEnforceScope(t *testing.T) {
	databaseURL := os.Getenv("KAIROS_TEST_DATABASE_URL")
	if databaseURL == "" {
		t.Skip("KAIROS_TEST_DATABASE_URL is not set")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	database, err := store.Open(ctx, databaseURL)
	if err != nil {
		t.Fatal(err)
	}
	defer database.Close()
	owner, err := database.CreateUser(ctx, "workspace-api-owner-"+uuid.NewString(), "hash")
	if err != nil {
		t.Fatal(err)
	}
	other, err := database.CreateUser(ctx, "workspace-api-other-"+uuid.NewString(), "hash")
	if err != nil {
		t.Fatal(err)
	}
	group, _, _, err := database.CreateGroup(ctx, owner.ID, "workspace API group")
	if err != nil {
		t.Fatal(err)
	}
	defer cleanupWorkspaceAPI(databaseURL, group.ID, owner.ID, other.ID)
	spaces, err := database.ListAccessibleWorkspaces(ctx, owner.ID)
	if err != nil {
		t.Fatal(err)
	}
	var personal store.Workspace
	for _, space := range spaces {
		if space.Kind == "personal" {
			personal = space
		}
	}
	if personal.ID == uuid.Nil {
		t.Fatal("personal workspace missing")
	}
	secret := []byte("01234567890123456789012345678901")
	tokens := auth.NewTokenManager(secret, 15*time.Minute, "kairos-server")
	ownerToken, _, err := tokens.IssueAccess(owner.ID, uuid.New())
	if err != nil {
		t.Fatal(err)
	}
	otherToken, _, err := tokens.IssueAccess(other.ID, uuid.New())
	if err != nil {
		t.Fatal(err)
	}
	handler := New(database, config.Config{SessionSecret: secret, AccessTTL: time.Minute, RefreshTTL: time.Hour}, slog.New(slog.NewTextHandler(io.Discard, nil)), "test")
	server := httptest.NewServer(handler)
	defer server.Close()
	status, _ := requestAPI(t, http.MethodGet, server.URL+"/api/v2/workspaces/"+personal.ID.String()+"/sync/snapshot", ownerToken, nil)
	if status != http.StatusOK {
		t.Fatalf("owner snapshot failed: %d", status)
	}
	status, _ = requestAPI(t, http.MethodGet, server.URL+"/api/v2/workspaces/"+group.WorkspaceID.String()+"/sync/snapshot", otherToken, nil)
	if status != http.StatusForbidden {
		t.Fatalf("cross-user group snapshot should be forbidden: %d", status)
	}
	status, body := requestAPI(t, http.MethodGet, server.URL+"/api/v2/workspaces", ownerToken, nil)
	if status != http.StatusOK || !bytes.Contains(body, []byte(`"display_name":"个人任务"`)) {
		t.Fatalf("workspace catalog should include display name: status=%d body=%s", status, body)
	}
}

func cleanupWorkspaceAPI(databaseURL string, groupID uuid.UUID, userIDs ...uuid.UUID) {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	connection, err := pgx.Connect(ctx, databaseURL)
	if err != nil {
		return
	}
	defer connection.Close(ctx)
	_, _ = connection.Exec(ctx, `DELETE FROM audit_events WHERE group_id = $1 OR actor_user_id = ANY($2)`, groupID, userIDs)
	_, _ = connection.Exec(ctx, `DELETE FROM group_account_links WHERE group_id = $1`, groupID)
	_, _ = connection.Exec(ctx, `DELETE FROM group_accounts WHERE group_id = $1`, groupID)
	_, _ = connection.Exec(ctx, `DELETE FROM groups WHERE id = $1`, groupID)
	_, _ = connection.Exec(ctx, `DELETE FROM workspaces WHERE group_id = $1 OR owner_user_id = ANY($2)`, groupID, userIDs)
	_, _ = connection.Exec(ctx, `DELETE FROM users WHERE id = ANY($1)`, userIDs)
}
