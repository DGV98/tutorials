package interfaces

import "fmt"

// Describe returns a one-line description of the dynamic type and
// value inside v. See the exercise file for the exact formats.
func Describe(v any) string {
	// switch x := v.(type) binds x to the matched type inside each
	// case: x is a bool in the bool case, an int in the int case, and
	// so on — no separate assertion needed.
	switch x := v.(type) {
	case nil:
		return "nil"
	case bool:
		return fmt.Sprintf("bool %t", x)
	case int:
		return fmt.Sprintf("int %d", x)
	case float64:
		return fmt.Sprintf("float64 %g", x)
	case string:
		return fmt.Sprintf("string %q", x)
	case []int:
		return fmt.Sprintf("[]int of length %d", len(x))
	case fmt.Stringer:
		// An interface case matches any dynamic type that satisfies
		// it. Cases are tried top to bottom, so it sits below the
		// concrete cases: a concrete match should win.
		return fmt.Sprintf("stringer %s", x)
	default:
		return fmt.Sprintf("unknown type %T", x)
	}
}

// SumNumeric returns the sum, as a float64, of every element of vals
// whose dynamic type is exactly int or float64. Everything else —
// strings, bools, nil, and even other numeric types such as int64 or
// float32 — is silently skipped.
//
// An empty or nil slice sums to 0.
func SumNumeric(vals []any) float64 {
	var sum float64
	for _, v := range vals {
		switch x := v.(type) {
		case int:
			sum += float64(x)
		case float64:
			sum += x
		}
		// No default: anything else is simply skipped.
	}
	return sum
}
