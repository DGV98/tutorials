// Package values is module 02 of the course: variables, basic types,
// zero values, explicit conversions, constants and iota.
package values

// CelsiusToFahrenheit converts a temperature in degrees Celsius to degrees
// Fahrenheit using the formula F = C*9/5 + 32.
//
// It must work for any float64 input, including negative temperatures:
// CelsiusToFahrenheit(-40) returns -40.
func CelsiusToFahrenheit(c float64) float64 {
	// TODO: implement
	return 0
}

// SafeAverage returns the arithmetic mean of a and b as a float64,
// preserving the fractional part: SafeAverage(1, 2) returns 1.5.
//
// The result must be correct even when a+b would overflow int:
// SafeAverage(math.MaxInt, math.MaxInt) must return float64(math.MaxInt).
// Hint: Go never converts numeric types implicitly, and WHERE you put the
// explicit conversions decides whether the intermediate sum overflows.
func SafeAverage(a, b int) float64 {
	// TODO: implement
	return 0
}
