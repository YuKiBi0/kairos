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
	"sync"
	"testing"
	"time"

	"github.com/YuKiBi0/kairos/server/internal/auth"
	"github.com/YuKiBi0/kairos/server/internal/config"
	"github.com/YuKiBi0/kairos/server/internal/store"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

type adminRedisFake struct {
	mu   sync.Mutex
	data map[string]string
	fail bool
}

func (f *adminRedisFake) Ping(context.Context) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	if f.fail {
		return io.ErrUnexpectedEOF
	}
	return nil
}

func (f *adminRedisFake) Command(_ context.Context, command string, args ...string) (any, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	if f.fail {
		return nil, io.ErrUnexpectedEOF
	}
	if f.data == nil {
		f.data = map[string]string{}
	}
	switch strings.ToUpper(command) {
	case "SET":
		if len(args) < 2 {
			return nil, io.ErrUnexpectedEOF
		}
		f.data[args[0]] = args[1]
		return "OK", nil
	case "GET":
		return f.data[args[0]], nil
	case "DEL":
		delete(f.data, args[0])
		return int64(1), nil
	default:
		return nil, io.ErrUnexpectedEOF
	}
}

func TestAdminLoginCSRFAndRedisFailure(t *testing.T) {
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
	username := "admin-test-" + uuid.NewString()
	hash, err := auth.HashPassword("correct horse battery staple")
	if err != nil {
		t.Fatal(err)
	}
	user, err := database.CreateUser(ctx, username, hash)
	if err != nil {
		t.Fatal(err)
	}
	defer func() {
		connection, err := pgx.Connect(ctx, databaseURL)
		if err == nil {
			_, _ = connection.Exec(ctx, `DELETE FROM server_roles WHERE user_id=$1`, user.ID)
			_, _ = connection.Exec(ctx, `DELETE FROM audit_events WHERE actor_user_id=$1`, user.ID)
			_, _ = connection.Exec(ctx, `DELETE FROM workspaces WHERE owner_user_id=$1`, user.ID)
			_, _ = connection.Exec(ctx, `DELETE FROM users WHERE id=$1`, user.ID)
			_ = connection.Close(ctx)
		}
	}()
	if err := database.BootstrapSuperAdmin(ctx, user.ID); err != nil {
		if _, roleErr := database.AdminRole(ctx, user.ID); roleErr != nil {
			t.Skip("another integration test owns the super administrator fixture")
		}
	}
	fake := &adminRedisFake{}
	secret := []byte("01234567890123456789012345678901")
	handler := NewWithRedis(database, config.Config{SessionSecret: secret, AccessTTL: time.Minute, RefreshTTL: time.Hour}, slog.New(slog.NewTextHandler(io.Discard, nil)), "test", fake)
	server := httptest.NewServer(handler)
	defer server.Close()
	payload, _ := json.Marshal(map[string]string{"username": username, "password": "correct horse battery staple"})
	response, err := server.Client().Post(server.URL+"/KairosAdmin/api/login", "application/json", strings.NewReader(string(payload)))
	if err != nil {
		t.Fatal(err)
	}
	var login struct {
		CSRFToken string `json:"csrf_token"`
	}
	if response.StatusCode != http.StatusOK || json.NewDecoder(response.Body).Decode(&login) != nil || login.CSRFToken == "" {
		t.Fatalf("admin login failed: status=%d", response.StatusCode)
	}
	response.Body.Close()
	var sessionCookie *http.Cookie
	for _, cookie := range response.Cookies() {
		if cookie.Name == adminSessionCookie {
			sessionCookie = cookie
		}
	}
	if sessionCookie == nil || !sessionCookie.HttpOnly || !sessionCookie.Secure || sessionCookie.SameSite != http.SameSiteStrictMode {
		t.Fatalf("admin session cookie is not hardened: %#v", sessionCookie)
	}
	request, _ := http.NewRequest(http.MethodPost, server.URL+"/KairosAdmin/api/logout", strings.NewReader(`{}`))
	request.Header.Set("Content-Type", "application/json")
	request.Header.Set("X-CSRF-Token", login.CSRFToken)
	request.AddCookie(sessionCookie)
	response, err = server.Client().Do(request)
	if err != nil {
		t.Fatal(err)
	}
	response.Body.Close()
	if response.StatusCode != http.StatusNoContent {
		t.Fatalf("csrf-protected logout failed: %d", response.StatusCode)
	}
	fake.fail = true
	request, _ = http.NewRequest(http.MethodGet, server.URL+"/KairosAdmin/api/me", nil)
	request.AddCookie(sessionCookie)
	response, err = server.Client().Do(request)
	if err != nil {
		t.Fatal(err)
	}
	response.Body.Close()
	if response.StatusCode != http.StatusServiceUnavailable {
		t.Fatalf("redis failure should fail closed: %d", response.StatusCode)
	}
}

