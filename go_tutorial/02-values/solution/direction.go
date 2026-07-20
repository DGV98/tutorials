package values

// Direction is a compass direction. Because its underlying type is int,
// Direction values support integer arithmetic — which is exactly what makes
// "turning" cheap.
type Direction int

// The four compass directions in clockwise order. iota starts at 0 and
// increments per line; only the first constant needs the type and the
// iota — the rest repeat the pattern implicitly.
const (
	North Direction = iota // 0
	East                   // 1
	South                  // 2
	West                   // 3
)

// TurnRight returns the direction 90 degrees clockwise from d:
// North -> East -> South -> West -> North.
//
// d is guaranteed to be one of the four Direction constants.
func TurnRight(d Direction) Direction {
	// +1 steps clockwise through the enum; % 4 wraps West back to North.
	return (d + 1) % 4
}
