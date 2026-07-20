# Go Quick Reference — Advent of Code Edition

Lookup card for Go 1.26, stdlib only. Companion to the 18-module course.

## Declarations & Types

```go
var n int                     // zero value: 0 ("", false, nil)
x := 42                       // short declaration, type inferred
a, b := 1, "two"              // multiple assignment
const Size = 141              // untyped constant
type Point struct{ R, C int } // comparable -> works as a map key
p := Point{R: 1, C: 2}
nums := []int{1, 2, 3} // slice (grows)
var arr [3][3]byte     // fixed-size array (rare in AoC)
m := map[Point]int{}   // empty map, ready to use
inc := func(v int) int { return v + 1 }
```

Conversions are always explicit: `float64(n)`, `int(f)` (truncates), `strconv.Itoa(n)` — never `string(n)` — `int(b - '0')` (digit byte to int), `[]byte(s)` / `string(bs)`.

## String Parsing One-Liners

```go
parts := strings.Split(line, ",")            // "1,2," -> ["1" "2" ""] keeps empties
words := strings.Fields(line)                // any whitespace, no empties
n, err := strconv.Atoi("42")                 // string -> int
line = strings.TrimSpace(line)               // strip \n and spaces
before, after, ok := strings.Cut(line, ": ") // split at first separator
strings.HasPrefix(line, "Game")              // also HasSuffix, Contains
strings.ReplaceAll(s, "old", "new")
```

Extract every int (handles negatives) — keep this in every solution:

```go
var intRe = regexp.MustCompile(`-?\d+`)

func extractInts(s string) []int {
	var out []int
	for _, m := range intRe.FindAllString(s, -1) {
		n, _ := strconv.Atoi(m)
		out = append(out, n)
	}
	return out
}
```

Fixed-format lines — `Sscanf` (`%d` takes negatives; `%s` stops at whitespace):

```go
var id, x, y int
fmt.Sscanf(line, "#%d @ %d,%d", &id, &x, &y)
```

## Slices

```go
var s []int             // nil slice: len 0, append works
s = append(s, 1, 2, 3)  // append may reallocate — always reassign
s = append(s, other...) // concat
c := slices.Clone(s)    // copy; or: c := make([]int, len(s)); copy(c, s)
w := s[1:3]             // half-open [lo:hi) view — shares memory!
s = s[1:]               // pop front
s = s[:len(s)-1]        // pop back
```

2D grid setup:

```go
grid := make([][]byte, rows) // blank rows x cols grid
for r := range grid {
	grid[r] = make([]byte, cols)
}

g := make([][]byte, len(lines)) // straight from input lines
for r, line := range lines {
	g[r] = []byte(line)
}
```

`slices` package helpers (import `"slices"`, `"maps"`):

```go
has := slices.Contains(s, 7)
i := slices.Index(s, 7)                // -1 if absent
hi, lo := slices.Max(s), slices.Min(s) // panic on empty slice
slices.Reverse(s)                      // in place
eq := slices.Equal(a, b)
keys := slices.Sorted(maps.Keys(m)) // sorted map keys as a new slice
```

## Maps

```go
m := map[string]int{}
m["a"] = 1
v, ok := m["a"] // comma-ok: ok=false if missing, v is zero value
delete(m, "a")
for k, v := range m { // iteration order is randomized!
	fmt.Println(k, v)
}
```

Sets and counting:

```go
seen := map[Point]bool{} // set
seen[p] = true
if seen[p] { // missing key -> false, no comma-ok needed
}

set := map[string]struct{}{} // zero-byte variant
set["x"] = struct{}{}
if _, ok := set["x"]; ok {
}

count := map[rune]int{} // counting
for _, ch := range s {
	count[ch]++ // missing key starts at 0
}
```

## Sorting

Imports: `"slices"`, `"cmp"`.

```go
slices.Sort(nums) // ascending, any ordered type
slices.SortFunc(items, func(a, b Item) int {
	return cmp.Compare(a.Rank, b.Rank) // negative / 0 / positive
})
slices.SortFunc(nums, func(a, b int) int { return cmp.Compare(b, a) }) // descending
slices.SortFunc(items, func(a, b Item) int {                           // multi-key
	return cmp.Or(cmp.Compare(a.Rank, b.Rank), cmp.Compare(a.Name, b.Name))
})
i, found := slices.BinarySearch(sorted, target) // needs sorted input
```

## Reading Input

Whole file at once — the AoC default:

```go
data, err := os.ReadFile("input.txt")
if err != nil {
	log.Fatal(err)
}
lines := strings.Split(strings.TrimSpace(string(data)), "\n")
blocks := strings.Split(strings.TrimSpace(string(data)), "\n\n") // paragraph groups
```

Line by line — streams, for huge inputs:

