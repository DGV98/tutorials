package capstone

import "strings"

// route is one parsed line of the timetable, e.g.
//
//	route R-17: GLACIER-GATE => TINSEL-TOWN | distance 42 | toll 7
//
// Routes are one-way: from -> to only.
type route struct {
	id       string
	from, to string
	distance int
	toll     int
}

func parseRoutes(input string) []route {
	lines := inputLines(input)
	routes := make([]route, 0, len(lines))
	for _, line := range lines {
		rest := strings.TrimPrefix(line, "route ")
		id, rest, _ := strings.Cut(rest, ": ")
		endpoints, rest, _ := strings.Cut(rest, " | ")
		from, to, _ := strings.Cut(endpoints, " => ")
		distPart, tollPart, _ := strings.Cut(rest, " | ")
		routes = append(routes, route{
			id:       id,
			from:     from,
			to:       to,
			distance: mustInt(strings.TrimPrefix(distPart, "distance ")),
			toll:     mustInt(strings.TrimPrefix(tollPart, "toll ")),
		})
	}
	return routes
}

// SolveDay4Part1 returns the total distance of every route whose toll
// is at most 5 candy canes.
func SolveDay4Part1(input string) int {
	total := 0
	for _, r := range parseRoutes(input) {
		if r.toll <= 5 {
			total += r.distance
		}
	}
	return total
}

// SolveDay4Part2 returns the smallest number of routes needed to
// travel from NORTH-POLE to SANTAS-WORKSHOP, respecting route
// direction, or -1 if the workshop cannot be reached. Fewest hops on
// an unweighted graph is breadth-first search.
func SolveDay4Part2(input string) int {
	const start, goal = "NORTH-POLE", "SANTAS-WORKSHOP"

	next := make(map[string][]string)
	for _, r := range parseRoutes(input) {
		next[r.from] = append(next[r.from], r.to)
	}

	dist := map[string]int{start: 0} // doubles as the visited set
	queue := []string{start}
	for len(queue) > 0 {
		cur := queue[0]
		queue = queue[1:]
		for _, n := range next[cur] {
			if _, visited := dist[n]; visited {
				continue
			}
			dist[n] = dist[cur] + 1
			if n == goal {
				return dist[n]
			}
			queue = append(queue, n)
		}
	}
	return -1
}
