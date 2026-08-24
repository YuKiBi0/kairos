package httpapi

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"

	"github.com/google/uuid"
)

type inviteRedisFake struct {
	mu         sync.Mutex
	counts     map[string]int64
	lastKey    string
	lastTTL    string
	command    string
	commandErr error
}

func (f *inviteRedisFake) Ping(context.Context) error {
	return f.commandErr
}

func (f *inviteRedisFake) Command(_ context.Context, command string, args ...string) (any, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	if f.commandErr != nil {
		return nil, f.commandErr
	}
	if strings.ToUpper(command) != "EVAL" || len(args) != 4 || args[1] != "1" {
		return nil, errors.New("unexpected Redis command")
	}
	if f.counts == nil {
		f.counts = make(map[string]int64)
	}
	f.command = strings.ToUpper(command)
	f.lastKey = args[2]
	f.lastTTL = args[3]
	f.counts[f.lastKey]++
	return f.counts[f.lastKey], nil
}

func TestRedeemInviteFailsClosedWithoutRedis(t *testing.T) {
	api := &API{}
	recorder := httptest.NewRecorder()
	request := inviteRedemptionRequest(uuid.New(), "secret-code")

	api.redeemInvite(recorder, request)

	if recorder.Code != http.StatusServiceUnavailable || !bytes.Contains(recorder.Body.Bytes(), []byte("DEPENDENCY_UNAVAILABLE")) {
		t.Fatalf("expected Redis failure to close redemption, status=%d body=%s", recorder.Code, recorder.Body.String())
	}
}

func TestInviteRedemptionRateLimitUsesOnlyUserIdentity(t *testing.T) {
	userID := uuid.New()
	fake := &inviteRedisFake{}
	api := &API{redis: fake}

	for attempt := int64(1); attempt <= inviteRedeemLimit; attempt++ {
		allowed, err := api.allowInviteRedemption(httptest.NewRequest(http.MethodPost, "/", nil), userID)
		if err != nil || !allowed {
			t.Fatalf("attempt %d should be allowed: allowed=%v err=%v", attempt, allowed, err)
		}
	}
	allowed, err := api.allowInviteRedemption(httptest.NewRequest(http.MethodPost, "/", nil), userID)
	if err != nil || allowed {
		t.Fatalf("attempt above the limit should be rejected: allowed=%v err=%v", allowed, err)
	}
	if fake.command != "EVAL" || fake.lastKey != inviteRedeemRateKeyBase+userID.String() || fake.lastTTL != "60" {
		t.Fatalf("unexpected rate limit command: command=%q key=%q ttl=%q", fake.command, fake.lastKey, fake.lastTTL)
	}
	if strings.Contains(fake.lastKey, "secret-code") {
		t.Fatal("raw invite code must not be included in the Redis key")
	}
}

func TestRedeemInviteReturnsRateLimitedBeforeStoreAccess(t *testing.T) {
	userID := uuid.New()
	fake := &inviteRedisFake{counts: map[string]int64{inviteRedeemRateKeyBase + userID.String(): inviteRedeemLimit}}
	api := &API{redis: fake}
	recorder := httptest.NewRecorder()

	api.redeemInvite(recorder, inviteRedemptionRequest(userID, "secret-code"))

	if recorder.Code != http.StatusTooManyRequests || !bytes.Contains(recorder.Body.Bytes(), []byte("RATE_LIMITED")) {
		t.Fatalf("expected rate limit response, status=%d body=%s", recorder.Code, recorder.Body.String())
	}
}

func inviteRedemptionRequest(userID uuid.UUID, code string) *http.Request {
	body := strings.NewReader(fmt.Sprintf("{\"code\":%q,\"idempotency_key\":%q}", code, uuid.NewString()))
	request := httptest.NewRequest(http.MethodPost, "/api/v2/group-invites/redeem", body)
	request.Header.Set("Content-Type", "application/json")
	ctx := context.WithValue(request.Context(), userIDKey, userID)
	ctx = context.WithValue(ctx, deviceIDKey, uuid.New())
	return request.WithContext(ctx)
}
