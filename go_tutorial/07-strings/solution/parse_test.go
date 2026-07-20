package parsing

import (
	"maps"
	"slices"
	"testing"
)

func TestParseInts(t *testing.T) {
	tests := []struct {
		name    string
		input   string
		want    []int
		wantErr bool
	}{
		{"simple", "1,2,3", []int{1, 2, 3}, false},
		{"single number", "42", []int{42}, false},
		{"spaces around fields", " 1, -2 ,3 ", []int{1, -2, 3}, false},
		{"empty input", "", nil, false},
		{"whitespace-only input", "   ", nil, false},
		{"not a number", "1,two,3", nil, true},
		{"empty field", "1,,3", nil, true},
		{"trailing comma", "1,2,", nil, true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := ParseInts(tt.input)
			if tt.wantErr {
				if err == nil {
					t.Fatalf("ParseInts(%q) = %v, want error", tt.input, got)
				}
				return
			}
			if err != nil {
				t.Fatalf("ParseInts(%q) returned unexpected error: %v", tt.input, err)
			}
			if !slices.Equal(got, tt.want) {
				t.Errorf("ParseInts(%q) = %v, want %v", tt.input, got, tt.want)
			}
		})
	}
}

func TestParseKeyValue(t *testing.T) {
	tests := []struct {
		name    string
		input   string
		want    map[string]string
		wantErr bool
	}{
		{
			name:  "two lines",
			input: "name=gopher\nlang=go",
			want:  map[string]string{"name": "gopher", "lang": "go"},
		},
		{
			name:  "whitespace trimmed",
			input: "  name =  gopher  ",
			want:  map[string]string{"name": "gopher"},
		},
		{
			name:  "blank lines skipped",
			input: "a=1\n\n  \nb=2\n",
			want:  map[string]string{"a": "1", "b": "2"},
		},
		{
			name:  "value contains equals sign",
			input: "expr=1+1=2",
			want:  map[string]string{"expr": "1+1=2"},
		},
		{
			name:  "duplicate key keeps last value",
			input: "x=1\nx=2",
			want:  map[string]string{"x": "2"},
		},
		{
			name:  "empty value is allowed",
			input: "flag=",
			want:  map[string]string{"flag": ""},
		},
		{
			name:  "empty input gives empty map",
			input: "",
			want:  map[string]string{},
		},
		{
			name:    "line without equals sign",
			input:   "a=1\nnoequals\nb=2",
			wantErr: true,
		},
		{
			name:    "empty key",
			input:   "=value",
			wantErr: true,
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := ParseKeyValue(tt.input)
			if tt.wantErr {
				if err == nil {
					t.Fatalf("ParseKeyValue(%q) = %v, want error", tt.input, got)
				}
				return
			}
			if err != nil {
				t.Fatalf("ParseKeyValue(%q) returned unexpected error: %v", tt.input, err)
			}
			if got == nil || !maps.Equal(got, tt.want) {
				t.Errorf("ParseKeyValue(%q) = %v, want %v", tt.input, got, tt.want)
			}
		})
	}
}

func TestParseMoves(t *testing.T) {
	tests := []struct {
		name    string
		input   string
		want    []Move
		wantErr bool
	}{
		{
			name:  "three moves",
			input: "R5 L3 U2",
			want:  []Move{{'R', 5}, {'L', 3}, {'U', 2}},
		},
		{
			name:  "multi-digit distance and all directions",
			input: "U10 D2 L37 R1",
			want:  []Move{{'U', 10}, {'D', 2}, {'L', 37}, {'R', 1}},
		},
		{
			name:  "any whitespace separates tokens",
			input: "  R5\n\tL3  ",
			want:  []Move{{'R', 5}, {'L', 3}},
		},
		{
			name:  "empty input",
			input: "",
			want:  nil,
		},
		{"unknown direction", "R5 X3", nil, true},
		{"lowercase direction", "r5", nil, true},
		{"missing distance", "R", nil, true},
		{"junk after distance", "R5x", nil, true},
		{"zero distance", "R0", nil, true},
		{"negative distance", "R-2", nil, true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := ParseMoves(tt.input)
			if tt.wantErr {
				if err == nil {
					t.Fatalf("ParseMoves(%q) = %v, want error", tt.input, got)
				}
				return
			}
			if err != nil {
				t.Fatalf("ParseMoves(%q) returned unexpected error: %v", tt.input, err)
			}
			if !slices.Equal(got, tt.want) {
				t.Errorf("ParseMoves(%q) = %v, want %v", tt.input, got, tt.want)
			}
		})
	}
}
