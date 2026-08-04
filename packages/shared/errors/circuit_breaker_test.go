package errors

import (
	"errors"
	"testing"
	"time"
)

func TestCircuitBreakerOpensAfterThreshold(t *testing.T) {
	now := time.Now()
	current := now
	cb := NewCircuitBreaker("timer-service", CircuitBreakerConfig{
		FailureThreshold: 5,
		FailureWindow:    30 * time.Second,
		HalfOpenAfter:    60 * time.Second,
	})
	cb.now = func() time.Time { return current }

	for i := 0; i < 5; i++ {
		current = current.Add(1 * time.Second)
		if err := cb.Execute(func() error { return errors.New("upstream failure") }); err == nil {
			t.Fatalf("attempt %d expected failure", i+1)
		}
	}

	if cb.State() != "open" {
		t.Fatalf("expected open circuit, got %q", cb.State())
	}

	if err := cb.Execute(func() error { return nil }); err == nil {
		t.Fatal("expected circuit open error")
	} else if apiErr := FromError(err); apiErr.Code != CodeCircuitOpen {
		t.Fatalf("unexpected error code: %v", apiErr)
	}
}

func TestCircuitBreakerHalfOpenThenClosed(t *testing.T) {
	current := time.Now()
	cb := NewCircuitBreaker("analytics-service", DefaultCircuitBreakerConfig())
	cb.now = func() time.Time { return current }

	for i := 0; i < 5; i++ {
		current = current.Add(1 * time.Second)
		_ = cb.Execute(func() error { return errors.New("fail") })
	}
	if cb.State() != "open" {
		t.Fatalf("expected open, got %q", cb.State())
	}

	current = current.Add(60 * time.Second)
	if cb.State() != "half-open" {
		t.Fatalf("expected half-open, got %q", cb.State())
	}

	if err := cb.Execute(func() error { return nil }); err != nil {
		t.Fatalf("expected successful half-open probe: %v", err)
	}
	if cb.State() != "closed" {
		t.Fatalf("expected closed after success, got %q", cb.State())
	}
}

func TestCircuitBreakerPerServiceIsolation(t *testing.T) {
	timerBreaker := NewCircuitBreaker("timer-service", DefaultCircuitBreakerConfig())
	questBreaker := NewCircuitBreaker("quest-service", DefaultCircuitBreakerConfig())

	for i := 0; i < 5; i++ {
		_ = timerBreaker.Execute(func() error { return errors.New("fail") })
	}
	if timerBreaker.State() != "open" {
		t.Fatal("timer breaker should be open")
	}
	if questBreaker.State() != "closed" {
		t.Fatal("quest breaker must remain isolated")
	}
}
