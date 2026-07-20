package values

// DigitSum returns the sum of the decimal digits of n.
// n is guaranteed to be non-negative.
//
// DigitSum(0) returns 0; DigitSum(12345) returns 15.
func DigitSum(n int) int {
	// TODO: implement
	return 0
}

// LastNDigits returns the number formed by the last n decimal digits of x,
// i.e. x modulo 10^n. x is non-negative and 1 <= n <= 18.
//
// If x has fewer than n digits the result is x itself:
// LastNDigits(42, 5) returns 42. Leading zeros disappear because the
// result is a number, not a string: LastNDigits(105, 2) returns 5.
func LastNDigits(x, n int) int {
	// TODO: implement
	return 0
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
	// TODO: implement
	return 0, 0, 0
}