```go
f, err := os.Open("input.txt")
if err != nil {
	log.Fatal(err)
}
defer f.Close()
sc := bufio.NewScanner(f)
sc.Buffer(make([]byte, 1024*1024), 1024*1024) // default cap is 64KB/line
for sc.Scan() {
	line := sc.Text() // no trailing \n
	_ = line
}
```

## Common AoC Patterns

Grid neighbors with dr/dc deltas:

```go
var (
	dr = []int{-1, 1, 0, 0} // up, down, left, right
	dc = []int{0, 0, -1, 1}
)

for i := range 4 {
	nr, nc := r+dr[i], c+dc[i]
	if nr < 0 || nr >= len(grid) || nc < 0 || nc >= len(grid[0]) {
		continue
	}
	_ = grid[nr][nc]
}
```

8-way: `for dr := -1; dr <= 1; dr++ { for dc := -1; dc <= 1; dc++ {` … skip `dr == 0 && dc == 0`.

BFS — slice queue + dist map (doubles as visited set):

```go
func bfs(grid [][]byte, start, goal Point) int {
	dist := map[Point]int{start: 0}
	queue := []Point{start}
	for len(queue) > 0 {
		cur := queue[0]
		queue = queue[1:]
		if cur == goal {
			return dist[cur]
		}
		for i := range 4 {
			n := Point{cur.R + dr[i], cur.C + dc[i]}
			if n.R < 0 || n.R >= len(grid) || n.C < 0 || n.C >= len(grid[0]) {
				continue
			}
			if grid[n.R][n.C] == '#' {
				continue
			}
			if _, ok := dist[n]; ok {
				continue
			}
			dist[n] = dist[cur] + 1
			queue = append(queue, n)
		}
	}
	return -1
}
```

Cycle detection — "run it 1,000,000,000 times" means find the loop and jump ahead:

```go
seen := map[string]int{} // fingerprint -> step first seen
for step := 0; step < total; step++ {
	key := fingerprint(state) // serialize state, e.g. string(gridBytes)
	if first, ok := seen[key]; ok {
		for range (total - step) % (step - first) {
			state = next(state) // next: your step function
		}
		break
	}
	seen[key] = step
	state = next(state)
}
```

Memoization — recursive count with a map cache:

```go
var memo = map[[2]int]int{}

func paths(r, c int) int {
	if r == 0 && c == 0 {
		return 1
	}
	if r < 0 || c < 0 {
		return 0
	}
	key := [2]int{r, c}
	if v, ok := memo[key]; ok {
		return v
	}
	res := paths(r-1, c) + paths(r, c-1) // your recursion here
	memo[key] = res
	return res
}
```

## Error-Handling One-Liners

```go
if err != nil {
	log.Fatal(err) // print + exit(1); fine for AoC mains
}
n, _ := strconv.Atoi(s) // discard err when input is trusted
```

Generic `must` — collapses any `(T, error)` call:

```go
func must[T any](v T, err error) T {
	if err != nil {
		panic(err)
	}
	return v
}
```

```go
n := must(strconv.Atoi(s))
data := must(os.ReadFile("input.txt"))
```

## Goroutines & Channels

Parallel fan-out — each goroutine owns one result slot, no locks (`wg.Go` is Go 1.25+):

```go
var wg sync.WaitGroup
results := make([]int, len(inputs))
for i, in := range inputs {
	wg.Go(func() {
		results[i] = solve(in)
	})
}
wg.Wait()
```

Channel basics:

```go
ch := make(chan int, 8) // buffered; make(chan int) = unbuffered
ch <- 1                 // send
v := <-ch               // receive
close(ch)               // sender closes; range drains until closed
```

Worker pool:

```go
jobs, out := make(chan int), make(chan int)
for range 8 { // workers
	go func() {
		for j := range jobs {
			out <- solve(j)
		}
	}()
}
go func() { // feeder
	for _, j := range inputs {
		jobs <- j
	}
	close(jobs)
}()
sum := 0
for range inputs {
	sum += <-out
}
```

Shared maps need a `sync.Mutex` — or avoid sharing, as in the fan-out above. Debug with `-race`.

## `go` Command Cheatsheet

| Command | Purpose |
|---|---|
| `go run .` | compile + run package in current dir |
| `go build -o day01 .` | produce a binary |
| `go test ./...` | run all tests in the module |
| `go test -run 'TestPart1'` | run tests matching a regexp |
| `go test -v` | verbose: show each test |
| `go test -race ./...` | race detector (also `go run -race`) |
| `go test -bench . -benchmem` | run benchmarks + allocation stats |
| `go fmt ./...` | gofmt every file |
| `go vet ./...` | static checks for common bugs |
| `go doc strings.Cut` | quick docs for any symbol |
