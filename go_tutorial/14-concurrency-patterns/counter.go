package patterns

import "sync"

// A SafeCounter counts occurrences of string keys and is safe for
// concurrent use by multiple goroutines. The zero value is ready to
// use:
//
//	var c SafeCounter
//	c.Inc("gold")
//
// The mutex guards counts: every access to the map — reads included —
// must happen between mu.Lock() and mu.Unlock(). Declaring the mutex
// directly above the fields it protects is the standard Go convention
// for saying so.
type SafeCounter struct {
	mu     sync.Mutex
	counts map[string]int
}

// Inc adds 1 to the count stored under key. It is safe to call from
// many goroutines at once.
//
// Because the zero value of SafeCounter has a nil map, Inc must
// lazily allocate counts the first time it is called — inside the
// locked region, so two goroutines cannot both allocate.
//
// Hint: lock, defer unlock, allocate the map if nil, increment.
func (c *SafeCounter) Inc(key string) {
	// TODO: implement
}

// Value returns the current count for key, or 0 if key has never been
// incremented.
//
// Value must take the lock too: a read of a map that another
// goroutine may be writing is a data race even though it "usually
// works" — and go test -race will say so. (Reading a nil map is fine;
// only writes to nil maps panic.)
func (c *SafeCounter) Value(key string) int {
	// TODO: implement
	return 0
}
