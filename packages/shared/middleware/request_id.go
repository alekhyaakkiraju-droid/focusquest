package middleware

import (
	"context"
	"net/http"

	"github.com/google/uuid"
)

type contextKey string

const requestIDKey contextKey = "request_id"

const RequestIDHeader = "X-Request-ID"

func RequestIDFromContext(ctx context.Context) string {
	if value, ok := ctx.Value(requestIDKey).(string); ok {
		return value
	}
	return ""
}

func resolveRequestID(header string) string {
	if header != "" {
		return header
	}
	return uuid.NewString()
}

func withRequestID(ctx context.Context, requestID string) context.Context {
	return context.WithValue(ctx, requestIDKey, requestID)
}

func PropagateRequestID(req *http.Request) string {
	requestID := resolveRequestID(req.Header.Get(RequestIDHeader))
	req.Header.Set(RequestIDHeader, requestID)
	return requestID
}
