package values

// DigitSum returns the sum of the decimal digits of n.
// n is guaranteed to be non-negative.
//
// DigitSum(0) returns 0; DigitSum(12345) returns 15.
func DigitSum(n int) int {
	sum := 0
	for n > 0 {
		sum += n % 10 // peel off the last digit...
		n /= 10       // ...then drop it
	}
	return sum
}

// LastNDigits returns the number formed by the last n decimal digits of x,
// i.e. x modulo 10^n. x is non-negative and 1 <= n <= 18.
//
// If x has fewer than n digits the result is x itself:
// LastNDigits(42, 5) returns 42. Leading zeros disappear because the
// result is a number, not a string: LastNDigits(105, 2) returns 5.
func LastNDigits(x, n int) int {
	// Build 10^n with integer arithmetic. math.Pow works on float64 and
	// would force conversions (and rounding risk) for no benefit.
	// 10^18 still fits in an int64, so n <= 18 is safe.
	pow := 1
	for range n { // "repeat n times" — range over an int, Go 1.22+
		pow *= 10
	}
	return x % pow
}

// SplitDuration breaks a duration given in whole seconds into hours,
// minutes and seconds, such that
//
//	totalSeconds == h*3600 + m*60 + s
//
// with 0 <= m < 60 and 0 <= s < 60. totalSeconds is non-negative.
//
// SplitDuration(3661) returns (1, 1, 1).
func SplitDuration(totalSeconds int) (h, m, s int) {
	h = totalSeconds / 3600
	m = totalSeconds % 3600 / 60 // % and / have equal precedence: left to right
	s = totalSeconds % 60
	return h, m, s
}
