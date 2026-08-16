package httpapi

import (
	"context"

	"github.com/google/uuid"
)

type contextKey string

const (
	requestIDKey contextKey = "request_id"
	userIDKey    contextKey = "user_id"
	deviceIDKey  contextKey = "device_id"
)

func requestID(ctx context.Context) string {
	value, _ := ctx.Value(requestIDKey).(string)
	return value
}

func identity(ctx context.Context) (uuid.UUID, uuid.UUID, bool) {
	userID, userOK := ctx.Value(userIDKey).(uuid.UUID)
	deviceID, deviceOK := ctx.Value(deviceIDKey).(uuid.UUID)
	return userID, deviceID, userOK && deviceOK
}
