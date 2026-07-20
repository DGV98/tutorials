package records

import "testing"

func TestCounter(t *testing.T) {
	var c Counter // the zero value must be ready to use
	if got := c.Value(); got != 0 {
		t.Errorf("Value() on a zero Counter = %d, want 0", got)
	}
	for i := 0; i < 3; i++ {
		c.Increment()
	}
	if got := c.Value(); got != 3 {
		t.Errorf("Value() after 3 Increments = %d, want 3", got)
	}
	c.Increment()
	if got := c.Value(); got != 4 {
		t.Errorf("Value() after 4 Increments = %d, want 4", got)
	}
}

// TestCounterCopy pins down value semantics: assigning a struct copies it,
// so a snapshot must not see Increments that happen afterwards.
func TestCounterCopy(t *testing.T) {
	var c Counter
	c.Increment()
	c.Increment()

	snapshot := c // structs are values: this copies the count
	c.Increment()

	if got := snapshot.Value(); got != 2 {
		t.Errorf("snapshot.Value() = %d, want 2 (a copy must not track the original)", got)
	}
	if got := c.Value(); got != 3 {
		t.Errorf("c.Value() = %d, want 3", got)
	}
}
