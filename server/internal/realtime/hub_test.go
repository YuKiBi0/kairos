package realtime

import (
	"testing"

	"github.com/google/uuid"
)

func TestHubIsolatesUsersAndUnsubscribes(t *testing.T) {
	hub := NewHub()
	firstUser := uuid.New()
	secondUser := uuid.New()
	first, cancelFirst := hub.Subscribe(firstUser)
	second, cancelSecond := hub.Subscribe(secondUser)
	defer cancelSecond()

	hint := ChangeHint{
		Type:          "change_hint",
		Cursor:        12,
		EntityType:    "task",
		EntityID:      uuid.New(),
		EntityVersion: 3,
	}
	hub.Publish(firstUser, hint)
	if received := <-first; received.EntityID != hint.EntityID {
		t.Fatalf("unexpected hint: %#v", received)
	}
	select {
	case <-second:
		t.Fatal("change hint leaked to a different user")
	default:
	}

	cancelFirst()
	if hub.ConnectionCount(firstUser) != 0 {
		t.Fatal("subscriber was not removed")
	}
}
