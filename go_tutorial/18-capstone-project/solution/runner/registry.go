package runner

import (
	"errors"
	"fmt"
	"slices"
)

// Sentinel errors for registry lookups. Callers match them with errors.Is,
// so every error returned by Register/Get must wrap the right sentinel
// (see module 11).
var (
	// ErrUnknownDay is wrapped by Get when no solver is registered for a day.
	ErrUnknownDay = errors.New("unknown day")

	// ErrDuplicateDay is wrapped by Register when the day is already taken.
	ErrDuplicateDay = errors.New("duplicate day")
)

// Registry maps day numbers to their solvers.
type Registry struct {
	solvers map[int]Solver
}

// NewRegistry returns an empty, ready-to-use Registry.
func NewRegistry() *Registry {
	return &Registry{solvers: make(map[int]Solver)}
}

// Register adds s as the solver for the given day.
// It returns an error if day < 1, and an error wrapping ErrDuplicateDay
// if the day is already registered.
func (r *Registry) Register(day int, s Solver) error {
	if day < 1 {
		return fmt.Errorf("register day %d: days start at 1", day)
	}
	if _, taken := r.solvers[day]; taken {
		return fmt.Errorf("register day %d: %w", day, ErrDuplicateDay)
	}
	r.solvers[day] = s
	return nil
}

// Get returns the solver registered for day, or an error wrapping
// ErrUnknownDay.
func (r *Registry) Get(day int) (Solver, error) {
	s, ok := r.solvers[day]
	if !ok {
		return nil, fmt.Errorf("day %d: %w", day, ErrUnknownDay)
	}
	return s, nil
}

// Days returns every registered day in ascending order.
func (r *Registry) Days() []int {
	days := make([]int, 0, len(r.solvers))
	for day := range r.solvers {
		days = append(days, day)
	}
	slices.Sort(days)
	return days
}
