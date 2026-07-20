package values

// ZeroValueReport returns a one-line description of the zero values of
// Go's most common basic types, in exactly this format:
//
//	int=0 float64=0 string="" bool=false
//
// Build the string with fmt.Sprintf from freshly declared, uninitialized
// variables (var i int, and so on) — don't hard-code the literal. The
// point is to watch real zero values come out of real variables. Use the
// %v verb for the numbers and the bool, and %q for the string so its
// quotes appear in the output.
func ZeroValueReport() string {
	// TODO: implement
	return ""
}
