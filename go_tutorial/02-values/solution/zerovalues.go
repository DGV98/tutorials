package values

import "fmt"

// ZeroValueReport returns a one-line description of the zero values of
// Go's most common basic types, in exactly this format:
//
//	int=0 float64=0 string="" bool=false
//
// Each value comes from a freshly declared, uninitialized variable — this
// is the whole point of the exercise: in Go there is no "uninitialized
// garbage", declaration alone gives you a usable value.
func ZeroValueReport() string {
	var (
		i int
		f float64
		s string
		b bool
	)
	// %v prints each value in its natural form; %q wraps the string in
	// quotes so an empty string is visible as "".
	return fmt.Sprintf("int=%v float64=%v string=%q bool=%v", i, f, s, b)
}
