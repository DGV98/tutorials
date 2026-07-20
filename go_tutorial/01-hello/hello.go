// Package hello is module 1 of the course: the Go toolchain and string
// formatting with the fmt package.
//
// Implement each function below using fmt.Sprintf (plain string
// concatenation with + is fine too where it reads better). Check your
// work from the repository root with:
//
//	go test ./01-hello/
package hello

// Greet returns a greeting for name, in exactly this form:
//
//	Hello, <name>! Welcome to Go.
//
// For example, Greet("Gopher") returns "Hello, Gopher! Welcome to Go.".
// An empty name is not special-cased: Greet("") returns
// "Hello, ! Welcome to Go.".
func Greet(name string) string {
	// TODO: implement
	return ""
}

// FormatScore renders a name/score pair as one line of a fixed-width
// scoreboard: the name left-aligned in a 10-character field, then a '|',
// then the score right-aligned in a 5-character field.
//
//	FormatScore("Alice", 42) == "Alice     |   42"
//
// Widths are minimums, not limits: a name longer than 10 characters or a
// score wider than 5 digits is never truncated — its field simply grows.
func FormatScore(name string, score int) string {
	// TODO: implement
	return ""
}

// QuoteWords returns the three words, each wrapped in double quotes,
// joined by ", ":
//
//	QuoteWords("go", "is", "fun") == `"go", "is", "fun"`
//
// The quoting must escape special characters the way Go source code
// would (the %q verb does all of this for you). For example, a double
// quote inside a word comes out backslash-escaped:
// QuoteWords(`say "hi"`, "to", "them") begins with `"say \"hi\""`.
// An empty word still gets its quotes: "".
func QuoteWords(first, second, third string) string {
	// TODO: implement
	return ""
}

// Banner returns text decorated as a one-line ASCII banner: three
// asterisks, a space, the text, a space, three asterisks.
//
//	Banner("Advent of Code") == "*** Advent of Code ***"
//
// Empty text keeps both spaces: Banner("") == "***  ***".
func Banner(text string) string {
	// TODO: implement
	return ""
}

// TableRow formats one row of a results table as three aligned columns
// separated by '|': day left-aligned in an 8-character field, stars
// right-aligned in a 4-character field, and seconds right-aligned in an
// 8-character field with exactly two digits after the decimal point.
//
//	TableRow("Day 1", 2, 0.5) == "Day 1   |   2|    0.50"
//
// The seconds value is rounded, not truncated: 123.456 renders as
// "123.46". As with FormatScore, field widths are minimums.
func TableRow(day string, stars int, seconds float64) string {
	// TODO: implement
	return ""
}
