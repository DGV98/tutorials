package interfaces

import "fmt"

// Temperature is a temperature in degrees Celsius. It is a named type
// whose underlying type is float64 (module 09), which means it can
// carry methods.
type Temperature float64

// Compile-time proof that Temperature satisfies fmt.Stringer.
var _ fmt.Stringer = Temperature(0)

// String formats the temperature with exactly one decimal place
// followed by "°C":
//
//	Temperature(23.5).String() == "23.5°C"
//	Temperature(-40).String() == "-40.0°C"
//	Temperature(0).String() == "0.0°C"
//
// This method makes Temperature satisfy fmt.Stringer, so every fmt
// verb that prints values — %v, %s, Println, ... — will use it
// automatically.
func (t Temperature) String() string {
	// The float64 conversion matters: formatting t itself with %v or
	// %s would call String again and recurse forever.
	return fmt.Sprintf("%.1f°C", float64(t))
}
