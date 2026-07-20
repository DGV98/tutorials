package values

import "testing"

func TestDirectionConstants(t *testing.T) {
	// TurnRight (and grid math in later modules) relies on this exact
	// clockwise numbering, which the iota declaration should produce.
	if North != 0 || East != 1 || South != 2 || West != 3 {
		t.Errorf("(North, East, South, West) = (%d, %d, %d, %d), want (0, 1, 2, 3)",
			North, East, South, West)
	}
}

func TestTurnRight(t *testing.T) {
	// Numeric literals rather than the named constants, so this test
	// checks TurnRight on its own even while the constants are still
	// the mis-declared placeholders (TestDirectionConstants pins the
	// mapping 0=North, 1=East, 2=South, 3=West).
	tests := []struct {
		name    string
		d, want Direction
	}{
		{"North to East", 0, 1},
		{"East to South", 1, 2},
		{"South to West", 2, 3},
		{"West wraps to North", 3, 0},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := TurnRight(tt.d); got != tt.want {
				t.Errorf("TurnRight(%d) = %d, want %d", tt.d, got, tt.want)
			}
		})
	}
}

func TestTurnRightFullCircle(t *testing.T) {
	// Four right turns from any direction must end up where you started.
	d := North
	for i := 0; i < 4; i++ {
		d = TurnRight(d)
	}
	if d != North {
		t.Errorf("TurnRight applied 4 times from North = %d, want %d (North)", d, North)
	}
}
