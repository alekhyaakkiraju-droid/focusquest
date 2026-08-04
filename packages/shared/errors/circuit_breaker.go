package errors

import (
	"errors"
	"sync"
	"time"
)

type breakerState int

const (
	stateClosed breakerState = iota
	stateOpen
	stateHalfOpen
)

// CircuitBreakerConfig controls when a per-service circuit opens and retries.
type CircuitBreakerConfig struct {
	FailureThreshold int
	FailureWindow    time.Duration
	HalfOpenAfter    time.Duration
}

// DefaultCircuitBreakerConfig matches WO-007 defaults: 5 failures in 30s, 60s half-open.
func DefaultCircuitBreakerConfig() CircuitBreakerConfig {
	return CircuitBreakerConfig{
		FailureThreshold: 5,
		FailureWindow:    30 * time.Second,
		HalfOpenAfter:    60 * time.Second,
	}
}

// CircuitBreaker protects inter-service calls for a single upstream dependency.
type CircuitBreaker struct {
	name string
	cfg  CircuitBreakerConfig
	now  func() time.Time

	mu         sync.Mutex
	state      breakerState
	failures   []time.Time
	openedAt   time.Time
	halfOpenIn bool
}

func NewCircuitBreaker(name string, cfg CircuitBreakerConfig) *CircuitBreaker {
	if cfg.FailureThreshold <= 0 {
		cfg = DefaultCircuitBreakerConfig()
	}
	return &CircuitBreaker{
		name: name,
		cfg:  cfg,
		now:  time.Now,
	}
}

func (cb *CircuitBreaker) Name() string {
	return cb.name
}

func (cb *CircuitBreaker) State() string {
	cb.mu.Lock()
	defer cb.mu.Unlock()
	cb.refreshStateLocked()
	switch cb.state {
	case stateOpen:
		return "open"
	case stateHalfOpen:
		return "half-open"
	default:
		return "closed"
	}
}

func (cb *CircuitBreaker) Execute(fn func() error) error {
	if err := cb.beforeCall(); err != nil {
		return err
	}

	err := fn()
	cb.afterCall(err)
	return err
}

func (cb *CircuitBreaker) beforeCall() error {
	cb.mu.Lock()
	defer cb.mu.Unlock()

	cb.refreshStateLocked()
	if cb.state == stateOpen {
		return CircuitOpenError(cb.name)
	}
	return nil
}

func (cb *CircuitBreaker) afterCall(err error) {
	cb.mu.Lock()
	defer cb.mu.Unlock()

	if err == nil {
		cb.failures = nil
		cb.state = stateClosed
		cb.halfOpenIn = false
		return
	}

	if cb.state == stateHalfOpen {
		cb.state = stateOpen
		cb.openedAt = cb.now()
		cb.halfOpenIn = false
		return
	}

	cb.failures = append(cb.failures, cb.now())
	cb.pruneFailuresLocked()
	if len(cb.failures) >= cb.cfg.FailureThreshold {
		cb.state = stateOpen
		cb.openedAt = cb.now()
	}
}

func (cb *CircuitBreaker) refreshStateLocked() {
	if cb.state != stateOpen {
		return
	}
	if cb.now().Sub(cb.openedAt) >= cb.cfg.HalfOpenAfter {
		cb.state = stateHalfOpen
		cb.halfOpenIn = true
	}
}

func (cb *CircuitBreaker) pruneFailuresLocked() {
	cutoff := cb.now().Add(-cb.cfg.FailureWindow)
	kept := cb.failures[:0]
	for _, ts := range cb.failures {
		if ts.After(cutoff) {
			kept = append(kept, ts)
		}
	}
	cb.failures = kept
}

var ErrMaxRetriesExceeded = errors.New("errors: max retries exceeded")
