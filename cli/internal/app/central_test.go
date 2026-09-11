package app

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestCentralCommandRequiresDelegationFields(t *testing.T) {
	var out, errOut bytes.Buffer
	err := centralCommand(options{out: Output{Mode: "json", Out: &out, Err: &errOut}}, []string{"task", "create"})
	cliErr := asCLIError(err)
	if cliErr.ExitCode != ExitUsage || cliErr.Code != "USAGE" {
		t.Fatalf("expected usage error, got %#v", cliErr)
	}
}

func TestCentralCommandRejectsBothCreatorSelectors(t *testing.T) {
	var out, errOut bytes.Buffer
	err := centralCommand(options{out: Output{Mode: "json", Out: &out, Err: &errOut}}, []string{
		"task", "create", "--group", "g", "--workspace", "w", "--creator-user", "u",
		"--creator-username", "alice", "--title", "task",
	})
	cliErr := asCLIError(err)
	if cliErr.ExitCode != ExitUsage || !strings.Contains(cliErr.Message, "只能指定一个") {
		t.Fatalf("expected mutually exclusive selector error, got %#v", cliErr)
	}
}

func TestCentralCommandLoadsJSONFileAndSendsIdempotency(t *testing.T) {
	root := t.TempDir()
	t.Setenv("APPDATA", root)
	t.Setenv("KAIROS_TOKEN", "l3-login-token")
	var received struct {
		Payload map[string]any
		Key     string
		Path    string
	}
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if got := r.Header.Get("Authorization"); got != "Bearer l3-login-token" {
			t.Fatalf("central command did not use the logged-in token: %q", got)
		}
		received.Path = r.URL.Path
		received.Key = r.Header.Get("Idempotency-Key")
		if err := json.NewDecoder(r.Body).Decode(&received.Payload); err != nil {
			t.Fatalf("decode request: %v", err)
		}
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"task":{"id":"task-1"}}`))
	}))
	defer server.Close()
	if err := SaveConfig(Config{CurrentServer: "prod", Servers: map[string]ServerProfile{
		"prod": {URL: server.URL, VerifyTLS: true},
	}}); err != nil {
		t.Fatal(err)
	}
	inputPath := filepath.Join(root, "task.json")
	input := `{"group_id":"group-1","workspace_id":"workspace-1","creator_username":"alice","title":"来自文件","description":"说明","source_agent_id":"agent-1","idempotency_key":"11111111-1111-1111-1111-111111111111"}`
	if err := os.WriteFile(inputPath, []byte(input), 0o600); err != nil {
		t.Fatal(err)
	}
	var out, errOut bytes.Buffer
	err := centralCommand(options{server: "prod", output: "json", requestTimeout: time.Second, out: Output{Mode: "json", Out: &out, Err: &errOut}}, []string{"task", "create", "--json-file", inputPath})
	if err != nil {
		t.Fatal(err)
	}
	if received.Path != "/api/v3/central/tasks" || received.Key != "11111111-1111-1111-1111-111111111111" {
		t.Fatalf("unexpected request path/key: %s %s", received.Path, received.Key)
	}
	if received.Payload["creator_username"] != "alice" || received.Payload["title"] != "来自文件" {
		t.Fatalf("JSON file fields were not sent: %#v", received.Payload)
	}
	if strings.Contains(out.String(), "l3-login-token") {
		t.Fatal("login token leaked to output")
	}
}

func TestCentralCommandUsesGlobalWorkspaceFlag(t *testing.T) {
	root := t.TempDir()
	t.Setenv("APPDATA", root)
	t.Setenv("KAIROS_TOKEN", "l3-login-token")
	var received map[string]any
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if err := json.NewDecoder(r.Body).Decode(&received); err != nil {
			t.Fatalf("decode request: %v", err)
		}
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"task":{"id":"task-1"}}`))
	}))
	defer server.Close()
	if err := SaveConfig(Config{CurrentServer: "prod", Servers: map[string]ServerProfile{
		"prod": {URL: server.URL, VerifyTLS: true},
	}}); err != nil {
		t.Fatal(err)
	}
	var out, errOut bytes.Buffer
	err := centralCommand(options{server: "prod", workspace: "workspace-from-global", output: "json", requestTimeout: time.Second, out: Output{Mode: "json", Out: &out, Err: &errOut}}, []string{
		"task", "create", "--group", "group-1", "--creator-user", "user-1", "--title", "task",
	})
	if err != nil {
		t.Fatal(err)
	}
	if got := received["workspace_id"]; got != "workspace-from-global" {
		t.Fatalf("global workspace flag was not forwarded: %#v", got)
	}
}
