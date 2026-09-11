package app

import (
	"bytes"
	"context"
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
