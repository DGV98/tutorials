package hello

// These tests use a few Go features you haven't met yet (the for-range
// loop, slices, and struct types — modules 03, 05, and 09). You don't
// need to understand the plumbing; each table lists inputs and the exact
// expected output, and that is the contract your code must meet.

import "testing"

func TestGreet(t *testing.T) {
	tests := []struct {
		name string
		in   string
		want string
	}{
		{"simple name", "Gopher", "Hello, Gopher! Welcome to Go."},
		{"name with a space", "Ada Lovelace", "Hello, Ada Lovelace! Welcome to Go."},
		{"empty name is not special-cased", "", "Hello, ! Welcome to Go."},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := Greet(tt.in); got != tt.want {
				t.Errorf("Greet(%q) = %q, want %q", tt.in, got, tt.want)
			}
		})
	}
}

func TestFormatScore(t *testing.T) {
	tests := []struct {
		name  string
		who   string
		score int
		want  string
	}{
		{"short name, two-digit score", "Alice", 42, "Alice     |   42"},
		{"tiny name and score", "Bo", 7, "Bo        |    7"},
		{"name longer than its field grows", "Bartholomew", 100, "Bartholomew|  100"},
		{"negative score", "Eve", -3, "Eve       |   -3"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := FormatScore(tt.who, tt.score); got != tt.want {
				t.Errorf("FormatScore(%q, %d) = %q, want %q", tt.who, tt.score, got, tt.want)
			}
		})
	}
}

func TestQuoteWords(t *testing.T) {
	tests := []struct {
		name                 string
		first, second, third string
		want                 string
	}{
		{"plain words", "go", "is", "fun", `"go", "is", "fun"`},
		{"embedded quotes are escaped", `say "hi"`, "to", "them", `"say \"hi\"", "to", "them"`},
		{"empty word still gets quotes", "", "b", "c", `"", "b", "c"`},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := QuoteWords(tt.first, tt.second, tt.third)
			if got != tt.want {
				t.Errorf("QuoteWords(%q, %q, %q) = %q, want %q",
					tt.first, tt.second, tt.third, got, tt.want)
			}
		})
	}
}

func TestBanner(t *testing.T) {
	tests := []struct {
		name string
		in   string
		want string
	}{
		{"phrase", "Advent of Code", "*** Advent of Code ***"},
		{"single word", "GO", "*** GO ***"},
		{"empty text keeps both spaces", "", "***  ***"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := Banner(tt.in); got != tt.want {
				t.Errorf("Banner(%q) = %q, want %q", tt.in, got, tt.want)
			}
		})
	}
}

func TestTableRow(t *testing.T) {
	tests := []struct {
		name    string
		day     string
		stars   int
		seconds float64
		want    string
	}{
		{"day one", "Day 1", 2, 0.5, "Day 1   |   2|    0.50"},
		{"rounds, does not truncate", "Day 25", 50, 123.456, "Day 25  |  50|  123.46"},
		{"whole number gains decimals", "Total", 500, 3, "Total   | 500|    3.00"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := TableRow(tt.day, tt.stars, tt.seconds)
			if got != tt.want {
				t.Errorf("TableRow(%q, %d, %v) = %q, want %q",
					tt.day, tt.stars, tt.seconds, got, tt.want)
			}
		})
	}
}
