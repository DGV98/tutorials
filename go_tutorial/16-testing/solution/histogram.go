package testkit

// RuneHistogram returns a map from each rune (Unicode code point) in s
// to the number of times it appears. Ranging over a string yields
// runes, not bytes (module 07), so "héé" maps 'h' to 1 and 'é' to 2.
// If s is empty, RuneHistogram returns an empty (or nil) map.
func RuneHistogram(s string) map[rune]int {
	h := make(map[rune]int)
	for _, r := range s {
		h[r]++
	}
	return h
}

// MostCommon returns the rune that appears most often in s, along with
// its count. If several runes tie for the highest count, the smallest
// rune (by code point) wins — map iteration order is random (module
// 06), so the tie-break must not depend on it. If s is empty,
// MostCommon returns (0, 0).
func MostCommon(s string) (rune, int) {
	var best rune
	bestN := 0
	for r, n := range RuneHistogram(s) {
		// Strictly better count wins; on a tie, the smaller rune wins.
		if n > bestN || (n == bestN && r < best) {
			best, bestN = r, n
		}
	}
	return best, bestN
}
