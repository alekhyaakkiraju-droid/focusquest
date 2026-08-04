package errors

import (
	"encoding/json"
	"io"
	"net/http"
	"os"

	sharedmw "github.com/alekhyaakkiraju-droid/focusquest/packages/shared/middleware"
)

var logOutput io.Writer = os.Stderr

type serverErrorLogEntry struct {
	RequestID   string `json:"request_id"`
	ServiceName string `json:"service_name"`
	Method      string `json:"method"`
	Path        string `json:"path"`
	ErrorCode   string `json:"error_code"`
	Message     string `json:"message"`
	StatusCode  int    `json:"status_code"`
}

func emitServerErrorLog(entry serverErrorLogEntry) {
	payload, err := json.Marshal(entry)
	if err != nil {
		return
	}
	_, _ = logOutput.Write(append(payload, '\n'))
}

// WriteError serializes an API error to the standard JSON response format.
func WriteError(w http.ResponseWriter, r *http.Request, serviceName string, err error) {
	apiErr := FromError(err)
	response := apiErr.ToResponse()

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(apiErr.StatusCode)
	_ = json.NewEncoder(w).Encode(response)

	if apiErr.StatusCode >= http.StatusInternalServerError {
		requestID := r.Header.Get(sharedmw.RequestIDHeader)
		if requestID == "" {
			requestID = sharedmw.RequestIDFromContext(r.Context())
		}
		emitServerErrorLog(serverErrorLogEntry{
			RequestID:   requestID,
			ServiceName: serviceName,
			Method:      r.Method,
			Path:        r.URL.Path,
			ErrorCode:   apiErr.Code,
			Message:     apiErr.Message,
			StatusCode:  apiErr.StatusCode,
		})
	}
}

// RecoverMiddleware converts panics into structured 500 responses and logs request context.
func RecoverMiddleware(serviceName string, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if recovered := recover(); recovered != nil {
				WriteError(w, r, serviceName, InternalError(
					"Request processing failed due to an unexpected error",
					nil,
				))
			}
		}()
		next.ServeHTTP(w, r)
	})
}
