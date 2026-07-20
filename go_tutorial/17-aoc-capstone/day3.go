package capstone

// SolveDay3Part1 returns the figurine arrangement after running the
// winding card once. The first input line is the starting arrangement:
// distinct lowercase letters, one per slot, slots numbered from 0 on
// the left. Every following line is one instruction, applied in order:
//
//	spin X       — rotate the whole ring right: the last X figurines
//	               move, in order, to the front (0 <= X <= slots).
//	swap I J     — the figurines in slots I and J trade places.
//	reverse I J  — the run of figurines in slots I..J inclusive
//	               reverses order (I <= J).
//
// Indices always refer to slots (positions), never to letters.
func SolveDay3Part1(input string) string {
	// TODO: implement
	return ""
}

// SolveDay3Part2 returns the arrangement after running the winding
// card 1,000,000,000 times in a row. One "run" applies the whole card,
// top to bottom, to the arrangement left by the previous run.
//
// Simulating a billion runs of a 180-line card is ~10^11 operations —
// far too slow. The arrangement is a finite state updated by a fixed
// rule, so the after-each-run sequence must eventually repeat an
// earlier state; detect that cycle and jump ahead with modular
// arithmetic instead of simulating.
func SolveDay3Part2(input string) string {
	// TODO: implement
	return ""
}
