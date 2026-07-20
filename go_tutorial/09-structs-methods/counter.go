package records

// Counter counts events. Its zero value is ready to use: `var c Counter`
// starts at 0. Because Counter is a plain value type, assigning one
// Counter to another copies the current count, and the two then advance
// independently.
//
// Counter deliberately mixes receiver kinds so you can feel the
// difference; in production code you would give every method a pointer
// receiver once any method needs one (be consistent per type).
type Counter struct {
	n int
}

// Increment adds one to the counter. It must use a pointer receiver:
// with a value receiver it would increment a private copy that is thrown
// away when the method returns.
func (c *Counter) Increment() {
	// TODO: implement
}

// Value returns the current count. Reading does not mutate anything, and
// a Counter is tiny, so a value receiver works fine here.
func (c Counter) Value() int {
	// TODO: implement
	return 0
}
