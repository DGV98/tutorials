// Command puzzlerunner runs the capstone puzzle solvers and prints a
// result table. This is milestone 7 — the only part of the project with
// no tests: you verify it by running it.
//
// Target usage (from the repo root):
//
//	go run ./18-capstone-project/cmd/puzzlerunner -all
//	go run ./18-capstone-project/cmd/puzzlerunner -day 2
//	go run ./18-capstone-project/cmd/puzzlerunner -all -workers 8
package main

import (
	"flag"
	"fmt"
	"os"

	"gotutorial/18-capstone-project/runner"
	"gotutorial/18-capstone-project/solvers"
)

func main() {
	day := flag.Int("day", 0, "run a single day (0 = use -all)")
	all := flag.Bool("all", false, "run every registered day")
	inputs := flag.String("inputs", "18-capstone-project/inputs", "directory containing dayN.txt files")
	workers := flag.Int("workers", 4, "how many solvers may run at once with -all")
	flag.Parse()

	reg := runner.NewRegistry()
	if err := register(reg); err != nil {
		fmt.Fprintln(os.Stderr, "puzzlerunner:", err)
		os.Exit(1)
	}

	// TODO: implement the run-and-report logic:
	//   1. Collect results: r.Run(*day, *inputs) for -day N, or
	//      r.RunAllParallel(*inputs, *workers) for -all (if neither flag
	//      was given, print a usage hint and exit non-zero).
	//   2. Print a table: DAY | NAME | PART 1 | PART 2 | TIME.
	//      text/tabwriter aligns the columns for you; res.Elapsed.Round
	//      (time.Microsecond) keeps the times readable.
	//   3. If any Result has Err != nil, print it and os.Exit(1) at the
	//      end (after printing the other rows — one bad day shouldn't
	//      hide the rest).
	_ = day
	_ = all
	_ = inputs
	_ = workers
	fmt.Println("puzzlerunner: not implemented yet — see README milestone 7")
}

// register wires every solver into the registry. Wrote a day3? Add it here.
func register(r *runner.Registry) error {
	if err := r.Register(1, solvers.Day1{}); err != nil {
		return err
	}
	return r.Register(2, solvers.Day2{})
}
