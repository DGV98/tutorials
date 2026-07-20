// Package controlflow contains the reference solutions for module
// 03-control-flow.
package controlflow

import "strconv"

// FizzBuzz returns the classic FizzBuzz sequence for the numbers 1 through n,
// in order: "FizzBuzz" for multiples of both 3 and 5, "Fizz" for multiples of
// 3 only, "Buzz" for multiples of 5 only, and the decimal string of the
// number otherwise. If n <= 0, FizzBuzz returns an empty (possibly nil)
// slice.
func FizzBuzz(n int) []string {
	var out []string
	for i := 1; i <= n; i++ {
		// A condition-less switch reads better than an if/else if
		// chain. The i%15 case must come first: a multiple of 15 also
		// matches the i%3 case, and the first true case wins.
		switch {
		case i%15 == 0:
			out = append(out, "FizzBuzz")
		case i%3 == 0:
			out = append(out, "Fizz")
		case i%5 == 0:
			out = append(out, "Buzz")
		default:
			out = append(out, strconv.Itoa(i))
		}
	}
	return out
}

// CollatzSteps returns the number of steps the Collatz process takes to reach
// 1 starting from n: at each step an even number is halved and an odd number
// becomes 3n+1. CollatzSteps(1) is 0. For n < 1 it returns -1.
func CollatzSteps(n int) int {
	if n < 1 {
		return -1
	}
	steps := 0
	for n != 1 { // while-style for: loop until the process reaches 1
		if n%2 == 0 {
			n /= 2
		} else {
			n = 3*n + 1
		}
		steps++
	}
	return steps
}

// IsPrime reports whether n is a prime number. Numbers below 2 are not
// prime.
func IsPrime(n int) bool {
	if n < 2 {
		return false
	}
	// Trial division: a composite n has a divisor no larger than sqrt(n),
	// so d*d <= n is enough. Comparing d*d avoids floating point.
	for d := 2; d*d <= n; d++ {
		if n%d == 0 {
			return false
		}
	}
	return true
}

// LetterGrade converts a numeric score to a letter grade: 90+ is an "A",
// 80-89 a "B", 70-79 a "C", 60-69 a "D", and anything below 60 an "F".
func LetterGrade(score int) string {
	// switch with no condition means switch true: the first case whose
	// expression is true runs. Ordering the cases from highest cutoff to
	// lowest keeps each one a single comparison.
	switch {
	case score >= 90:
		return "A"
	case score >= 80:
		return "B"
	case score >= 70:
		return "C"
	case score >= 60:
		return "D"
	default:
		return "F"
	}
}

// FirstDivisor returns the smallest divisor of n that is greater than 1, or
// n itself when n is prime. For n < 2 it returns 0.
func FirstDivisor(n int) int {
	if n < 2 {
		return 0
	}
	for d := 2; d*d <= n; d++ {
		if n%d == 0 {
			return d
		}
	}
	// No divisor up to sqrt(n) means n is prime, so its smallest divisor
	// greater than 1 is n itself.
	return n
}

// SumOfMultiples returns the sum of every positive integer below limit that
// is divisible by at least one of the given divisors, counting each number
// once. Divisors that are zero or negative are ignored.
func SumOfMultiples(limit int, divisors ...int) int {
	sum := 0
	// range over an integer: n runs 0, 1, ..., limit-1, and the loop body
	// never runs when limit <= 0. n == 0 matches every divisor but adds
	// nothing to the sum, so it needs no special case.
	for n := range limit {
		for _, d := range divisors {
			if d > 0 && n%d == 0 {
				sum += n
				break // count n once even if several divisors match
			}
		}
	}
	return sum
}
