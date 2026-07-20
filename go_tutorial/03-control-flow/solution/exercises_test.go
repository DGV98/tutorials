package controlflow

import (
	"slices"
	"testing"
)

func TestFizzBuzz(t *testing.T) {
	tests := []struct {
		name string
		n    int
		want []string
	}{
		{"zero gives empty", 0, nil},
		{"negative gives empty", -3, nil},
		{"one", 1, []string{"1"}},
		{"ends with Fizz", 3, []string{"1", "2", "Fizz"}},
		{"ends with Buzz", 5, []string{"1", "2", "Fizz", "4", "Buzz"}},
		{"full round to FizzBuzz", 15, []string{
			"1", "2", "Fizz", "4", "Buzz", "Fizz", "7", "8", "Fizz", "Buzz",
			"11", "Fizz", "13", "14", "FizzBuzz",
		}},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := FizzBuzz(tt.n)
			if !slices.Equal(got, tt.want) {
				t.Errorf("FizzBuzz(%d) = %q, want %q", tt.n, got, tt.want)
			}
		})
	}
}

func TestCollatzSteps(t *testing.T) {
	tests := []struct {
		name string
		n    int
		want int
	}{
		{"one is already there", 1, 0},
		{"two halves once", 2, 1},
		{"three takes the odd branch", 3, 7},
		{"six", 6, 8},
		{"seven", 7, 16},
		{"twenty-seven is famously slow", 27, 111},
		{"zero is undefined", 0, -1},
		{"negative is undefined", -5, -1},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := CollatzSteps(tt.n)
			if got != tt.want {
				t.Errorf("CollatzSteps(%d) = %d, want %d", tt.n, got, tt.want)
			}
		})
	}
}

func TestIsPrime(t *testing.T) {
	tests := []struct {
		name string
		n    int
		want bool
	}{
		{"zero", 0, false},
		{"one", 1, false},
		{"two, the only even prime", 2, true},
		{"three", 3, true},
		{"four", 4, false},
		{"nine, odd but composite", 9, false},
		{"seventeen", 17, true},
		{"twenty-five, square of a prime", 25, false},
		{"the thousandth prime", 7919, true},
		{"negative", -7, false},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := IsPrime(tt.n)
			if got != tt.want {
				t.Errorf("IsPrime(%d) = %t, want %t", tt.n, got, tt.want)
			}
		})
	}
}

func TestLetterGrade(t *testing.T) {
	tests := []struct {
		name  string
		score int
		want  string
	}{
		{"perfect score", 100, "A"},
		{"bottom of the A range", 90, "A"},
		{"top of the B range", 89, "B"},
		{"bottom of the B range", 80, "B"},
		{"middle C", 75, "C"},
		{"bottom of the C range", 70, "C"},
		{"top of the D range", 69, "D"},
		{"bottom of the D range", 60, "D"},
		{"just failing", 59, "F"},
		{"zero", 0, "F"},
		{"negative is still an F", -10, "F"},
		{"extra credit is still an A", 105, "A"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := LetterGrade(tt.score)
			if got != tt.want {
				t.Errorf("LetterGrade(%d) = %q, want %q", tt.score, got, tt.want)
			}
		})
	}
}

func TestFirstDivisor(t *testing.T) {
	tests := []struct {
		name string
		n    int
		want int
	}{
		{"smallest prime", 2, 2},
		{"prime returns itself", 3, 3},
		{"even composite", 4, 2},
		{"odd composite", 9, 3},
		{"fifteen", 15, 3},
		{"square above the small primes", 49, 7},
		{"semiprime 7 times 13", 91, 7},
		{"large prime returns itself", 97, 97},
		{"one has no divisor above one", 1, 0},
		{"zero has no divisor above one", 0, 0},
		{"negatives have no divisor above one", -4, 0},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := FirstDivisor(tt.n)
			if got != tt.want {
				t.Errorf("FirstDivisor(%d) = %d, want %d", tt.n, got, tt.want)
			}
		})
	}
}

func TestSumOfMultiples(t *testing.T) {
	tests := []struct {
		name     string
		limit    int
		divisors []int
		want     int
	}{
		{"classic 3 and 5 below 10", 10, []int{3, 5}, 23},
		{"project euler problem 1", 1000, []int{3, 5}, 233168},
		{"single divisor", 20, []int{7}, 21},
		{"overlapping divisors count once", 16, []int{4, 2}, 56},
		{"divisor one sums everything", 10, []int{1}, 45},
		{"no divisors", 10, []int{}, 0},
		{"zero divisor is ignored", 10, []int{0}, 0},
		{"negative divisor is ignored", 10, []int{-3, 5}, 5},
		{"limit zero", 0, []int{3, 5}, 0},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := SumOfMultiples(tt.limit, tt.divisors...)
			if got != tt.want {
				t.Errorf("SumOfMultiples(%d, %v) = %d, want %d", tt.limit, tt.divisors, got, tt.want)
			}
		})
	}
}
