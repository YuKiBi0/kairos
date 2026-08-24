package httpapi

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/YuKiBi0/kairos/server/internal/config"
)

type fakeRedis struct{ err error }

func (f fakeRedis) Ping(context.Context) error { return f.err }

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
