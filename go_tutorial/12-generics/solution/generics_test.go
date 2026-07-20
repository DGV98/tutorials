package generics

import (
	"slices"
	"strconv"
	"strings"
	"testing"
)

func TestMaxOf(t *testing.T) {
	t.Run("ints", func(t *testing.T) {
		tests := []struct {
			name string
			a, b int
			want int
		}{
			{"a larger", 9, 2, 9},
			{"b larger", 2, 9, 9},
			{"equal", 4, 4, 4},
			{"both negative", -3, -7, -3},
		}
		for _, tt := range tests {
			t.Run(tt.name, func(t *testing.T) {
				if got := MaxOf(tt.a, tt.b); got != tt.want {
					t.Errorf("MaxOf(%d, %d) = %d, want %d", tt.a, tt.b, got, tt.want)
				}
			})
		}
	})
	t.Run("strings", func(t *testing.T) {
		if got := MaxOf("apple", "pear"); got != "pear" {
			t.Errorf("MaxOf(%q, %q) = %q, want %q", "apple", "pear", got, "pear")
		}
	})
	t.Run("floats", func(t *testing.T) {
		if got := MaxOf(1.5, -2.5); got != 1.5 {
			t.Errorf("MaxOf(%v, %v) = %v, want %v", 1.5, -2.5, got, 1.5)
		}
	})
}

func TestMap(t *testing.T) {
	t.Run("int to string", func(t *testing.T) {
		xs := []int{1, 2, 3}
		got := Map(xs, strconv.Itoa)
		want := []string{"1", "2", "3"}
		if !slices.Equal(got, want) {
			t.Errorf("Map(%v, strconv.Itoa) = %v, want %v", xs, got, want)
		}
	})
	t.Run("double ints", func(t *testing.T) {
		xs := []int{2, 4, 8}
		got := Map(xs, func(x int) int { return x * 2 })
		want := []int{4, 8, 16}
		if !slices.Equal(got, want) {
			t.Errorf("Map(%v, double) = %v, want %v", xs, got, want)
		}
	})
	t.Run("string to length", func(t *testing.T) {
		xs := []string{"go", "gopher", ""}
		got := Map(xs, func(s string) int { return len(s) })
		want := []int{2, 6, 0}
		if !slices.Equal(got, want) {
			t.Errorf("Map(%q, len) = %v, want %v", xs, got, want)
		}
	})
	t.Run("empty", func(t *testing.T) {
		if got := Map(nil, strconv.Itoa); len(got) != 0 {
			t.Errorf("Map(nil, strconv.Itoa) = %v, want length 0", got)
		}
	})
	t.Run("does not modify input", func(t *testing.T) {
		xs := []int{1, 2, 3}
		Map(xs, func(x int) int { return -x })
		if want := []int{1, 2, 3}; !slices.Equal(xs, want) {
			t.Errorf("after Map, input xs = %v, want %v (unchanged)", xs, want)
		}
	})
}

func TestFilter(t *testing.T) {
	t.Run("keep evens", func(t *testing.T) {
		xs := []int{1, 2, 3, 4, 5, 6}
		got := Filter(xs, func(x int) bool { return x%2 == 0 })
		want := []int{2, 4, 6}
		if !slices.Equal(got, want) {
			t.Errorf("Filter(%v, even) = %v, want %v", xs, got, want)
		}
	})
	t.Run("keep long strings", func(t *testing.T) {
		xs := []string{"a", "abcd", "ab", "abcde"}
		got := Filter(xs, func(s string) bool { return len(s) > 3 })
		want := []string{"abcd", "abcde"}
		if !slices.Equal(got, want) {
			t.Errorf("Filter(%q, len>3) = %q, want %q", xs, got, want)
		}
	})
	t.Run("keep all", func(t *testing.T) {
		xs := []int{7, 8}
		got := Filter(xs, func(int) bool { return true })
		if !slices.Equal(got, xs) {
			t.Errorf("Filter(%v, always true) = %v, want %v", xs, got, xs)
		}
	})
	t.Run("keep none returns nil", func(t *testing.T) {
		xs := []int{1, 2, 3}
		if got := Filter(xs, func(int) bool { return false }); got != nil {
			t.Errorf("Filter(%v, always false) = %v, want nil", xs, got)
		}
	})
}

