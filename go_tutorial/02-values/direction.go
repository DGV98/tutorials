package values

// Direction is a compass direction. Because its underlying type is int,
// Direction values support integer arithmetic — which is exactly what makes
// "turning" cheap.
type Direction int

// TODO: replace the explicit zeros below with an iota-based declaration so
// that North=0, East=1, South=2, West=3 (clockwise order). TurnRight — and
// any grid walking you do later — depends on that exact numbering.
const (
	North Direction = 0
	East  Direction = 0
	South Direction = 0
	West  Direction = 0
)

// TurnRight returns the direction 90 degrees clockwise from d:
// North -> East -> South -> West -> North.
//
// d is guaranteed to be one of the four Direction constants.
func TurnRight(d Direction) Direction {
	// TODO: implement
	return 0
}
