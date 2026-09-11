package app

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"
	"time"
)

func TestParseYAMLConfig(t *testing.T) {
	var config Config
	if err := parseYAMLConfig("current_server: prod\ncurrent_workspace: personal\nservers:\n  prod:\n    url: https://example.test\n    verify_tls: true\n    ca_file: null\n", &config); err != nil {
		t.Fatal(err)
	}
	if config.CurrentServer != "prod" || config.Servers["prod"].URL != "https://example.test" || !config.Servers["prod"].VerifyTLS {
		t.Fatalf("unexpected config: %#v", config)
	}
}

func TestParseGlobalAllowsFlagsBeforeAndAfterCommand(t *testing.T) {
	opts, args, err := parseGlobal([]string{"--output", "json", "task", "list", "--workspace", "space", "--quiet"})
	if err != nil {
		t.Fatal(err)
	}
	if opts.output != "json" || opts.workspace != "space" || !opts.quiet {
		t.Fatalf("unexpected options: %#v", opts)
	}
	if strings.Join(args, " ") != "task list" {
		t.Fatalf("unexpected command args: %#v", args)
	}
}

func TestRunInvalidCommandJSONErrorAndExitCode(t *testing.T) {
	var stdout, stderr bytes.Buffer
	code := Run([]string{"--output", "json", "does-not-exist"}, &stdout, &stderr)
	if code != ExitUsage {
		t.Fatalf("exit code = %d", code)
	}
	if !strings.Contains(stdout.String(), `"code":"USAGE"`) {
		t.Fatalf("missing structured error: %s", stdout.String())
	}
	if stderr.Len() != 0 {
		t.Fatalf("unexpected stderr: %s", stderr.String())
	}
}

func TestTokenIssuanceCommandIsRemoved(t *testing.T) {
	var stdout, stderr bytes.Buffer
	code := Run([]string{"--output", "json", "token", "create"}, &stdout, &stderr)
	if code != ExitUsage || !strings.Contains(stdout.String(), `"code":"USAGE"`) {
		t.Fatalf("removed token command should return usage error: code=%d output=%s", code, stdout.String())
	}
}

func TestAPIClientMapsRequestIDAndStatus(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("X-Request-ID", "req-123")
		w.WriteHeader(http.StatusForbidden)
		_, _ = w.Write([]byte(`{"error":{"code":"FORBIDDEN_SCOPE","message":"denied","request_id":"req-123"}}`))
	}))
	defer server.Close()
	client, err := NewAPIClient(ServerProfile{URL: server.URL, VerifyTLS: true}, "", time.Second, false)
	if err != nil {
		t.Fatal(err)
	}
	_, _, err = client.Do(context.Background(), http.MethodGet, "/healthz", url.Values{}, nil, "")
	value := asCLIError(err)
	if value.ExitCode != ExitForbidden || value.Code != "FORBIDDEN_SCOPE" || value.RequestID != "req-123" {
		t.Fatalf("unexpected error: %#v", value)
	}
}

func TestCredentialsNeedRefresh(t *testing.T) {
	now := time.Now().UTC()
	if credentialsNeedRefresh(Credentials{AccessToken: "access"}, now) {
		t.Fatal("an environment-style access token without a refresh token must not be refreshed")
	}
	if !credentialsNeedRefresh(Credentials{AccessToken: "access", RefreshToken: "refresh", ExpiresAt: now.Add(20 * time.Second).Format(time.RFC3339)}, now) {
		t.Fatal("a session near expiry should be refreshed")
	}
	if credentialsNeedRefresh(Credentials{AccessToken: "access", RefreshToken: "refresh", ExpiresAt: now.Add(time.Hour).Format(time.RFC3339)}, now) {
		t.Fatal("a fresh session should be reused")
	}
}

func TestRefreshCredentialsRotatesStoredSessionValues(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/api/v1/auth/refresh" {
			t.Fatalf("unexpected refresh path: %s", r.URL.Path)
		}
		var request map[string]string
		if err := json.NewDecoder(r.Body).Decode(&request); err != nil {
			t.Fatal(err)
		}
		if request["refresh_token"] != "old-refresh" {
			t.Fatalf("unexpected refresh token: %q", request["refresh_token"])
		}
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"access_token":"new-access","refresh_token":"new-refresh","expires_in":3600}`))
	}))
	defer server.Close()
	client, err := NewAPIClient(ServerProfile{URL: server.URL, VerifyTLS: true}, "", time.Second, false)
	if err != nil {
		t.Fatal(err)
	}
	updated, err := refreshCredentials(context.Background(), client, Credentials{RefreshToken: "old-refresh"})
	if err != nil {
		t.Fatal(err)
	}
	if updated.AccessToken != "new-access" || updated.RefreshToken != "new-refresh" || updated.ExpiresAt == "" {
		t.Fatalf("unexpected refreshed credentials: %#v", updated)
	}
}
