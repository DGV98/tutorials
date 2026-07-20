package runner

import (
	"cmp"
	"slices"
	"sync"
	"time"
)

// Run looks up the solver for day, loads its input from inputsDir, solves,
// and returns a filled-in Result. Failures are carried in Result.Err so a
// batch run can keep going. Elapsed times only the Solve call and is
// recorded even when Solve fails.
func (r *Registry) Run(day int, inputsDir string) Result {
	res := Result{Day: day}

	s, err := r.Get(day)
	if err != nil {
		res.Err = err
		return res
	}
	res.Name = s.Name()

	input, err := LoadInput(inputsDir, day)
	if err != nil {
		res.Err = err
		return res
	}

	start := time.Now()
	part1, part2, err := s.Solve(input)
	res.Elapsed = time.Since(start)
	res.Part1, res.Part2, res.Err = part1, part2, err
	return res
}

// RunAll runs every registered day in ascending order, sequentially.
func (r *Registry) RunAll(inputsDir string) []Result {
	days := r.Days()
	results := make([]Result, 0, len(days))
	for _, day := range days {
		results = append(results, r.Run(day, inputsDir))
	}
	return results
}

// RunAllParallel is RunAll with a worker pool: at most `workers` solvers
// execute concurrently (workers < 1 is treated as 1). Results come back
// sorted by day regardless of completion order.
func (r *Registry) RunAllParallel(inputsDir string, workers int) []Result {
	if workers < 1 {
		workers = 1
	}

	jobs := make(chan int)
	out := make(chan Result)

	var wg sync.WaitGroup
	for range workers {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for day := range jobs {
				out <- r.Run(day, inputsDir)
			}
		}()
	}

	go func() {
		for _, day := range r.Days() {
			jobs <- day
		}
		close(jobs)
	}()

	go func() {
		wg.Wait()
		close(out)
	}()

	results := make([]Result, 0, len(r.solvers))
	for res := range out {
		results = append(results, res)
	}
	slices.SortFunc(results, func(a, b Result) int { return cmp.Compare(a.Day, b.Day) })
	return results
}
