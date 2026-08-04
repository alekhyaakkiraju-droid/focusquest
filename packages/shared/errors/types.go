package errors

import (
	"fmt"
	"net/http"
)

const (
	CodeValidation      = "VALIDATION_ERROR"
	CodeAuthentication  = "AUTHENTICATION_ERROR"
	CodeAuthorization   = "AUTHORIZATION_ERROR"
	CodeNotFound        = "NOT_FOUND"
	CodeRateLimit       = "RATE_LIMIT_EXCEEDED"
	CodeInternal        = "INTERNAL_ERROR"
	CodeCircuitOpen     = "CIRCUIT_OPEN"
)

// Detail describes a field-level validation or business rule failure.
type Detail struct {
	Field  string `json:"field"`
	Reason string `json:"reason"`
}

// ErrorResponse is the standard JSON error envelope for all FocusQuest APIs.
type ErrorResponse struct {
	ErrorCode string   `json:"error_code"`
	Message   string   `json:"message"`
	Details   []Detail `json:"details"`
}

// APIError is a typed service error with an HTTP status code and client-safe message.
type APIError struct {
	Code       string
	Message    string
	StatusCode int
	Details    []Detail
	cause      error
}

func (e *APIError) Error() string {
	if e.cause != nil {
		return fmt.Sprintf("%s: %s (%v)", e.Code, e.Message, e.cause)
	}
	return fmt.Sprintf("%s: %s", e.Code, e.Message)
}

func (e *APIError) Unwrap() error {
	return e.cause
}

func (e *APIError) ToResponse() ErrorResponse {
	details := e.Details
	if details == nil {
		details = []Detail{}
	}
	return ErrorResponse{
		ErrorCode: e.Code,
		Message:   e.Message,
		Details:   details,
	}
}

func newAPIError(code, message string, status int, details []Detail, cause error) *APIError {
	return &APIError{
		Code:       code,
		Message:    message,
		StatusCode: status,
		Details:    details,
		cause:      cause,
	}
}

func ValidationError(message string, details ...Detail) *APIError {
	if message == "" {
		message = "One or more request fields are invalid"
	}
	return newAPIError(CodeValidation, message, http.StatusBadRequest, details, nil)
}

func AuthenticationError(message string) *APIError {
	if message == "" {
		message = "Authentication is required to access this resource"
	}
	return newAPIError(CodeAuthentication, message, http.StatusUnauthorized, nil, nil)
}

func AuthorizationError(message string) *APIError {
	if message == "" {
		message = "You do not have permission to perform this action"
	}
	return newAPIError(CodeAuthorization, message, http.StatusForbidden, nil, nil)
}

func NotFoundError(resource string) *APIError {
	message := "The requested resource was not found"
	if resource != "" {
		message = fmt.Sprintf("%s was not found", resource)
	}
	return newAPIError(CodeNotFound, message, http.StatusNotFound, nil, nil)
}

func RateLimitError(message string) *APIError {
	if message == "" {
		message = "Rate limit exceeded; retry after a short delay"
	}
	return newAPIError(CodeRateLimit, message, http.StatusTooManyRequests, nil, nil)
}

func InternalError(message string, cause error) *APIError {
	if message == "" {
		message = "An unexpected error occurred while processing the request"
	}
	return newAPIError(CodeInternal, message, http.StatusInternalServerError, nil, cause)
}

func CircuitOpenError(serviceName string) *APIError {
	message := fmt.Sprintf("Upstream service %s is temporarily unavailable", serviceName)
	return newAPIError(CodeCircuitOpen, message, http.StatusServiceUnavailable, nil, nil)
}

// FromError maps unknown errors to InternalError while preserving typed API errors.
func FromError(err error) *APIError {
	if err == nil {
		return nil
	}
	if apiErr, ok := err.(*APIError); ok {
		return apiErr
	}
	return InternalError("An unexpected error occurred while processing the request", err)
}
