package values

import (
	"math"
	"testing"
)

func TestCelsiusToFahrenheit(t *testing.T) {
	// Every expected value here is exactly representable in float64,
	// so plain == comparison is safe (no epsilon needed).
	tests := []struct {
		name string
		c    float64
		want float64
	}{
		{"freezing point", 0, 32},
		{"boiling point", 100, 212},
		{"warm day", 25, 77},
		{"where the scales meet", -40, -40},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := CelsiusToFahrenheit(tt.c); got != tt.want {
				t.Errorf("CelsiusToFahrenheit(%v) = %v, want %v", tt.c, got, tt.want)
			}
		})
	}
}

func TestSafeAverage(t *testing.T) {
	tests := []struct {
		name string
		a, b int
		want float64
	}{
		{"fractional result", 1, 2, 1.5},
		{"mixed signs", -3, 2, -0.5},
		{"both negative", -5, -10, -7.5},
		{"a+b would overflow int", math.MaxInt, math.MaxInt, float64(math.MaxInt)},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := SafeAverage(tt.a, tt.b); got != tt.want {
				t.Errorf("SafeAverage(%d, %d) = %v, want %v", tt.a, tt.b, got, tt.want)
			}
		})
	}
}
