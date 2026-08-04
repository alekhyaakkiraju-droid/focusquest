package errors

import (
	"errors"
	"testing"
	"time"
)

func TestRetryStopsAfterMaxAttempts(t *testing.T) {
	attempts := 0
	err := Retry(RetryConfig{MaxRetries: 3, BaseDelay: time.Millisecond}, func() error {
		attempts++
		return errors.New("temporary failure")
	})
	if err == nil {
		t.Fatal("expected error after retries exhausted")
	}
	if attempts != 4 {
		t.Fatalf("expected 4 attempts (initial + 3 retries), got %d", attempts)
	}
}

func TestRetrySucceedsBeforeMaxAttempts(t *testing.T) {
	attempts := 0
	err := Retry(DefaultRetryConfig(), func() error {
		attempts++
		if attempts < 2 {
			return errors.New("temporary failure")
		}
		return nil
	})
	if err != nil {
		t.Fatalf("expected success, got %v", err)
	}
	if attempts != 2 {
		t.Fatalf("expected 2 attempts, got %d", attempts)
	}
}

func TestBackoffDelayIncreasesExponentially(t *testing.T) {
	first := backoffDelay(100*time.Millisecond, 0)
	second := backoffDelay(100*time.Millisecond, 1)
	if second <= first {
		t.Fatalf("expected exponential increase, first=%v second=%v", first, second)
	}
}

func TestRetryWithBreakerRespectsOpenCircuit(t *testing.T) {
	current := time.Now()
	breaker := NewCircuitBreaker("notification-service", DefaultCircuitBreakerConfig())
	breaker.now = func() time.Time { return current }

	for i := 0; i < 5; i++ {
		current = current.Add(time.Second)
		_ = breaker.Execute(func() error { return errors.New("fail") })
	}

	attempts := 0
	err := RetryWithBreaker(breaker, RetryConfig{MaxRetries: 3, BaseDelay: time.Millisecond}, func() error {
		attempts++
		return nil
	})
	if err == nil {
		t.Fatal("expected circuit open error")
	}
	if attempts != 0 {
		t.Fatalf("expected zero upstream attempts while circuit open, got %d", attempts)
	}
}
