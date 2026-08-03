package middleware

import (
	"encoding/json"
	"io"
	"net/http"
	"os"
	"regexp"
	"strings"
	"time"
)

var (
	emailPattern = regexp.MustCompile(`[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}`)
	namePattern  = regexp.MustCompile(`(?i)(child_name|display_name|email)=([^&\s]+)`)
	logOutput    io.Writer = os.Stdout
)

type logEntry struct {
	RequestID   string `json:"request_id"`
	UserID      string `json:"user_id"`
	ServiceName string `json:"service_name"`
	Method      string `json:"method"`
	Path        string `json:"path"`
	StatusCode  int    `json:"status_code"`
	LatencyMS   int64  `json:"latency_ms"`
}

type statusRecorder struct {
	http.ResponseWriter
	status int
}

func (rec *statusRecorder) WriteHeader(status int) {
	rec.status = status
	rec.ResponseWriter.WriteHeader(status)
}

func maskPII(value string) string {
	masked := emailPattern.ReplaceAllString(value, "[REDACTED_EMAIL]")
	masked = namePattern.ReplaceAllString(masked, "$1=[REDACTED]")
	return masked
}

func userIDFromRequest(req *http.Request) string {
	userID := req.Header.Get("X-User-ID")
	if userID == "" {
		userID = "anonymous"
	}
	return maskPII(userID)
}

func emitStructuredLog(entry logEntry) {
	payload, err := json.Marshal(entry)
	if err != nil {
		return
	}
	_, _ = logOutput.Write(append(payload, '\n'))
}

func Logging(serviceName string, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, req *http.Request) {
		start := time.Now()
		requestID := PropagateRequestID(req)
		ctx := withRequestID(req.Context(), requestID)
		req = req.WithContext(ctx)

		recorder := &statusRecorder{ResponseWriter: w, status: http.StatusOK}
		w.Header().Set(RequestIDHeader, requestID)
		next.ServeHTTP(recorder, req)

		emitStructuredLog(logEntry{
			RequestID:   requestID,
			UserID:      userIDFromRequest(req),
			ServiceName: serviceName,
			Method:      req.Method,
			Path:        maskPII(req.URL.Path),
			StatusCode:  recorder.status,
			LatencyMS:   time.Since(start).Milliseconds(),
		})
	})
}

func Chain(serviceName string, handler http.Handler) http.Handler {
	return Tracing(serviceName, Logging(serviceName, handler))
}

func JoinServiceName(parts ...string) string {
	return strings.Join(parts, "-")
}
