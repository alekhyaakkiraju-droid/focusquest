package errors

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestWriteErrorJSONFormat(t *testing.T) {
	var logBuffer bytes.Buffer
	original := logOutput
	logOutput = &logBuffer
	t.Cleanup(func() { logOutput = original })

	req := httptest.NewRequest(http.MethodPost, "/v1/children", nil)
	rec := httptest.NewRecorder()

	WriteError(rec, req, "auth-service", ValidationError(
		"Child profile validation failed",
		Detail{Field: "age_range", Reason: "must be one of 5-6, 7-9, 10-12"},
	))

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", rec.Code)
	}

	var body ErrorResponse
	if err := json.NewDecoder(rec.Body).Decode(&body); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if body.ErrorCode != CodeValidation {
		t.Fatalf("unexpected error_code: %+v", body)
	}
	if body.Message == "" || len(body.Details) != 1 {
		t.Fatalf("unexpected body: %+v", body)
	}
	if logBuffer.Len() > 0 {
		t.Fatal("4xx errors must not emit server error logs")
	}
}

func TestWriteErrorLogsServerErrors(t *testing.T) {
	var logBuffer bytes.Buffer
	original := logOutput
	logOutput = &logBuffer
	t.Cleanup(func() { logOutput = original })

	req := httptest.NewRequest(http.MethodGet, "/v1/children/123", nil)
	req.Header.Set("X-Request-ID", "req-500")
	rec := httptest.NewRecorder()

	WriteError(rec, req, "auth-service", InternalError("Database connection failed", nil))

	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("expected 500, got %d", rec.Code)
	}
	if logBuffer.Len() == 0 {
		t.Fatal("expected structured log for 5xx error")
	}

	var entry serverErrorLogEntry
	if err := json.Unmarshal(bytes.TrimSpace(logBuffer.Bytes()), &entry); err != nil {
		t.Fatalf("invalid server error log: %v", err)
	}
	if entry.RequestID != "req-500" || entry.StatusCode != 500 || entry.ErrorCode != CodeInternal {
		t.Fatalf("unexpected log entry: %+v", entry)
	}
}

func TestRecoverMiddlewareReturnsStructuredError(t *testing.T) {
	handler := RecoverMiddleware("quest-service", http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		panic("unexpected fault")
	}))

	req := httptest.NewRequest(http.MethodGet, "/v1/quests", nil)
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("expected 500, got %d", rec.Code)
	}

	var body ErrorResponse
	if err := json.NewDecoder(rec.Body).Decode(&body); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if body.ErrorCode != CodeInternal {
		t.Fatalf("unexpected body: %+v", body)
	}
}
