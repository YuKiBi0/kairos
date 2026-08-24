package httpapi

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/YuKiBi0/kairos/server/internal/config"
)

type fakeRedis struct{ err error }

func (f fakeRedis) Ping(context.Context) error { return f.err }

type adminRateRedisFake struct {
	count int64
	key   string
}

func (f *adminRateRedisFake) Ping(context.Context) error { return nil }

func (f *adminRateRedisFake) Command(_ context.Context, command string, args ...string) (any, error) {
	if command != "EVAL" || len(args) != 3 {
		return nil, errors.New("unexpected command")
	}
	f.count++
	f.key = args[2]
	return f.count, nil
}

func TestHealthReportsRedisDegraded(t *testing.T) {
	handler := NewWithRedis(nil, config.Config{}, slog.New(slog.NewTextHandler(io.Discard, nil)), "test", fakeRedis{err: errors.New("offline")})
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, httptest.NewRequest(http.MethodGet, "/healthz", nil))
	if recorder.Code != http.StatusOK {
		t.Fatalf("unexpected status: %d", recorder.Code)
	}
	var response map[string]string
	if err := json.Unmarshal(recorder.Body.Bytes(), &response); err != nil {
		t.Fatal(err)
	}
	if response["status"] != "degraded" || response["redis"] != "unavailable" {
		t.Fatalf("unexpected health response: %#v", response)
	}
}

func TestSensitiveMutationRequiresRedis(t *testing.T) {
	request := httptest.NewRequest(http.MethodPut, "/KairosAdmin/api/users/id/super-admin", nil)
	recorder := httptest.NewRecorder()
	if (&API{}).requireRedisDependency(recorder, request) {
		t.Fatal("sensitive mutation should not proceed without Redis")
	}
	if recorder.Code != http.StatusServiceUnavailable || !strings.Contains(recorder.Body.String(), "DEPENDENCY_UNAVAILABLE") {
		t.Fatalf("unexpected Redis dependency response: status=%d body=%s", recorder.Code, recorder.Body.String())
	}
	recorder = httptest.NewRecorder()
	if (&API{redis: fakeRedis{err: errors.New("offline")}}).requireRedisDependency(recorder, request) {
		t.Fatal("sensitive mutation should not proceed when Redis is unhealthy")
	}
	if recorder.Code != http.StatusServiceUnavailable {
		t.Fatalf("unexpected Redis unhealthy status: %d", recorder.Code)
	}
}

func TestAdminLoginRateLimitUsesHashedUsername(t *testing.T) {
	fake := &adminRateRedisFake{}
	api := &API{redis: fake}
	request := httptest.NewRequest(http.MethodPost, "/KairosAdmin/api/login", nil)
	for attempt := int64(1); attempt <= adminLoginLimit; attempt++ {
		allowed, err := api.allowAdminLogin(request, "Admin User")
		if err != nil || !allowed {
			t.Fatalf("attempt %d should be allowed: allowed=%v err=%v", attempt, allowed, err)
		}
	}
	allowed, err := api.allowAdminLogin(request, "Admin User")
	if err != nil || allowed {
		t.Fatalf("attempt above limit should be rejected: allowed=%v err=%v", allowed, err)
	}
	if fake.key == "" || strings.Contains(fake.key, "Admin User") || !strings.HasPrefix(fake.key, "kairos:admin:login:") {
		t.Fatalf("admin login key should contain only a digest: %q", fake.key)
	}
}
