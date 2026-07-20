package mapping

import (
	"maps"
	"reflect"
	"slices"
	"testing"
)

func TestWordCount(t *testing.T) {
	tests := []struct {
		name string
		text string
		want map[string]int
	}{
		{"no words", "   \t\n", map[string]int{}},
		{"single word", "go", map[string]int{"go": 1}},
		{"repeats", "the quick the lazy the", map[string]int{"the": 3, "quick": 1, "lazy": 1}},
		{"mixed whitespace", "a  b\tb\na", map[string]int{"a": 2, "b": 2}},
		{"case sensitive", "Go go", map[string]int{"Go": 1, "go": 1}},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := WordCount(tt.text); !maps.Equal(got, tt.want) {
				t.Errorf("WordCount(%q) = %v, want %v", tt.text, got, tt.want)
			}
		})
	}
}

func TestFirstRepeated(t *testing.T) {
	tests := []struct {
		name   string
		xs     []int
		want   int
		wantOK bool
	}{
		{"empty", nil, 0, false},
		{"all distinct", []int{1, 2, 3}, 0, false},
		{"immediate repeat", []int{5, 5}, 5, true},
		{"first to repeat wins", []int{1, 2, 3, 2, 1}, 2, true},
		{"zero can repeat", []int{0, 1, 0}, 0, true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, ok := FirstRepeated(tt.xs)
			if got != tt.want || ok != tt.wantOK {
				t.Errorf("FirstRepeated(%v) = (%d, %t), want (%d, %t)",
					tt.xs, got, ok, tt.want, tt.wantOK)
			}
		})
	}
}

func TestIntersect(t *testing.T) {
	tests := []struct {
		name string
		a, b []int
		want []int
	}{
		{"disjoint", []int{1, 2}, []int{3, 4}, nil},
		{"empty a", nil, []int{1, 2}, nil},
		{"overlap", []int{1, 2, 3, 4}, []int{3, 4, 5}, []int{3, 4}},
		{"duplicates collapse", []int{1, 1, 2, 2}, []int{2, 2, 1}, []int{1, 2}},
		{"result is sorted", []int{5, 3, 1}, []int{1, 3, 5, 7}, []int{1, 3, 5}},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := Intersect(tt.a, tt.b); !slices.Equal(got, tt.want) {
				t.Errorf("Intersect(%v, %v) = %v, want %v", tt.a, tt.b, got, tt.want)
			}
		})
	}
}

func TestGroupAnagrams(t *testing.T) {
	tests := []struct {
		name  string
		words []string
		want  [][]string
	}{
		{"empty", nil, nil},
		{
			"classic",
			[]string{"eat", "tea", "tan", "ate", "nat", "bat"},
			[][]string{{"eat", "tea", "ate"}, {"tan", "nat"}, {"bat"}},
		},
		{
			"no anagrams",
			[]string{"go", "rust"},
			[][]string{{"go"}, {"rust"}},
		},
		{
			"identical words",
			[]string{"abc", "abc"},
			[][]string{{"abc", "abc"}},
		},
		{
			"case sensitive",
			[]string{"Tea", "eat", "ate"},
			[][]string{{"Tea"}, {"eat", "ate"}},
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := GroupAnagrams(tt.words); !reflect.DeepEqual(got, tt.want) {
				t.Errorf("GroupAnagrams(%v) = %v, want %v", tt.words, got, tt.want)
			}
		})
	}
}

func TestMode(t *testing.T) {
	tests := []struct {
		name   string
		xs     []int
		want   int
		wantOK bool
	}{
		{"empty", nil, 0, false},
		{"single", []int{4}, 4, true},
		{"clear winner", []int{1, 2, 2, 3, 2}, 2, true},
		{"tie smallest wins", []int{3, 3, 1, 1, 2}, 1, true},
		{"all tied", []int{9, 4, 7}, 4, true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, ok := Mode(tt.xs)
			if got != tt.want || ok != tt.wantOK {
				t.Errorf("Mode(%v) = (%d, %t), want (%d, %t)",
					tt.xs, got, ok, tt.want, tt.wantOK)
			}
		})
	}
}

func TestInvert(t *testing.T) {
	tests := []struct {
		name string
		m    map[string]int
		want map[int]string
	}{
		{"empty", map[string]int{}, map[int]string{}},
		{"simple", map[string]int{"a": 1, "b": 2}, map[int]string{1: "a", 2: "b"}},
		{
			"duplicate values, smallest key wins",
			map[string]int{"zebra": 1, "apple": 1, "mango": 2},
			map[int]string{1: "apple", 2: "mango"},
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := Invert(tt.m); !maps.Equal(got, tt.want) {
				t.Errorf("Invert(%v) = %v, want %v", tt.m, got, tt.want)
			}
		})
	}
}

func TestTwoSum(t *testing.T) {
	tests := []struct {
		name         string
		xs           []int
		target       int
		wantI, wantJ int
		wantOK       bool
	}{
		{"empty", nil, 0, 0, 0, false},
		{"no pair", []int{1, 2, 3}, 100, 0, 0, false},
		{"cannot pair with itself", []int{5}, 10, 0, 0, false},
		{"basic", []int{2, 7, 11, 15}, 9, 0, 1, true},
		{"pair at end", []int{3, 2, 4}, 6, 1, 2, true},
		{"equal values at two indices", []int{3, 3}, 6, 0, 1, true},
		{"negatives", []int{-1, 5, 4, -3}, -4, 0, 3, true},
		{"smallest j wins", []int{1, 2, 3, 4}, 5, 1, 2, true},
		{"smallest i wins for that j", []int{3, 1, 3, 5}, 8, 0, 3, true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			i, j, ok := TwoSum(tt.xs, tt.target)
			if i != tt.wantI || j != tt.wantJ || ok != tt.wantOK {
				t.Errorf("TwoSum(%v, %d) = (%d, %d, %t), want (%d, %d, %t)",
					tt.xs, tt.target, i, j, ok, tt.wantI, tt.wantJ, tt.wantOK)
			}
		})
	}
}
