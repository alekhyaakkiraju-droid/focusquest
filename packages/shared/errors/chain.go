package errors

import (
	"net/http"
)

// Chain wraps a handler with panic recovery and standardized 5xx error responses.
func Chain(serviceName string, handler http.Handler) http.Handler {
	return RecoverMiddleware(serviceName, handler)
}
