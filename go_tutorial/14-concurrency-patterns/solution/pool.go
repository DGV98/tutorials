// Package patterns contains the exercises for module 14: the worker
// pool pattern, pipelines built from channel stages, fan-out/fan-in,
// protecting shared state with sync.Mutex, and context.Context for
// cancellation and timeouts.
package patterns

import "sync"

// WorkerPool applies fn to every element of jobs and returns the
// results, computed by a pool of `workers` goroutines running
// concurrently.
//
// The classic shape — and the one the tests expect — is:
//
//   - one jobs channel that every worker receives from,
//   - one results channel that every worker sends to,
//   - a sync.WaitGroup so the results channel can be closed exactly
//     once, after the last worker has finished.
//
// The returned slice contains fn(j) for every j in jobs, in
// unspecified order: whichever worker finishes first delivers first.
// Its length always equals len(jobs), and fn is called exactly once
// per job. If workers < 1 it is treated as 1. An empty or nil jobs
// slice yields an empty result.
//
// Hints: close the jobs channel after sending the last job, or the
// workers' range loops never end. Close the results channel from a
// goroutine that first calls wg.Wait() — never from inside a worker
// (the first worker to close it strands the others sending on a
// closed channel). Feed the jobs from their own goroutine so the
// caller's goroutine is free to collect results as they arrive.
func WorkerPool(jobs []int, workers int, fn func(int) int) []int {
	if workers < 1 {
		workers = 1
	}

	jobsCh := make(chan int)
	results := make(chan int)

	var wg sync.WaitGroup
	for range workers {
		wg.Go(func() {
			for j := range jobsCh {
				results <- fn(j)
			}
		})
	}

	// Feed jobs from their own goroutine so this goroutine can move on
	// to collecting; feeding inline would deadlock the moment every
	// worker was busy and nobody was draining results.
	go func() {
		for _, j := range jobs {
			jobsCh <- j
		}
		close(jobsCh) // ends every worker's range loop
	}()

	// Exactly one goroutine closes results, and only after the last
	// worker is done — that close is what ends the collection loop.
	go func() {
		wg.Wait()
		close(results)
	}()

	out := make([]int, 0, len(jobs))
	for r := range results {
		out = append(out, r)
	}
	return out
}
