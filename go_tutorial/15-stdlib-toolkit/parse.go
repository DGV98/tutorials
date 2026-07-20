package toolkit

import (
	"io"
	"time"
)

// ExtractInts returns every integer that appears in s, in order of
// appearance — the single most useful Advent of Code helper. An
// integer is a match of the pattern -?\d+: a run of digits, optionally
// preceded by an immediately attached minus sign. So
//
//	ExtractInts("move -12 from 3 to 45") = [-12 3 45]
//	ExtractInts("3 - 4") = [3 4]   // detached dash is not a sign
//	ExtractInts("1-2") = [1 -2]    // attached dash IS a sign (see README)
//
// If s contains no digits, ExtractInts returns nil. Values are assumed
// to fit in int.
//
// Hint: compile the pattern once with regexp.MustCompile in a
// package-level var, then use FindAllString(s, -1).
func ExtractInts(s string) []int {
	// TODO: implement
	return nil
}

// An Event is one timestamped log line.
type Event struct {
	At  time.Time
	Msg string
}

// ParseEvents reads lines of the form
//
//	2024-01-02 15:04|message text
//
// from r and returns them as Events, in input order. The timestamp is
// parsed with time.Parse using the layout "2006-01-02 15:04" (Go's
// reference time — see the README). The message is everything after
// the first '|', kept verbatim. Lines are trimmed of surrounding
// whitespace first, and blank lines are skipped.
//
// If a line has no '|', or its timestamp does not parse, ParseEvents
// returns (nil, err) where err mentions the offending line.
//
// Hint: strings.Cut splits on the first '|' and tells you whether one
// was found.
func ParseEvents(r io.Reader) ([]Event, error) {
	// TODO: implement
	return nil, nil
}

// Span returns the Duration from the earliest event in events to the
// latest, regardless of the order they appear in. With fewer than two
// events there is nothing to span, so Span returns 0.
//
// Hint: time.Time values are compared with Before/After and subtracted
// with Sub, which yields a time.Duration.
func Span(events []Event) time.Duration {
	// TODO: implement
	return 0
}
