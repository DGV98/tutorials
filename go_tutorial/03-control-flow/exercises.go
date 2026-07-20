// Package controlflow contains the exercises for module 03-control-flow:
// if/else, every shape of for, and switch.
package controlflow

// FizzBuzz returns the classic FizzBuzz sequence for the numbers 1 through n,
// in order. Element i (0-indexed) describes the number i+1:
//
//   - "FizzBuzz" if it is divisible by both 3 and 5,
//   - "Fizz" if it is divisible by 3 only,
//   - "Buzz" if it is divisible by 5 only,
//   - the number itself in decimal (e.g. "7") otherwise.
//
// If n <= 0, FizzBuzz returns an empty (possibly nil) slice.
//
// Hint: strconv.Itoa converts an int to its decimal string, and
// out = append(out, s) grows a slice (slices get a full lesson in module 05).
func FizzBuzz(n int) []string {
	// TODO: implement
	return nil
}

// CollatzSteps returns the number of steps the Collatz process takes to reach
// 1 starting from n: at each step an even number is halved and an odd number
// becomes 3n+1. CollatzSteps(1) is 0 because it is already there.
//
// The process is only defined for n >= 1; for anything smaller CollatzSteps
// returns -1.
func CollatzSteps(n int) int {
	// TODO: implement
	return 0
}

// IsPrime reports whether n is a prime number. Numbers below 2 — including
// 0, 1, and all negatives — are not prime.
//
// Hint: trial division is plenty here, and you only need to try divisors d
// while d*d <= n.
func IsPrime(n int) bool {
	// TODO: implement
	return false
}

// LetterGrade converts a numeric score to a letter grade:
//
//	90 and above   "A"
//	80 to 89       "B"
//	70 to 79       "C"
//	60 to 69       "D"
//	below 60       "F"
//
// Scores outside 0..100 still follow the table: 105 is an "A" and -3 is an
// "F". Implement it with a condition-less switch rather than an if/else
// chain — that is the point of this exercise.
func LetterGrade(score int) string {
	// TODO: implement
	return ""
}

// FirstDivisor returns the smallest divisor of n that is greater than 1.
// When n is prime, that divisor is n itself. For n < 2 no such divisor
// exists and FirstDivisor returns 0.
//
// Hint: as with IsPrime, you only need to try candidates d while d*d <= n.
// If none of them divides n, n is prime — what does that tell you about the
// answer?
func FirstDivisor(n int) int {
	// TODO: implement
	return 0
}

// SumOfMultiples returns the sum of every positive integer below limit that
// is divisible by at least one of the given divisors. Each qualifying number
// is counted exactly once, even if several divisors divide it.
//
// Divisors that are zero or negative are ignored (this also protects you
// from dividing by zero). With no usable divisors, or with limit <= 1, the
// sum is 0.
//
// SumOfMultiples(10, 3, 5) == 23, because 3 + 5 + 6 + 9 == 23.
//
// The ...int makes divisors variadic: callers pass any number of ints, and
// inside the function divisors behaves like a []int you can loop over with
// range (variadic functions are covered properly in module 04).
func SumOfMultiples(limit int, divisors ...int) int {
	// TODO: implement
	return 0
}
