package errors

import (
	"math/rand"
	"time"
)

// RetryConfig controls exponential backoff retries for inter-service calls.
type RetryConfig struct {
	MaxRetries int
	BaseDelay  time.Duration
}

// DefaultRetryConfig matches WO-007 defaults: max 3 retries, 100ms base delay.
func DefaultRetryConfig() RetryConfig {
	return RetryConfig{
		MaxRetries: 3,
		BaseDelay:  100 * time.Millisecond,
	}
}

// Retry executes fn with exponential backoff and jitter between attempts.
func Retry(cfg RetryConfig, fn func() error) error {
	if cfg.MaxRetries <= 0 {
		cfg = DefaultRetryConfig()
	}
	if cfg.BaseDelay <= 0 {
		cfg.BaseDelay = 100 * time.Millisecond
	}

	var err error
	for attempt := 0; attempt <= cfg.MaxRetries; attempt++ {
		err = fn()
		if err == nil {
			return nil
		}
		if attempt == cfg.MaxRetries {
			break
		}
		delay := backoffDelay(cfg.BaseDelay, attempt)
		time.Sleep(delay)
	}
	return err
}

func backoffDelay(base time.Duration, attempt int) time.Duration {
	multiplier := time.Duration(1 << attempt)
	delay := base * multiplier
	jitter := time.Duration(rand.Int63n(int64(delay / 2)))
	return delay + jitter
}

// RetryWithBreaker combines circuit breaker protection with retry/backoff.
func RetryWithBreaker(breaker *CircuitBreaker, retryCfg RetryConfig, fn func() error) error {
	return Retry(retryCfg, func() error {
		return breaker.Execute(fn)
	})
}
