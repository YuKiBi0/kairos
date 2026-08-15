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
	"strings"
	"testing"
	"time"

	"github.com/YuKiBi0/kairos/server/internal/auth"
	"github.com/YuKiBi0/kairos/server/internal/config"
	"github.com/YuKiBi0/kairos/server/internal/store"
	"github.com/coder/websocket"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

func TestRealtimeHintTriggersHTTPChanges(t *testing.T) {
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
	password := "http integration password 123"
	hash, err := auth.HashPassword(password)
	if err != nil {
		t.Fatal(err)
	}
	username := "http-sync-" + uuid.NewString()
	user, err := database.CreateUser(ctx, username, hash)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		connection, err := pgx.Connect(context.Background(), databaseURL)
		if err == nil {
			_, _ = connection.Exec(context.Background(), `DELETE FROM users WHERE id=$1`, user.ID)
			_ = connection.Close(context.Background())
		}
	})

	logger := slog.New(slog.NewTextHandler(io.Discard, nil))
	handler := New(database, config.Config{
		SessionSecret: []byte("01234567890123456789012345678901"),
		AccessTTL:     15 * time.Minute,
		RefreshTTL:    time.Hour,
	}, logger, "test")
	server := httptest.NewServer(handler)
	defer server.Close()

	loginPayload := map[string]any{
		"username": username,
		"password": password,
		"device": map[string]string{
			"name":     "integration",
			"platform": "windows",
		},
	}
	loginResponse := requestJSON(t, http.MethodPost, server.URL+"/api/v1/auth/login", "", loginPayload)
	accessToken, ok := loginResponse["access_token"].(string)
	if !ok || accessToken == "" {
		t.Fatal("login did not return an access token")
	}

	websocketURL := "ws" + strings.TrimPrefix(server.URL, "http") + "/api/v1/realtime"
	connection, _, err := websocket.Dial(ctx, websocketURL, &websocket.DialOptions{
		HTTPHeader: http.Header{"Authorization": []string{"Bearer " + accessToken}},
	})
	if err != nil {
		t.Fatal(err)
	}
	defer connection.Close(websocket.StatusNormalClosure, "test complete")
	_, ready, err := connection.Read(ctx)
	if err != nil || !bytes.Contains(ready, []byte(`"type":"ready"`)) {
		t.Fatalf("unexpected ready message: %s err=%v", ready, err)
	}

	taskID := uuid.New()
	pushPayload := map[string]any{
		"operations": []any{map[string]any{
			"operation_id": uuid.New(),
			"entity_type":  "task",
			"entity_id":    taskID,
			"base_version": 0,
			"changes": map[string]any{
				"title":      "Realtime private title",
				"quadrant":   2,
				"status":     0,
				"sort_order": 0,
			},
			"changed_fields": []string{"title", "quadrant", "status", "sort_order"},
		}},
	}
	pushResponse := requestJSON(
		t,
		http.MethodPost,
		server.URL+"/api/v1/sync/push",
		accessToken,
		pushPayload,
	)
	if _, ok := pushResponse["results"]; !ok {
		t.Fatalf("push response missing results: %#v", pushResponse)
	}
	_, hint, err := connection.Read(ctx)
	if err != nil {
		t.Fatal(err)
	}
	if bytes.Contains(hint, []byte("Realtime private title")) ||
		!bytes.Contains(hint, []byte(taskID.String())) {
		t.Fatalf("change hint leaked content or omitted id: %s", hint)
	}

	changes := requestJSON(
		t,
		http.MethodGet,
		server.URL+"/api/v1/sync/changes?after=0&limit=200",
		accessToken,
		nil,
	)
	encodedChanges, err := json.Marshal(changes["changes"])
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Contains(encodedChanges, []byte("Realtime private title")) {
		t.Fatalf("HTTP changes omitted task data: %s", encodedChanges)
	}
}

func requestJSON(
	t *testing.T,
	method, endpoint, accessToken string,
	payload any,
) map[string]any {
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
	if accessToken != "" {
		request.Header.Set("Authorization", "Bearer "+accessToken)
	}
	response, err := http.DefaultClient.Do(request)
	if err != nil {
		t.Fatal(err)
	}
	defer response.Body.Close()
	if response.StatusCode < 200 || response.StatusCode >= 300 {
		data, _ := io.ReadAll(response.Body)
		t.Fatalf("unexpected status %d: %s", response.StatusCode, data)
	}
	var decoded map[string]any
	if err := json.NewDecoder(response.Body).Decode(&decoded); err != nil {
		t.Fatal(err)
	}
	return decoded
}
