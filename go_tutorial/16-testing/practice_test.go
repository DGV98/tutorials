// This module's main exercise is writing this file. Every function
// below is named for the test you should write; replace each
// t.Skip/b.Skip/f.Skip line with a real body. The README walks through
// all the syntax you need, and checked_test.go in this directory is a
// worked example of the table-driven style.
//
// Remember: one of Clamp, Reverse, and Median is buggy. If everything
// you write passes on the first try, your tables are too polite.
package testkit

import "testing"

// TestClamp: a table-driven test with t.Run subtests. Cover at least:
// x below lo, x above hi, x strictly inside the range, and x exactly
// at each boundary. Failure messages should read like
// Clamp(x, lo, hi) = got, want want.
func TestClamp(t *testing.T) {
	t.Skip("write me")
}

// TestReverse: a table-driven test. Think hard about edge cases — the
// empty string, a single character, a palindrome... and remember what
// module 07 taught you about what a Go string actually contains.
func TestReverse(t *testing.T) {
	t.Skip("write me")
}

// TestMedian: a table-driven test covering: empty input (comma-ok
// false), a single value, odd length, even length (mean of the two
// middle values), and input that is NOT already sorted.
func TestMedian(t *testing.T) {
	t.Skip("write me")
}

// TestMedianDoesNotMutate: Median's contract says it never modifies
// xs. Test that behavior directly: build a slice, call Median, then
// compare the slice against a copy taken beforehand (slices.Clone and
// slices.Equal are your friends).
func TestMedianDoesNotMutate(t *testing.T) {
	t.Skip("write me")
}

// BenchmarkReverse: measure Reverse on a string a few hundred bytes
// long (strings.Repeat builds one in one line) using the b.Loop()
// pattern. Run it with:
//
//	go test -run '^$' -bench=Reverse ./16-testing/
//
// (-run '^$' skips the tests: benchmarks only run once the selected
// tests pass, and this package stays red until Part 2 is done.)
func BenchmarkReverse(b *testing.B) {
	b.Skip("write me")
}

// FuzzReverse: seed the corpus with f.Add (include some non-ASCII
// strings), then check two properties inside f.Fuzz: the output of
// Reverse must be valid UTF-8 (unicode/utf8.ValidString), and
// reversing twice must give back the input. t.Skip inputs that are
// not themselves valid UTF-8 — Reverse's contract doesn't cover them.
// Run it with:
//
//	go test -run FuzzReverse -fuzz=Reverse -fuzztime=10s ./16-testing/
//
// (the -run filter matters: -fuzz won't start while other tests in
// the package are failing).
func FuzzReverse(f *testing.F) {
	f.Skip("write me")
}