func TestAdminManagementRoutesRequireCSRFAndMutateScopedResources(t *testing.T) {
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
	username := "admin-manage-" + uuid.NewString()
	hash, err := auth.HashPassword("correct horse battery staple")
	if err != nil {
		t.Fatal(err)
	}
	user, err := database.CreateUser(ctx, username, hash)
	if err != nil {
		t.Fatal(err)
	}
	createdGroupID := uuid.Nil
	t.Cleanup(func() {
		cleanupGroupFixtureHTTP(context.Background(), t, databaseURL, createdGroupID, user.ID)
	})
	if err := database.BootstrapSuperAdmin(ctx, user.ID); err != nil {
		if _, roleErr := database.AdminRole(ctx, user.ID); roleErr != nil {
			t.Skip("another integration test owns the super administrator fixture")
		}
	}
	fake := &adminRedisFake{}
	handler := NewWithRedis(database, config.Config{SessionSecret: []byte("01234567890123456789012345678901")}, slog.New(slog.NewTextHandler(io.Discard, nil)), "test", fake)
	server := httptest.NewServer(handler)
	defer server.Close()
	loginBody, _ := json.Marshal(map[string]string{"username": username, "password": "correct horse battery staple"})
	response, err := server.Client().Post(server.URL+"/KairosAdmin/api/login", "application/json", strings.NewReader(string(loginBody)))
	if err != nil {
		t.Fatal(err)
	}
	var login struct {
		CSRFToken string `json:"csrf_token"`
	}
	if response.StatusCode != http.StatusOK || json.NewDecoder(response.Body).Decode(&login) != nil {
		t.Fatalf("admin login failed: %d", response.StatusCode)
	}
	response.Body.Close()
	var cookie *http.Cookie
	for _, candidate := range response.Cookies() {
		if candidate.Name == adminSessionCookie {
			cookie = candidate
		}
	}
	if cookie == nil {
		t.Fatal("admin session cookie missing")
	}
	requestAdmin := func(method, path string, payload any, csrfToken string) *http.Response {
		var body io.Reader
		if payload != nil {
			encoded, _ := json.Marshal(payload)
			body = strings.NewReader(string(encoded))
		}
		request, _ := http.NewRequest(method, server.URL+path, body)
		request.Header.Set("Content-Type", "application/json")
		if csrfToken != "" {
			request.Header.Set("X-CSRF-Token", csrfToken)
		}
		request.AddCookie(cookie)
		result, requestErr := server.Client().Do(request)
		if requestErr != nil {
			t.Fatal(requestErr)
		}
		return result
	}
	response = requestAdmin(http.MethodPost, "/KairosAdmin/api/groups", map[string]string{"name": "Admin managed group"}, "")
	response.Body.Close()
	if response.StatusCode != http.StatusForbidden {
		t.Fatalf("admin mutation without CSRF should fail: %d", response.StatusCode)
	}
	response = requestAdmin(http.MethodPost, "/KairosAdmin/api/groups", map[string]string{"name": "Admin managed group"}, login.CSRFToken)
	var created struct {
		Group store.Group `json:"group"`
	}
	if response.StatusCode != http.StatusCreated || json.NewDecoder(response.Body).Decode(&created) != nil {
		t.Fatalf("admin group creation failed: %d", response.StatusCode)
	}
	createdGroupID = created.Group.ID
	response.Body.Close()
	response = requestAdmin(http.MethodPost, "/KairosAdmin/api/groups/"+created.Group.ID.String()+"/collaboration", map[string]any{}, login.CSRFToken)
	response.Body.Close()
	if response.StatusCode != http.StatusNoContent {
		t.Fatalf("admin collaboration enable failed: %d", response.StatusCode)
	}
	group, err := database.GroupByID(ctx, created.Group.ID)
	if err != nil || group.CollaborationEnabledAt == nil {
		t.Fatalf("collaboration was not persisted: group=%#v err=%v", group, err)
	}
}

func cleanupGroupFixtureHTTP(ctx context.Context, t *testing.T, databaseURL string, groupID, userID uuid.UUID) {
	t.Helper()
	connection, err := pgx.Connect(ctx, databaseURL)
	if err != nil {
		return
	}
	defer connection.Close(ctx)
	_, _ = connection.Exec(ctx, `SET CONSTRAINTS ALL DEFERRED`)
	_, _ = connection.Exec(ctx, `DELETE FROM audit_events WHERE group_id=$1 OR actor_user_id=$2`, groupID, userID)
	if groupID != uuid.Nil {
		_, _ = connection.Exec(ctx, `DELETE FROM group_account_links WHERE group_id=$1`, groupID)
		_, _ = connection.Exec(ctx, `DELETE FROM group_accounts WHERE group_id=$1`, groupID)
		_, _ = connection.Exec(ctx, `DELETE FROM groups WHERE id=$1`, groupID)
	}
	_, _ = connection.Exec(ctx, `DELETE FROM workspaces WHERE group_id=$1 OR owner_user_id=$2`, groupID, userID)
	_, _ = connection.Exec(ctx, `DELETE FROM server_roles WHERE user_id=$1`, userID)
	_, _ = connection.Exec(ctx, `DELETE FROM users WHERE id=$1`, userID)
}
