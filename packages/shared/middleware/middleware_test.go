package middleware

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestLoggingMiddlewareEmitsRequiredFields(t *testing.T) {
	var logBuffer bytes.Buffer
	original := logOutput
	logOutput = &logBuffer
	t.Cleanup(func() { logOutput = original })

	handler := Chain("auth-service", http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))

	req := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	req.Header.Set("X-User-ID", "parent-123")
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Header().Get(RequestIDHeader) == "" {
		t.Fatalf("expected %s response header", RequestIDHeader)
	}

	var entry logEntry
	if err := json.Unmarshal(bytes.TrimSpace(logBuffer.Bytes()), &entry); err != nil {
		t.Fatalf("log output is not valid JSON: %v", err)
	}

	if entry.RequestID == "" || entry.ServiceName != "auth-service" || entry.Method != "GET" {
		t.Fatalf("unexpected log entry: %+v", entry)
	}
	if entry.Path != "/healthz" || entry.StatusCode != 200 {
		t.Fatalf("unexpected log entry values: %+v", entry)
	}
	if entry.UserID != "parent-123" {
		t.Fatalf("expected user_id in log, got %q", entry.UserID)
	}
}

func TestRequestIDPropagation(t *testing.T) {
	incoming := "test-request-id-123"
	handler := Chain("timer-service", http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if got := r.Header.Get(RequestIDHeader); got != incoming {
			t.Fatalf("expected propagated request id %q, got %q", incoming, got)
		}
	}))

	req := httptest.NewRequest(http.MethodGet, "/sessions", nil)
	req.Header.Set(RequestIDHeader, incoming)
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Header().Get(RequestIDHeader) != incoming {
		t.Fatalf("expected response header %q", incoming)
	}
}

func TestPIIMasking(t *testing.T) {
	masked := maskPII("/users?email=child@example.com&child_name=Maya")
	if strings.Contains(masked, "child@example.com") || strings.Contains(masked, "Maya") {
		t.Fatalf("PII was not masked: %s", masked)
	}
}

func TestOutboundRequestPropagatesRequestID(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "http://example.com/internal", nil)
	req.Header.Set(RequestIDHeader, "abc-123")
	OutboundRequest(req)
	if req.Header.Get(RequestIDHeader) != "abc-123" {
		t.Fatalf("request id not preserved on outbound request")
	}
}
