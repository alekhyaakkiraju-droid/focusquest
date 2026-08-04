package errors

import (
	"net/http"
	"testing"
)

func TestErrorTypesStatusCodes(t *testing.T) {
	tests := []struct {
		name   string
		err    *APIError
		status int
		code   string
	}{
		{"validation", ValidationError("invalid email", Detail{Field: "email", Reason: "format"}), http.StatusBadRequest, CodeValidation},
		{"authentication", AuthenticationError(""), http.StatusUnauthorized, CodeAuthentication},
		{"authorization", AuthorizationError(""), http.StatusForbidden, CodeAuthorization},
		{"not found", NotFoundError("Child profile"), http.StatusNotFound, CodeNotFound},
		{"rate limit", RateLimitError(""), http.StatusTooManyRequests, CodeRateLimit},
		{"internal", InternalError("database unavailable", nil), http.StatusInternalServerError, CodeInternal},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			if tc.err.StatusCode != tc.status {
				t.Fatalf("expected status %d, got %d", tc.status, tc.err.StatusCode)
			}
			if tc.err.Code != tc.code {
				t.Fatalf("expected code %q, got %q", tc.code, tc.err.Code)
			}
			response := tc.err.ToResponse()
			if response.ErrorCode != tc.code {
				t.Fatalf("unexpected response code: %+v", response)
			}
			if response.Details == nil {
				t.Fatal("expected non-nil details slice in JSON response")
			}
		})
	}
}

func TestFromErrorPreservesAPIError(t *testing.T) {
	original := NotFoundError("Quest")
	mapped := FromError(original)
	if mapped != original {
		t.Fatal("expected same API error instance")
	}
}

func TestInternalErrorMessageIsActionable(t *testing.T) {
	err := InternalError("Failed to persist child profile", nil)
	if err.Message == "Internal Server Error" {
		t.Fatal("error message must not be generic")
	}
}
