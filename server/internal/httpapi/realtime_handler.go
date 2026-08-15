package httpapi

import (
	"context"
	"encoding/json"
	"net/http"
	"time"

	"github.com/coder/websocket"
	"github.com/google/uuid"
)

const heartbeatInterval = 15 * time.Second

func (a *API) realtime(w http.ResponseWriter, r *http.Request) {
	userID, _, ok := identity(r.Context())
	if !ok {
		writeError(w, r, http.StatusUnauthorized, "UNAUTHORIZED", "需要登录")
		return
	}
	cursor, err := a.store.ServerCursor(r.Context(), userID)
	if err != nil {
		writeError(w, r, http.StatusServiceUnavailable, "SYNC_FAILED", "无法读取服务端游标")
		return
	}
	connection, err := websocket.Accept(w, r, &websocket.AcceptOptions{
		OriginPatterns: a.realtimeOrigins,
	})
	if err != nil {
		return
	}
	defer connection.Close(websocket.StatusNormalClosure, "session ended")
	connection.SetReadLimit(4 << 10)

	hints, unsubscribe := a.hub.Subscribe(userID)
	defer unsubscribe()
	ready := map[string]any{
		"type":                   "ready",
		"connection_id":          uuid.New(),
		"server_cursor":          cursor,
		"heartbeat_interval_sec": int(heartbeatInterval.Seconds()),
	}
	if err := writeWebSocketJSON(r.Context(), connection, ready); err != nil {
		return
	}

	readErrors := make(chan error, 1)
	go func() {
		for {
			_, message, err := connection.Read(r.Context())
			if err != nil {
				readErrors <- err
				return
			}
			var envelope struct {
				Type string `json:"type"`
			}
			if json.Unmarshal(message, &envelope) != nil {
				continue
			}
			if envelope.Type != "heartbeat_ack" {
				continue
			}
		}
	}()

	ticker := time.NewTicker(heartbeatInterval)
	defer ticker.Stop()
	for {
		select {
		case <-r.Context().Done():
			return
		case <-readErrors:
			return
		case hint := <-hints:
			if err := writeWebSocketJSON(r.Context(), connection, hint); err != nil {
				return
			}
		case tick := <-ticker.C:
			heartbeat := map[string]any{
				"type":        "heartbeat",
				"server_time": tick.UTC().Format(time.RFC3339Nano),
			}
			if err := writeWebSocketJSON(r.Context(), connection, heartbeat); err != nil {
				return
			}
			pingContext, cancel := context.WithTimeout(r.Context(), 10*time.Second)
			err := connection.Ping(pingContext)
			cancel()
			if err != nil {
				return
			}
		}
	}
}

func writeWebSocketJSON(
	ctx context.Context,
	connection *websocket.Conn,
	value any,
) error {
	encoded, err := json.Marshal(value)
	if err != nil {
		return err
	}
	writeContext, cancel := context.WithTimeout(ctx, 10*time.Second)
	defer cancel()
	return connection.Write(writeContext, websocket.MessageText, encoded)
}