func TestReduce(t *testing.T) {
	t.Run("sum ints", func(t *testing.T) {
		xs := []int{1, 2, 3, 4}
		got := Reduce(xs, 0, func(acc, x int) int { return acc + x })
		if want := 10; got != want {
			t.Errorf("Reduce(%v, 0, add) = %d, want %d", xs, got, want)
		}
	})
	t.Run("join strings", func(t *testing.T) {
		xs := []string{"a", "b", "c"}
		got := Reduce(xs, "", func(acc, s string) string { return acc + s })
		if want := "abc"; got != want {
			t.Errorf("Reduce(%q, %q, concat) = %q, want %q", xs, "", got, want)
		}
	})
	t.Run("fold strings into int", func(t *testing.T) {
		xs := []string{"go", "is", "fun"}
		got := Reduce(xs, 0, func(acc int, s string) int { return acc + len(s) })
		if want := 7; got != want {
			t.Errorf("Reduce(%q, 0, total length) = %d, want %d", xs, got, want)
		}
	})
	t.Run("empty returns initial", func(t *testing.T) {
		got := Reduce(nil, 42, func(acc, x int) int { return acc + x })
		if want := 42; got != want {
			t.Errorf("Reduce(nil, 42, add) = %d, want %d", got, want)
		}
	})
}

func TestKeys(t *testing.T) {
	t.Run("string keys", func(t *testing.T) {
		m := map[string]int{"a": 1, "b": 2, "c": 3}
		got := Keys(m)
		slices.Sort(got)
		want := []string{"a", "b", "c"}
		if !slices.Equal(got, want) {
			t.Errorf("Keys(%v) = %v (after sorting), want %v", m, got, want)
		}
	})
	t.Run("int keys", func(t *testing.T) {
		m := map[int]string{10: "x", 5: "y"}
		got := Keys(m)
		slices.Sort(got)
		want := []int{5, 10}
		if !slices.Equal(got, want) {
			t.Errorf("Keys(%v) = %v (after sorting), want %v", m, got, want)
		}
	})
	t.Run("empty map", func(t *testing.T) {
		if got := Keys(map[string]bool{}); len(got) != 0 {
			t.Errorf("Keys(map[string]bool{}) = %v, want length 0", got)
		}
	})
}

func TestContains(t *testing.T) {
	t.Run("ints", func(t *testing.T) {
		tests := []struct {
			name   string
			xs     []int
			target int
			want   bool
		}{
			{"present in middle", []int{1, 2, 3}, 2, true},
			{"present at end", []int{1, 2, 3}, 3, true},
			{"absent", []int{1, 2, 3}, 4, false},
			{"empty", nil, 1, false},
		}
		for _, tt := range tests {
			t.Run(tt.name, func(t *testing.T) {
				if got := Contains(tt.xs, tt.target); got != tt.want {
					t.Errorf("Contains(%v, %d) = %t, want %t", tt.xs, tt.target, got, tt.want)
				}
			})
		}
	})
	t.Run("strings", func(t *testing.T) {
		xs := strings.Fields("the quick brown fox")
		if got := Contains(xs, "quick"); !got {
			t.Errorf("Contains(%q, %q) = %t, want true", xs, "quick", got)
		}
		if got := Contains(xs, "slow"); got {
			t.Errorf("Contains(%q, %q) = %t, want false", xs, "slow", got)
		}
	})
}

func TestSumNumbers(t *testing.T) {
	t.Run("ints", func(t *testing.T) {
		xs := []int{1, 2, 3}
		if got := SumNumbers(xs); got != 6 {
			t.Errorf("SumNumbers(%v) = %d, want 6", xs, got)
		}
	})
	t.Run("int64s", func(t *testing.T) {
		xs := []int64{1 << 40, 1 << 40}
		if got, want := SumNumbers(xs), int64(1<<41); got != want {
			t.Errorf("SumNumbers(%v) = %d, want %d", xs, got, want)
		}
	})
	t.Run("floats", func(t *testing.T) {
		xs := []float64{1.5, 2.25}
		if got, want := SumNumbers(xs), 3.75; got != want {
			t.Errorf("SumNumbers(%v) = %v, want %v", xs, got, want)
		}
	})
	t.Run("named type via tilde", func(t *testing.T) {
		// fuel's underlying type is int, so ~int in the Number
		// constraint admits it.
		type fuel int
		xs := []fuel{3, 5}
		if got := SumNumbers(xs); got != 8 {
			t.Errorf("SumNumbers(%v) = %d, want 8", xs, got)
		}
	})
	t.Run("empty", func(t *testing.T) {
		if got := SumNumbers([]int(nil)); got != 0 {
			t.Errorf("SumNumbers(nil) = %d, want 0", got)
		}
	})
}
