package realtime

import (
	"sync"

	"github.com/google/uuid"
)

type ChangeHint struct {
	Type          string    `json:"type"`
	Cursor        int64     `json:"cursor"`
	EntityType    string    `json:"entity_type"`
	EntityID      uuid.UUID `json:"entity_id"`
	EntityVersion int64     `json:"entity_version"`
}

type Hub struct {
	mu          sync.RWMutex
	subscribers map[uuid.UUID]map[chan ChangeHint]struct{}
}

func NewHub() *Hub {
	return &Hub{subscribers: make(map[uuid.UUID]map[chan ChangeHint]struct{})}
}

func (h *Hub) Subscribe(userID uuid.UUID) (<-chan ChangeHint, func()) {
	channel := make(chan ChangeHint, 32)
	h.mu.Lock()
	if h.subscribers[userID] == nil {
		h.subscribers[userID] = make(map[chan ChangeHint]struct{})
	}
	h.subscribers[userID][channel] = struct{}{}
	h.mu.Unlock()
	return channel, func() {
		h.mu.Lock()
		if subscribers := h.subscribers[userID]; subscribers != nil {
			delete(subscribers, channel)
			if len(subscribers) == 0 {
				delete(h.subscribers, userID)
			}
		}
		h.mu.Unlock()
	}
}

func (h *Hub) Publish(userID uuid.UUID, hint ChangeHint) {
	h.mu.RLock()
	defer h.mu.RUnlock()
	for subscriber := range h.subscribers[userID] {
		select {
		case subscriber <- hint:
		default:
			// A later heartbeat or reconnect pull closes any notification gap.
		}
	}
}

func (h *Hub) ConnectionCount(userID uuid.UUID) int {
	h.mu.RLock()
	defer h.mu.RUnlock()
	return len(h.subscribers[userID])
}
