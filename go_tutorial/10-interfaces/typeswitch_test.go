package interfaces

import "testing"

// greeting is a fmt.Stringer defined just for these tests — Describe
// must recognize it through the interface, not by concrete type.
type greeting struct{}

func (greeting) String() string { return "hello" }

func TestDescribe(t *testing.T) {
	tests := []struct {
		name string
		v    any
		want string
	}{
		{"nil", nil, "nil"},
		{"bool", true, "bool true"},
		{"int", 42, "int 42"},
		{"negative int", -7, "int -7"},
		{"float64", 2.5, "float64 2.5"},
		{"string", "hi", `string "hi"`},
		{"int slice", []int{1, 2, 3}, "[]int of length 3"},
		{"empty int slice", []int{}, "[]int of length 0"},
		{"stringer", greeting{}, "stringer hello"},
		{"unknown int64", int64(7), "unknown type int64"},
		{"unknown struct", struct{}{}, "unknown type struct {}"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := Describe(tt.v); got != tt.want {
				t.Errorf("Describe(%#v) = %q, want %q", tt.v, got, tt.want)
			}
		})
	}
}

func TestSumNumeric(t *testing.T) {
	tests := []struct {
		name string
		vals []any
		want float64
	}{
		{"nil slice", nil, 0},
		{"ints only", []any{1, 2, 3}, 6},
		{"floats only", []any{1.5, 2.5}, 4},
		{"mixed numerics", []any{1, 2.5}, 3.5},
		{"skips non-numbers", []any{1, "two", 3.0, true, nil}, 4},
		{"skips other numeric types", []any{int64(5), float32(2), 10}, 10},
		{"nothing numeric", []any{"a", false}, 0},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := SumNumeric(tt.vals); !almostEqual(got, tt.want) {
				t.Errorf("SumNumeric(%v) = %v, want %v", tt.vals, got, tt.want)
			}
		})
	}
}
