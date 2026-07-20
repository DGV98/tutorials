// Package errs contains the exercises for module 11: creating errors,
// the if err != nil idiom, wrapping with %w, inspecting with errors.Is
// and errors.As, sentinel errors, custom error types, and converting
// panics into errors with recover.
package errs

import "errors"

// ErrNotFound is the sentinel error reported by Lookup when a key is
// absent. Callers test for it with errors.Is(err, ErrNotFound) — never
// with ==, because Lookup wraps it in context before returning it.
var ErrNotFound = errors.New("not found")

// A ValidationError describes a single invalid field. It carries
// structured data — which field failed and why — so callers can react
// programmatically instead of string-matching the message.
//
// Its Error method uses a pointer receiver, which makes
// *ValidationError (not ValidationError) the type that satisfies the
// error interface; that is the type callers must pass to errors.As.
type ValidationError struct {
	Field  string
	Reason string
}

// Error returns the message "<field>: <reason>", for example
// "name: must not be empty". Note the convention: lowercase, no
// trailing punctuation.
func (e *ValidationError) Error() string {
	// TODO: implement
	return ""
}

// SafeDivide returns a divided by b.
//
// If b == 0 it returns (0, err) where err is non-nil and its message
// is exactly "division by zero". Otherwise it returns (a/b, nil).
func SafeDivide(a, b float64) (float64, error) {
	// TODO: implement
	return 0, nil
}

// ParseAge parses s as an age in whole years.
//
// On success it returns (n, nil). On failure it returns (0, err):
//
//   - If s is not a valid integer, err adds context and wraps the
//     strconv error with %w, so errors.Is(err, strconv.ErrSyntax) —
//     or strconv.ErrRange for overflow — still reports true. The
//     message must contain s quoted, e.g. `parse age "abc": ...`
//     (the %q verb quotes for you).
//   - If s parses but the value is negative, err is a plain
//     (non-wrapping) error with the message
//     "age <n> must not be negative", e.g. "age -3 must not be negative".
func ParseAge(s string) (int, error) {
	// TODO: implement
	return 0, nil
}

// Lookup returns the value stored under key in m.
//
// If key is present it returns (m[key], nil) — including when the
// stored value is 0. If key is absent it returns (0, err) where err
// wraps ErrNotFound with the key as context; the message is exactly
// `lookup "<key>": not found`. A nil map has no keys, so every lookup
// in it reports ErrNotFound.
func Lookup(m map[string]int, key string) (int, error) {
	// TODO: implement
	return 0, nil
}

// ValidateUser checks a user record and returns nil if it is valid.
// Rules, checked in this order (first failure wins):
//
//   - name must not be empty: otherwise the result is a
//     *ValidationError with Field "name" and Reason "must not be empty".
//   - age must be in [0, 150]: otherwise Field "age" and Reason
//     "must be between 0 and 150".
func ValidateUser(name string, age int) error {
	// TODO: implement
	return nil
}

// Chain wraps err in two layers of context, the way a real error
// gathers context while climbing back up the call stack. The inner
// layer adds the prefix "inner: " and the outer layer adds "outer: ",
// both via fmt.Errorf with the %w verb, so the final message is
// exactly "outer: inner: <err's message>" and errors.Is / errors.As
// still see the original err at the bottom of the chain.
//
// Chain(nil) returns nil — no failure, no error to decorate.
func Chain(err error) error {
	// TODO: implement
	return nil
}

// DontPanic calls f and converts a panic, if one occurs, into an
// ordinary error — the standard trick at API boundaries (it is the
// essence of what net/http does around your handlers).
//
// If f returns normally, DontPanic returns nil. If f panics with
// value v, DontPanic recovers and returns a non-nil error whose
// message is "panic: <v>", with v formatted by the %v verb.
//
// Hints: recover only has an effect inside a deferred function, and
// the named return value err is the only channel through which that
// deferred function can hand the error to the caller.
func DontPanic(f func()) (err error) {
	// TODO: implement
	return nil
}
