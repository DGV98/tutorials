package runner

// Run looks up the solver for day, loads its input from inputsDir, solves,
// and returns a filled-in Result. Run never returns an error itself —
// failures are carried in Result.Err so a batch run can keep going:
//
//   - unknown day        -> Err from Get (Name stays empty)
//   - input won't load   -> Err from LoadInput
//   - solver fails       -> Err exactly as Solve returned it
//
// Elapsed times only the Solve call (not lookup or file loading), and is
// recorded even when Solve returns an error.
func (r *Registry) Run(day int, inputsDir string) Result {
	// TODO: implement
	return Result{}
}

// RunAll runs every registered day in ascending order, sequentially,
// and returns one Result per day.
func (r *Registry) RunAll(inputsDir string) []Result {
	// TODO: implement
	return nil
}

// RunAllParallel is RunAll with a worker pool: at most `workers` solvers
// execute concurrently (workers < 1 is treated as 1). The returned slice
// is still sorted by day, no matter which solver finished first.
//
// Build it the module-14 way: a jobs channel feeding worker goroutines, a
// results channel they send into, a WaitGroup so you know when to close
// the results channel, then sort what you collected.
func (r *Registry) RunAllParallel(inputsDir string, workers int) []Result {
	// TODO: implement
	return nil
}
