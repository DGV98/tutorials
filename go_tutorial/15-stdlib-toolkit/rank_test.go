package toolkit

import (
	"slices"
	"testing"
)

func TestSortPeople(t *testing.T) {
	tests := []struct {
		name   string
		people []Person
		want   []Person
	}{
		{
			name: "by age",
			people: []Person{
				{"Carol", 30},
				{"Alice", 25},
				{"Eve", 41},
			},
			want: []Person{
				{"Alice", 25},
				{"Carol", 30},
				{"Eve", 41},
			},
		},
		{
			name: "ties broken by name",
			people: []Person{
				{"Dan", 25},
				{"Carol", 30},
				{"Bob", 25},
				{"Alice", 30},
			},
			want: []Person{
				{"Bob", 25},
				{"Dan", 25},
				{"Alice", 30},
				{"Carol", 30},
			},
		},
		{
			name:   "empty slice",
			people: nil,
			want:   nil,
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := slices.Clone(tt.people)
			SortPeople(got)
			if !slices.Equal(got, tt.want) {
				t.Errorf("SortPeople(%v) = %v, want %v", tt.people, got, tt.want)
			}
		})
	}
}

func TestTopN(t *testing.T) {
	counts := map[string]int{"a": 3, "b": 5, "c": 3, "d": 1}
	tests := []struct {
		name   string
		counts map[string]int
		n      int
		want   []string
	}{
		{"top two", counts, 2, []string{"b", "a"}},
		{"tie broken alphabetically", counts, 3, []string{"b", "a", "c"}},
		{"n larger than map", counts, 10, []string{"b", "a", "c", "d"}},
		{"n is zero", counts, 0, nil},
		{"negative n", counts, -1, nil},
		{"empty map", map[string]int{}, 3, nil},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := TopN(tt.counts, tt.n)
			if !slices.Equal(got, tt.want) {
				t.Errorf("TopN(%v, %d) = %q, want %q", tt.counts, tt.n, got, tt.want)
			}
		})
	}
}
