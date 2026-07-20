package capstone

import "strings"

// instruction is one line of the winding card. op is "spin", "swap",
// or "reverse"; a and b are its operands (b is unused for "spin").
type instruction struct {
	op   string
	a, b int
}

func parseCard(input string) (start string, card []instruction) {
	lines := inputLines(input)
	card = make([]instruction, 0, len(lines)-1)
	for _, line := range lines[1:] {
		f := strings.Fields(line)
		in := instruction{op: f[0], a: mustInt(f[1])}
		if len(f) > 2 {
			in.b = mustInt(f[2])
		}
		card = append(card, in)
	}
	return lines[0], card
}

// runPass applies every instruction on the card once, in order, and
// returns the resulting arrangement.
func runPass(state string, card []instruction) string {
	s := []byte(state) // strings are immutable; edit a byte slice copy
	for _, in := range card {
		switch in.op {
		case "spin":
			n := len(s)
			x := in.a % n
			// Build a fresh slice: appending s[n-x:] to itself in
			// place would read bytes we have already overwritten.
			rotated := make([]byte, 0, n)
			rotated = append(rotated, s[n-x:]...)
			rotated = append(rotated, s[:n-x]...)
			s = rotated
		case "swap":
			s[in.a], s[in.b] = s[in.b], s[in.a]
		case "reverse":
			for i, j := in.a, in.b; i < j; i, j = i+1, j-1 {
				s[i], s[j] = s[j], s[i]
			}
		}
	}
	return string(s)
}

// SolveDay3Part1 returns the arrangement of figurines after running
// the winding card once. The first input line is the starting
// arrangement; every following line is one instruction.
func SolveDay3Part1(input string) string {
	start, card := parseCard(input)
	return runPass(start, card)
}

// SolveDay3Part2 returns the arrangement after running the winding
// card one billion times. Simulating every pass is hopeless, but the
// arrangement is finite state evolving under a fixed rule, so the
// sequence of arrangements must eventually revisit one it has seen —
// find that cycle and jump ahead with modular arithmetic.
func SolveDay3Part2(input string) string {
	const passes = 1_000_000_000
	start, card := parseCard(input)

	seen := make(map[string]int) // arrangement -> pass count when first seen
	var history []string         // history[k] = arrangement after k passes
	state := start
	for pass := 0; pass < passes; pass++ {
		if first, ok := seen[state]; ok {
			cycle := pass - first
			return history[first+(passes-first)%cycle]
		}
		seen[state] = pass
		history = append(history, state)
		state = runPass(state, card)
	}
	return state // only reached if there is no cycle within a billion passes
}
