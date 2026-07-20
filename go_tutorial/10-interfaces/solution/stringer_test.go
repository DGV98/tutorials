package interfaces

import (
	"fmt"
	"testing"
)

func TestTemperatureString(t *testing.T) {
	tests := []struct {
		name string
		temp Temperature
		want string
	}{
		{"positive", 23.5, "23.5°C"},
		{"negative", -40, "-40.0°C"},
		{"zero", 0, "0.0°C"},
		{"rounded to one decimal", 21.26, "21.3°C"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := tt.temp.String(); got != tt.want {
				t.Errorf("Temperature(%v).String() = %q, want %q",
					float64(tt.temp), got, tt.want)
			}
		})
	}
}

func TestTemperatureSatisfiesStringer(t *testing.T) {
	// fmt never heard of Temperature, yet %v picks up the String
	// method: fmt checks — at runtime, with a type assertion — whether
	// each value it prints satisfies fmt.Stringer.
	var _ fmt.Stringer = Temperature(0) // compile-time proof it satisfies

	got := fmt.Sprintf("current: %v", Temperature(18.5))
	want := "current: 18.5°C"
	if got != want {
		t.Errorf("fmt.Sprintf(%%v, Temperature(18.5)) = %q, want %q", got, want)
	}
}
