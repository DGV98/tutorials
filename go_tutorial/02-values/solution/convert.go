// Package values contains the reference solutions for module 02:
// variables, basic types, zero values, explicit conversions, constants
// and iota.
package values

// CelsiusToFahrenheit converts a temperature in degrees Celsius to degrees
// Fahrenheit using the formula F = C*9/5 + 32.
//
// It must work for any float64 input, including negative temperatures:
// CelsiusToFahrenheit(-40) returns -40.
func CelsiusToFahrenheit(c float64) float64 {
	// 9, 5 and 32 are untyped constants, so they quietly take on float64
	// here. Note the evaluation order: (c*9)/5 does float division.
	// Writing c*(9/5) would be a bug — 9/5 is *integer* constant division,
	// which is 1.
	return c*9/5 + 32
}

// SafeAverage returns the arithmetic mean of a and b as a float64,
// preserving the fractional part: SafeAverage(1, 2) returns 1.5.
//
// The result must be correct even when a+b would overflow int:
// SafeAverage(math.MaxInt, math.MaxInt) must return float64(math.MaxInt).
func SafeAverage(a, b int) float64 {
	// Convert each operand *before* adding: float64(a+b) would compute
	// a+b in int first, and overflow for large inputs.
	return (float64(a) + float64(b)) / 2
}
