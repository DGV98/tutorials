package interfaces

// Temperature is a temperature in degrees Celsius. It is a named type
// whose underlying type is float64 (module 09), which means it can
// carry methods.
type Temperature float64

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
//
// Careful: inside String, formatting t itself with %v or %s calls
// String again, recursing forever. Convert first:
// fmt.Sprintf("%.1f°C", float64(t)).
func (t Temperature) String() string {
	// TODO: implement
	return ""
}
