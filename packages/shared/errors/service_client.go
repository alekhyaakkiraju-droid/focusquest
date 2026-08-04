package errors

import (
	"fmt"
	"net/http"
	"time"
)

// ServiceClient wraps outbound HTTP calls with per-service circuit breaking and retry.
type ServiceClient struct {
	ServiceName string
	BaseURL     string
	Breaker     *CircuitBreaker
	Retry       RetryConfig
	Client      *http.Client
}

func NewServiceClient(serviceName, baseURL string) *ServiceClient {
	return &ServiceClient{
		ServiceName: serviceName,
		BaseURL:     baseURL,
		Breaker:     NewCircuitBreaker(serviceName, DefaultCircuitBreakerConfig()),
		Retry:       DefaultRetryConfig(),
		Client:      &http.Client{Timeout: 10 * time.Second},
	}
}

func (c *ServiceClient) Do(req *http.Request) (*http.Response, error) {
	var resp *http.Response
	err := RetryWithBreaker(c.Breaker, c.Retry, func() error {
		var callErr error
		resp, callErr = c.Client.Do(req)
		if callErr != nil {
			return InternalError(fmt.Sprintf("Call to %s failed", c.ServiceName), callErr)
		}
		if resp.StatusCode >= http.StatusInternalServerError {
			return InternalError(
				fmt.Sprintf("%s returned a server error (status %d)", c.ServiceName, resp.StatusCode),
				nil,
			)
		}
		return nil
	})
	return resp, err
}
