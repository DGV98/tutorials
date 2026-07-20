package runner

import "errors"

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
//
// Remember: the zero value of a map is nil, and writing to a nil map
// panics — the constructor exists so Register can't blow up.
func NewRegistry() *Registry {
	// TODO: implement
	return nil
}

// Register adds s as the solver for the given day.
// It returns an error if day < 1, and an error wrapping ErrDuplicateDay
// (include the day number in the message) if the day is already registered.
func (r *Registry) Register(day int, s Solver) error {
	// TODO: implement
	return nil
}

// Get returns the solver registered for day. If none is registered it
// returns an error wrapping ErrUnknownDay that includes the day number.
func (r *Registry) Get(day int) (Solver, error) {
	// TODO: implement
	return nil, nil
}

// Days returns every registered day in ascending order.
// Remember: map iteration order is random — you must sort.
func (r *Registry) Days() []int {
	// TODO: implement
	return nil
}
