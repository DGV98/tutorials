package toolkit

import (
	"slices"
	"strings"
	"testing"
	"time"
)

func TestExtractInts(t *testing.T) {
	tests := []struct {
		name  string
		input string
		want  []int
	}{
		{"plain numbers", "1 2 3", []int{1, 2, 3}},
		{"embedded in text", "move 12 from 3 to 45", []int{12, 3, 45}},
		{"negatives", "x=-5, y=17", []int{-5, 17}},
		{"detached dash is not a sign", "3 - 4", []int{3, 4}},
		// The classic AoC quirk: in "1-2" the dash touches the digits,
		// so it reads as 1 and -2. See the README for when to use
		// strings.Split instead.
		{"attached dash is a sign", "1-2", []int{1, -2}},
		{"digits inside words", "a1b22c", []int{1, 22}},
		{"multiline input", "top: 9\nbottom: -9", []int{9, -9}},
		{"no digits", "hello, world", nil},
		{"empty string", "", nil},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := ExtractInts(tt.input)
			if !slices.Equal(got, tt.want) {
				t.Errorf("ExtractInts(%q) = %v, want %v", tt.input, got, tt.want)
			}
		})
	}
}

func TestParseEvents(t *testing.T) {
	tests := []struct {
		name    string
		input   string
		want    []Event
		wantErr bool
	}{
		{
			name:  "two events",
			input: "2024-01-02 15:04|door opened\n2024-01-02 15:09|door closed\n",
			want: []Event{
				{time.Date(2024, 1, 2, 15, 4, 0, 0, time.UTC), "door opened"},
				{time.Date(2024, 1, 2, 15, 9, 0, 0, time.UTC), "door closed"},
			},
		},
		{
			name:  "message may contain a pipe",
			input: "2024-06-30 08:00|a|b\n",
			want: []Event{
				{time.Date(2024, 6, 30, 8, 0, 0, 0, time.UTC), "a|b"},
			},
		},
		{
			name:  "blank lines skipped",
			input: "\n2024-01-02 15:04|hi\n\n",
			want: []Event{
				{time.Date(2024, 1, 2, 15, 4, 0, 0, time.UTC), "hi"},
			},
		},
		{name: "empty input", input: "", want: nil},
		{name: "missing separator", input: "2024-01-02 15:04 no pipe\n", wantErr: true},
		{name: "bad timestamp", input: "yesterday-ish|msg\n", wantErr: true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := ParseEvents(strings.NewReader(tt.input))
			if tt.wantErr {
				if err == nil {
					t.Fatalf("ParseEvents(%q) = %v, want error", tt.input, got)
				}
				return
			}
			if err != nil {
				t.Fatalf("ParseEvents(%q) returned unexpected error: %v", tt.input, err)
			}
			if len(got) != len(tt.want) {
				t.Fatalf("ParseEvents(%q) returned %d events, want %d", tt.input, len(got), len(tt.want))
			}
			for i := range got {
				// time.Time values are compared with Equal, not ==.
				if !got[i].At.Equal(tt.want[i].At) || got[i].Msg != tt.want[i].Msg {
					t.Errorf("ParseEvents(%q)[%d] = %v, want %v", tt.input, i, got[i], tt.want[i])
				}
			}
		})
	}
}

func TestSpan(t *testing.T) {
	at := func(hour, min int) time.Time {
		return time.Date(2024, 1, 2, hour, min, 0, 0, time.UTC)
	}
	tests := []struct {
		name   string
		events []Event
		want   time.Duration
	}{
		{
			name: "in order",
			events: []Event{
				{at(15, 0), "start"},
				{at(15, 45), "end"},
			},
			want: 45 * time.Minute,
		},
		{
			name: "out of order",
			events: []Event{
				{at(15, 4), "middle"},
				{at(15, 0), "first"},
				{at(15, 30), "last"},
			},
			want: 30 * time.Minute,
		},
		{
			name: "hours apart",
			events: []Event{
				{at(9, 0), "open"},
				{at(17, 30), "close"},
			},
			want: 8*time.Hour + 30*time.Minute,
		},
		{name: "single event", events: []Event{{at(12, 0), "lonely"}}, want: 0},
		{name: "no events", events: nil, want: 0},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := Span(tt.events)
			if got != tt.want {
				t.Errorf("Span(%v) = %v, want %v", tt.events, got, tt.want)
			}
		})
	}
}
