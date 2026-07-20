// Package hello is module 1 of the course: the Go toolchain and string
// formatting with the fmt package. This is the reference solution.
package hello

import "fmt"

// Greet returns a greeting for name, in exactly this form:
//
//	Hello, <name>! Welcome to Go.
func Greet(name string) string {
	return fmt.Sprintf("Hello, %s! Welcome to Go.", name)
}

// FormatScore renders a name/score pair as one line of a fixed-width
// scoreboard: name left-aligned in 10 characters, '|', score
// right-aligned in 5 characters.
func FormatScore(name string, score int) string {
	// %-10s: the minus sign means left-align within the 10-char field.
	// %5d has no minus, so the number is right-aligned (the default).
	return fmt.Sprintf("%-10s|%5d", name, score)
}

// QuoteWords returns the three words, each wrapped in double quotes and
// escaped like a Go string literal, joined by ", ".
func QuoteWords(first, second, third string) string {
	// %q produces a Go-syntax quoted string: it adds the surrounding
	// quotes AND escapes anything inside that needs it.
	return fmt.Sprintf("%q, %q, %q", first, second, third)
}

// Banner returns text decorated as a one-line ASCII banner:
// "*** <text> ***".
func Banner(text string) string {
	return fmt.Sprintf("*** %s ***", text)
}

// TableRow formats one row of a results table as three aligned columns
// separated by '|': day (%-8s), stars (%4d), seconds (%8.2f).
func TableRow(day string, stars int, seconds float64) string {
	// %8.2f: width 8 for the whole number, exactly 2 digits after the
	// decimal point. fmt rounds (123.456 -> "123.46"), never truncates.
	return fmt.Sprintf("%-8s|%4d|%8.2f", day, stars, seconds)
}
