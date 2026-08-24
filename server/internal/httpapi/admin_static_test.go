package httpapi

import (
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/YuKiBi0/kairos/server/internal/config"
)

func TestKairosAdminStaticEntryAndSecurityHeaders(t *testing.T) {
	handler := New(nil, config.Config{SessionSecret: []byte("01234567890123456789012345678901")}, slog.New(slog.NewTextHandler(io.Discard, nil)), "test")
	server := httptest.NewServer(handler)
	defer server.Close()
	response, err := server.Client().Get(server.URL + "/KairosAdmin/")
	if err != nil {
		t.Fatal(err)
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusOK {
		t.Fatalf("KairosAdmin entry returned %d", response.StatusCode)
	}
	if response.Header.Get("Content-Security-Policy") == "" || response.Header.Get("X-Frame-Options") != "DENY" {
		t.Fatalf("admin security headers missing: %#v", response.Header)
	}
	wrongCase, err := server.Client().Get(server.URL + "/admin/")
	if err != nil {
		t.Fatal(err)
	}
	wrongCase.Body.Close()
	if wrongCase.StatusCode != http.StatusNotFound {
		t.Fatalf("weak admin entry should be 404, got %d", wrongCase.StatusCode)
	}
	unauthorized, err := server.Client().Get(server.URL + "/KairosAdmin/api/me")
	if err != nil {
		t.Fatal(err)
	}
	unauthorized.Body.Close()
	if unauthorized.StatusCode != http.StatusUnauthorized {
		t.Fatalf("unauthenticated admin API should be 401, got %d", unauthorized.StatusCode)
	}
}
