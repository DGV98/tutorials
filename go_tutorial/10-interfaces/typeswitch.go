package interfaces

// Describe returns a one-line description of the dynamic type and
// value inside v. Implement it with a single type switch producing
// exactly these formats:
//
//	Describe(nil)           == "nil"
//	Describe(true)          == "bool true"          (%t)
//	Describe(42)            == "int 42"             (%d)
//	Describe(2.5)           == "float64 2.5"        (%g)
//	Describe("hi")          == `string "hi"`        (%q)
//	Describe([]int{1, 2})   == "[]int of length 2"
//	Describe(x)             == "stringer hello"     for any fmt.Stringer
//	                           whose String() returns "hello" (%s)
//	Describe(int64(7))      == "unknown type int64" (%T)
//
// Only those exact types match their case: an int64 or float32 is not
// an int or a float64, so it falls through to the default. A type
// switch tries its cases top to bottom, so keep the fmt.Stringer case
// after the concrete ones and use default for everything else.
func Describe(v any) string {
	// TODO: implement
	return ""
}

// SumNumeric returns the sum, as a float64, of every element of vals
// whose dynamic type is exactly int or float64. Everything else —
// strings, bools, nil, and even other numeric types such as int64 or
// float32 — is silently skipped.
//
// An empty or nil slice sums to 0.
func SumNumeric(vals []any) float64 {
	// TODO: implement
	return 0
}
