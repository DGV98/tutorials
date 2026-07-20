package slicing

import (
	"reflect"
	"slices"
	"testing"
)

func TestSum(t *testing.T) {
	tests := []struct {
		name string
		xs   []int
		want int
	}{
		{"empty", nil, 0},
		{"single", []int{7}, 7},
		{"several", []int{1, 2, 3, 4}, 10},
		{"negatives", []int{-5, 5, -1}, -1},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := Sum(tt.xs); got != tt.want {
				t.Errorf("Sum(%v) = %d, want %d", tt.xs, got, tt.want)
			}
		})
	}
}

func TestMax(t *testing.T) {
	tests := []struct {
		name   string
		xs     []int
		want   int
		wantOK bool
	}{
		{"empty", nil, 0, false},
		{"single", []int{3}, 3, true},
		{"max at end", []int{1, 2, 9}, 9, true},
		{"max at start", []int{9, 2, 1}, 9, true},
		{"all negative", []int{-3, -1, -7}, -1, true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, ok := Max(tt.xs)
			if got != tt.want || ok != tt.wantOK {
				t.Errorf("Max(%v) = (%d, %t), want (%d, %t)",
					tt.xs, got, ok, tt.want, tt.wantOK)
			}
		})
	}
}

func TestReverseInPlace(t *testing.T) {
	tests := []struct {
		name string
		xs   []int
		want []int
	}{
		{"empty", nil, nil},
		{"single", []int{1}, []int{1}},
		{"even length", []int{1, 2, 3, 4}, []int{4, 3, 2, 1}},
		{"odd length", []int{1, 2, 3}, []int{3, 2, 1}},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := slices.Clone(tt.xs)
			ReverseInPlace(got)
			if !slices.Equal(got, tt.want) {
				t.Errorf("ReverseInPlace(%v) = %v, want %v", tt.xs, got, tt.want)
			}
		})
	}
}

func TestFilter(t *testing.T) {
	isEven := func(x int) bool { return x%2 == 0 }
	isPositive := func(x int) bool { return x > 0 }

	tests := []struct {
		name string
		xs   []int
		keep func(int) bool
		want []int
	}{
		{"keep evens", []int{1, 2, 3, 4, 5, 6}, isEven, []int{2, 4, 6}},
		{"keep positives", []int{-2, 3, 0, 7}, isPositive, []int{3, 7}},
		{"keep everything", []int{2, 4}, isEven, []int{2, 4}},
		{"keep nothing", []int{1, 3, 5}, isEven, nil},
		{"empty input", nil, isEven, nil},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := Filter(tt.xs, tt.keep)
			if !slices.Equal(got, tt.want) {
				t.Errorf("Filter(%v, %s) = %v, want %v", tt.xs, tt.name, got, tt.want)
			}
		})
	}
}

func TestMapInts(t *testing.T) {
	double := func(x int) int { return 2 * x }
	square := func(x int) int { return x * x }

	tests := []struct {
		name string
		xs   []int
		f    func(int) int
		want []int
	}{
		{"double", []int{1, 2, 3}, double, []int{2, 4, 6}},
		{"square", []int{-2, 3}, square, []int{4, 9}},
		{"empty input", nil, double, nil},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := MapInts(tt.xs, tt.f)
			if !slices.Equal(got, tt.want) {
				t.Errorf("MapInts(%v, %s) = %v, want %v", tt.xs, tt.name, got, tt.want)
			}
		})
	}
}

func TestChunk(t *testing.T) {
	tests := []struct {
		name string
		xs   []int
		size int
		want [][]int
	}{
		{"even split", []int{1, 2, 3, 4}, 2, [][]int{{1, 2}, {3, 4}}},
		{"uneven split", []int{1, 2, 3, 4, 5}, 2, [][]int{{1, 2}, {3, 4}, {5}}},
		{"size one", []int{1, 2, 3}, 1, [][]int{{1}, {2}, {3}}},
		{"size larger than slice", []int{1, 2}, 5, [][]int{{1, 2}}},
		{"empty slice", nil, 3, nil},
		{"zero size", []int{1, 2}, 0, nil},
		{"negative size", []int{1, 2}, -1, nil},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := Chunk(tt.xs, tt.size)
			if !reflect.DeepEqual(got, tt.want) {
				t.Errorf("Chunk(%v, %d) = %v, want %v", tt.xs, tt.size, got, tt.want)
			}
		})
	}
}

func TestRotate(t *testing.T) {
	tests := []struct {
		name string
		xs   []int
		k    int
		want []int
	}{
		{"rotate by 2", []int{1, 2, 3, 4, 5}, 2, []int{3, 4, 5, 1, 2}},
		{"rotate by 0", []int{1, 2, 3}, 0, []int{1, 2, 3}},
		{"rotate by length", []int{1, 2, 3}, 3, []int{1, 2, 3}},
		{"rotate past length", []int{1, 2, 3}, 4, []int{2, 3, 1}},
		{"negative k rotates right", []int{1, 2, 3, 4}, -1, []int{4, 1, 2, 3}},
		{"empty", nil, 3, nil},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			orig := slices.Clone(tt.xs)
			got := Rotate(tt.xs, tt.k)
			if !slices.Equal(got, tt.want) {
				t.Errorf("Rotate(%v, %d) = %v, want %v", tt.xs, tt.k, got, tt.want)
			}
			if !slices.Equal(tt.xs, orig) {
				t.Errorf("Rotate(%v, %d) modified its input: now %v", orig, tt.k, tt.xs)
			}
		})
	}
}
