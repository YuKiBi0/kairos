//go:build integration

package httpapi

import (
	"context"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/YuKiBi0/kairos/server/internal/auth"
	"github.com/YuKiBi0/kairos/server/internal/config"
	"github.com/YuKiBi0/kairos/server/internal/store"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

func TestCentralTaskDelegationAuthorizationOwnershipIdempotencyAndAudit(t *testing.T) {
	databaseURL := os.Getenv("KAIROS_TEST_DATABASE_URL")
	if databaseURL == "" {
		t.Skip("KAIROS_TEST_DATABASE_URL is not set")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 45*time.Second)
	defer cancel()
	database, err := store.Open(ctx, databaseURL)
	if err != nil {
		t.Fatal(err)
	}
	defer database.Close()
	hash, err := auth.HashPassword("central integration password")
	if err != nil {
		t.Fatal(err)
	}
	actor, err := database.CreateUser(ctx, "central-actor-"+uuid.NewString(), hash)
	if err != nil {
		t.Fatal(err)
	}
	target, err := database.CreateUser(ctx, "central-target-"+uuid.NewString(), hash)
	if err != nil {
		t.Fatal(err)
	}
	outsider, err := database.CreateUser(ctx, "central-outsider-"+uuid.NewString(), hash)
	if err != nil {
		t.Fatal(err)
	}
	group, _, _, err := database.CreateGroup(ctx, actor.ID, "central integration group")
	if err != nil {
		t.Fatal(err)
	}
	account, err := database.CreateGroupAccount(ctx, actor.ID, group.ID, "central-target", "Central Target", "L1")
	if err != nil {
		t.Fatal(err)
	}
	if _, err := database.BindGroupAccount(ctx, actor.ID, group.ID, account.ID, target.ID); err != nil {
		t.Fatal(err)
	}
	connection, err := pgx.Connect(ctx, databaseURL)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := connection.Exec(ctx, `INSERT INTO server_roles(user_id,role,active) VALUES($1,'L3',true) ON CONFLICT(user_id) DO UPDATE SET role='L3',active=true`, actor.ID); err != nil {
		_ = connection.Close(ctx)
		t.Fatal(err)
	}
	_ = connection.Close(ctx)
	defer func() {
		cleanup, err := pgx.Connect(context.Background(), databaseURL)
		if err == nil {
			cleanupCtx := context.Background()
			tx, txErr := cleanup.Begin(cleanupCtx)
			if txErr == nil {
				_, _ = tx.Exec(cleanupCtx, `SET CONSTRAINTS ALL DEFERRED`)
				_, _ = tx.Exec(cleanupCtx, `DELETE FROM audit_events WHERE group_id=$1 OR actor_user_id=$2`, group.ID, actor.ID)
				_, _ = tx.Exec(cleanupCtx, `DELETE FROM sync_operations WHERE workspace_id=$1`, group.WorkspaceID)
				_, _ = tx.Exec(cleanupCtx, `DELETE FROM sync_changes WHERE workspace_id=$1`, group.WorkspaceID)
				_, _ = tx.Exec(cleanupCtx, `DELETE FROM tasks WHERE workspace_id=$1`, group.WorkspaceID)
				_, _ = tx.Exec(cleanupCtx, `DELETE FROM group_account_links WHERE group_id=$1`, group.ID)
				_, _ = tx.Exec(cleanupCtx, `DELETE FROM group_accounts WHERE group_id=$1`, group.ID)
				_, _ = tx.Exec(cleanupCtx, `DELETE FROM groups WHERE id=$1`, group.ID)
				_, _ = tx.Exec(cleanupCtx, `DELETE FROM workspaces WHERE id=$1 OR owner_user_id=ANY($2)`, group.WorkspaceID, []uuid.UUID{actor.ID, target.ID, outsider.ID})
				_, _ = tx.Exec(cleanupCtx, `DELETE FROM server_roles WHERE user_id=$1`, actor.ID)
				_, _ = tx.Exec(cleanupCtx, `DELETE FROM users WHERE id = ANY($1)`, []uuid.UUID{actor.ID, target.ID, outsider.ID})
				_ = tx.Commit(cleanupCtx)
			}
			_ = cleanup.Close(context.Background())
		}
	}()

	secret := []byte("01234567890123456789012345678901")
	tokens := auth.NewTokenManager(secret, 15*time.Minute, "kairos-server")
	actorDevice, err := database.UpsertDevice(ctx, actor.ID, nil, "central-test", "windows")
	if err != nil {
		t.Fatal(err)
	}
	regularToken, _, err := tokens.IssueAccess(actor.ID, actorDevice.ID)
	if err != nil {
		t.Fatal(err)
	}
	handler := New(database, config.Config{SessionSecret: secret, AccessTTL: 15 * time.Minute, RefreshTTL: time.Hour}, slog.New(slog.NewTextHandler(io.Discard, nil)), "test")
	server := httptest.NewServer(handler)
	defer server.Close()
	status, body := requestAPI(t, http.MethodPost, server.URL+"/api/v3/tokens", regularToken, map[string]string{"scope": "task:read"})
	if status != http.StatusBadRequest || !containsJSON(body, `UNSUPPORTED_SCOPE`) {
		t.Fatalf("token endpoint should reject unsupported scope: status=%d body=%s", status, body)
	}
	status, body = requestAPI(t, http.MethodPost, server.URL+"/api/v3/tokens", regularToken, map[string]string{"scope": "central:tasks:create", "expires_in": "2h"})
	if status != http.StatusCreated {
		t.Fatalf("central token issuance failed: status=%d body=%s", status, body)
	}
	var tokenResponse map[string]any
	if err := json.Unmarshal(body, &tokenResponse); err != nil {
		t.Fatal(err)
	}
	centralToken, ok := tokenResponse["access_token"].(string)
	if !ok || centralToken == "" {
		t.Fatalf("central token response missing access_token: %#v", tokenResponse)
	}
	status, body = requestAPI(t, http.MethodPost, server.URL+"/api/v3/tokens", centralToken, map[string]string{"scope": "central:tasks:create"})
	if status != http.StatusForbidden || !containsJSON(body, `FORBIDDEN_SCOPE`) {
		t.Fatalf("central token must not mint another central token: status=%d body=%s", status, body)
	}
	payload := map[string]any{
		"group_id": group.ID, "workspace_id": group.WorkspaceID, "creator_user_id": target.ID,
		"title": "delegated task", "description": "created by central agent", "source_agent_id": "agent-1",
		"idempotency_key": uuid.New(),
	}
	status, body = requestAPI(t, http.MethodPost, server.URL+"/api/v3/central/tasks", regularToken, payload)
	if status != http.StatusForbidden {
		t.Fatalf("regular token should be denied, got %d", status)
	}
	nonMemberPayload := map[string]any{}
	for key, value := range payload {
		nonMemberPayload[key] = value
	}
	nonMemberPayload["creator_user_id"] = outsider.ID
	nonMemberPayload["idempotency_key"] = uuid.New()
	status, body = requestAPI(t, http.MethodPost, server.URL+"/api/v3/central/tasks", centralToken, nonMemberPayload)
	if status != http.StatusForbidden || !containsJSON(body, `TARGET_NOT_GROUP_MEMBER`) {
		t.Fatalf("non-member target should be rejected: status=%d body=%s", status, body)
	}
	personal, err := database.EnsurePersonalWorkspace(ctx, actor.ID)
	if err != nil {
		t.Fatal(err)
	}
	personalPayload := map[string]any{}
	for key, value := range payload {
		personalPayload[key] = value
	}
	personalPayload["workspace_id"] = personal.ID
	personalPayload["idempotency_key"] = uuid.New()
	status, body = requestAPI(t, http.MethodPost, server.URL+"/api/v3/central/tasks", centralToken, personalPayload)
	if status != http.StatusBadRequest || !containsJSON(body, `WORKSPACE_GROUP_MISMATCH`) {
		t.Fatalf("personal workspace should be rejected: status=%d body=%s", status, body)
	}
	status, body = requestAPI(t, http.MethodPost, server.URL+"/api/v3/central/tasks", centralToken, payload)
	if status != http.StatusCreated {
		t.Fatalf("central task create failed: status=%d body=%s", status, body)
	}
	var created map[string]any
	if err := json.Unmarshal(body, &created); err != nil {
		t.Fatal(err)
	}
	task, ok := created["task"].(map[string]any)
	if !ok {
		t.Fatalf("missing task response: %#v", created)
	}
	if _, exists := task["user_id"]; exists {
		t.Fatal("central task response must not expose internal user_id")
	}
	status, body = requestAPI(t, http.MethodPost, server.URL+"/api/v3/central/tasks", centralToken, payload)
	if status != http.StatusOK || !containsJSON(body, `"duplicate":true`) {
		t.Fatalf("idempotent retry failed: status=%d body=%s", status, body)
	}
	var auditCount int
	if err := database.Ping(ctx); err != nil {
		t.Fatal(err)
	}
	connection, err = pgx.Connect(ctx, databaseURL)
	if err != nil {
		t.Fatal(err)
	}
	var owner, creator, operator uuid.UUID
	if err := connection.QueryRow(ctx, `SELECT user_id,created_by_user_id,last_operated_by_user_id FROM tasks WHERE workspace_id=$1 AND title='delegated task'`, group.WorkspaceID).Scan(&owner, &creator, &operator); err != nil {
		_ = connection.Close(ctx)
		t.Fatal(err)
	}
	if owner != target.ID || creator != target.ID || operator != actor.ID {
		_ = connection.Close(ctx)
		t.Fatalf("unexpected task identity: owner=%s creator=%s operator=%s", owner, creator, operator)
	}
	var auditDetails []byte
	if err := connection.QueryRow(ctx, `SELECT details FROM audit_events WHERE group_id=$1 AND action='central.task.create' AND target_id=(SELECT id FROM tasks WHERE workspace_id=$2 AND title='delegated task')`, group.ID, group.WorkspaceID).Scan(&auditDetails); err != nil {
		_ = connection.Close(ctx)
		t.Fatal(err)
	}
	if err := json.Unmarshal(auditDetails, &map[string]any{}); err != nil || !strings.Contains(string(auditDetails), actor.ID.String()) || !strings.Contains(string(auditDetails), target.ID.String()) || !strings.Contains(string(auditDetails), "agent-1") {
		_ = connection.Close(ctx)
		t.Fatalf("audit details missing delegation context: %s", auditDetails)
	}
	if err := connection.QueryRow(ctx, `SELECT count(*) FROM audit_events WHERE group_id=$1 AND action='central.task.create' AND target_id=(SELECT id FROM tasks WHERE workspace_id=$2 AND title='delegated task')`, group.ID, group.WorkspaceID).Scan(&auditCount); err != nil {
		_ = connection.Close(ctx)
		t.Fatal(err)
	}
	_ = connection.Close(ctx)
	if auditCount != 1 {
		t.Fatalf("expected one audit event, got %d", auditCount)
	}
}

func containsJSON(body []byte, value string) bool {
	return len(body) > 0 && string(body) != "" && strings.Contains(string(body), value)
}
