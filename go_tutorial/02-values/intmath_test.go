package values

import "testing"

func TestDigitSum(t *testing.T) {
	tests := []struct {
		name string
		n    int
		want int
	}{
		{"zero", 0, 0},
		{"single digit", 7, 7},
		{"multiple digits", 12345, 15},
		{"zeros inside", 909, 18},
		{"all nines", 999999, 54},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := DigitSum(tt.n); got != tt.want {
				t.Errorf("DigitSum(%d) = %d, want %d", tt.n, got, tt.want)
			}
		})
	}
}

func TestLastNDigits(t *testing.T) {
	tests := []struct {
		name string
		x, n int
		want int
	}{
		{"last two digits", 12345, 2, 45},
		{"last digit", 987, 1, 7},
		{"n longer than the number", 42, 5, 42},
		{"leading zero drops off", 105, 2, 5},
		{"big modulus", 1000000007, 9, 7},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := LastNDigits(tt.x, tt.n); got != tt.want {
				t.Errorf("LastNDigits(%d, %d) = %d, want %d", tt.x, tt.n, got, tt.want)
			}
		})
	}
}

func TestSplitDuration(t *testing.T) {
	tests := []struct {
		name                string
		totalSeconds        int
		wantH, wantM, wantS int
	}{
		{"zero", 0, 0, 0, 0},
		{"seconds only", 59, 0, 0, 59},
		{"one of each", 3661, 1, 1, 1},
		{"exact hours", 7200, 2, 0, 0},
		{"last second of the day", 86399, 23, 59, 59},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			h, m, s := SplitDuration(tt.totalSeconds)
			if h != tt.wantH || m != tt.wantM || s != tt.wantS {
				t.Errorf("SplitDuration(%d) = (%d, %d, %d), want (%d, %d, %d)",
					tt.totalSeconds, h, m, s, tt.wantH, tt.wantM, tt.wantS)
			}
		})
	}
}
