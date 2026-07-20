package values

import "testing"

func TestZeroValueReport(t *testing.T) {
	want := `int=0 float64=0 string="" bool=false`
	if got := ZeroValueReport(); got != want {
		t.Errorf("ZeroValueReport() = %q, want %q", got, want)
	}
}
