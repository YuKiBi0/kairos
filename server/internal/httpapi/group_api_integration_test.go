//go:build integration

package httpapi

import (
	"bytes"
	"context"
	"encoding/json"
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

func TestGroupAPIEnforcesMembershipAndRoleScope(t *testing.T) {
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
	hash, err := auth.HashPassword("group API integration password")
	if err != nil {
		t.Fatal(err)
	}
	owner, err := database.CreateUser(ctx, "group-api-owner-"+uuid.NewString(), hash)
	if err != nil {
		t.Fatal(err)
	}
	member, err := database.CreateUser(ctx, "group-api-member-"+uuid.NewString(), hash)
	if err != nil {
		t.Fatal(err)
	}
	var groupID uuid.UUID
	t.Cleanup(func() { cleanupGroupAPI(databaseURL, groupID, []uuid.UUID{owner.ID, member.ID}) })

	secret := []byte("01234567890123456789012345678901")
	tokens := auth.NewTokenManager(secret, 15*time.Minute, "kairos-server")
	ownerToken, _, err := tokens.IssueAccess(owner.ID, uuid.New())
	if err != nil {
		t.Fatal(err)
	}
	memberToken, _, err := tokens.IssueAccess(member.ID, uuid.New())
	if err != nil {
		t.Fatal(err)
	}
	handler := New(database, config.Config{SessionSecret: secret, AccessTTL: 15 * time.Minute, RefreshTTL: time.Hour}, slog.New(slog.NewTextHandler(io.Discard, nil)), "test")
	server := httptest.NewServer(handler)
	defer server.Close()

	created := requestJSON(t, http.MethodPost, server.URL+"/api/v2/groups", ownerToken, map[string]string{"name": "API group"})
	groupMap := created["group"].(map[string]any)
	groupID, err = uuid.Parse(groupMap["id"].(string))
	if err != nil {
		t.Fatal(err)
	}
	workspaces := requestJSON(t, http.MethodGet, server.URL+"/api/v2/workspaces", ownerToken, nil)
	if values, ok := workspaces["workspaces"].([]any); !ok || len(values) != 2 {
		t.Fatalf("unexpected owner workspaces: %#v", workspaces)
	}

	status, _ := requestAPI(t, http.MethodGet, server.URL+"/api/v2/groups/"+groupID.String(), memberToken, nil)
	if status != http.StatusForbidden {
		t.Fatalf("expected non-member group access to be forbidden, got %d", status)
	}
	createdAccount := requestJSON(t, http.MethodPost, server.URL+"/api/v2/groups/"+groupID.String()+"/accounts", ownerToken, map[string]string{
		"account_code": "member-001",
		"display_name": "Member",
	})
	accountMap := createdAccount["group_account"].(map[string]any)
	accountID := accountMap["id"].(string)
	requestJSON(t, http.MethodPost, server.URL+"/api/v2/groups/"+groupID.String()+"/accounts/"+accountID+"/bind", ownerToken, map[string]string{"user_id": member.ID.String()})
	requestJSON(t, http.MethodGet, server.URL+"/api/v2/groups/"+groupID.String(), memberToken, nil)
	status, _ = requestAPI(t, http.MethodGet, server.URL+"/api/v2/groups/"+groupID.String()+"/accounts", memberToken, nil)
	if status != http.StatusForbidden {
		t.Fatalf("expected L1 roster access to be forbidden, got %d", status)
	}
	status, _ = requestAPI(t, http.MethodPut, server.URL+"/api/v2/groups/"+groupID.String()+"/accounts/"+accountID+"/role", ownerToken, map[string]string{"role": "L2"})
	if status != http.StatusNoContent {
		t.Fatalf("expected role promotion to succeed, got %d", status)
	}
	requestJSON(t, http.MethodGet, server.URL+"/api/v2/groups/"+groupID.String()+"/accounts", memberToken, nil)
	status, body := requestAPI(t, http.MethodPut, server.URL+"/api/v2/groups/"+groupID.String()+"/accounts/"+accountID+"/role", memberToken, map[string]string{"role": "L3"})
	if status != http.StatusForbidden || !bytes.Contains(body, []byte("ROLE_ESCALATION")) {
		t.Fatalf("expected L3 role escalation to be rejected, status=%d body=%s", status, body)
	}
	status, _ = requestAPI(t, http.MethodPost, server.URL+"/api/v2/groups/"+groupID.String()+"/collaboration", memberToken, map[string]any{})
	if status != http.StatusNoContent {
		t.Fatalf("expected L2 collaboration enable to succeed, got %d", status)
	}
}

func requestAPI(t *testing.T, method, endpoint, accessToken string, payload any) (int, []byte) {
	t.Helper()
	var body io.Reader
	if payload != nil {
		encoded, err := json.Marshal(payload)
		if err != nil {
			t.Fatal(err)
		}
		body = bytes.NewReader(encoded)
	}
	request, err := http.NewRequest(method, endpoint, body)
	if err != nil {
		t.Fatal(err)
	}
	request.Header.Set("Content-Type", "application/json")
	request.Header.Set("Authorization", "Bearer "+accessToken)
	response, err := http.DefaultClient.Do(request)
	if err != nil {
		t.Fatal(err)
	}
	defer response.Body.Close()
	encoded, err := io.ReadAll(response.Body)
	if err != nil {
		t.Fatal(err)
	}
	return response.StatusCode, encoded
}

func cleanupGroupAPI(databaseURL string, groupID uuid.UUID, userIDs []uuid.UUID) {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	connection, err := pgx.Connect(ctx, databaseURL)
	if err != nil {
		return
	}
	defer connection.Close(ctx)
	tx, err := connection.Begin(ctx)
	if err != nil {
		return
	}
	defer func() { _ = tx.Rollback(ctx) }()
	_, _ = tx.Exec(ctx, `SET CONSTRAINTS ALL DEFERRED`)
	_, _ = tx.Exec(ctx, `DELETE FROM audit_events WHERE group_id = $1 OR actor_user_id = ANY($2)`, groupID, userIDs)
	_, _ = tx.Exec(ctx, `DELETE FROM group_account_links WHERE group_id = $1`, groupID)
	_, _ = tx.Exec(ctx, `DELETE FROM group_accounts WHERE group_id = $1`, groupID)
	_, _ = tx.Exec(ctx, `DELETE FROM groups WHERE id = $1`, groupID)
	_, _ = tx.Exec(ctx, `DELETE FROM workspaces WHERE group_id = $1 OR owner_user_id = ANY($2)`, groupID, userIDs)
	_, _ = tx.Exec(ctx, `DELETE FROM users WHERE id = ANY($1)`, userIDs)
	_ = tx.Commit(ctx)
}
