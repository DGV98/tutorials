// Command puzzlerunner runs the capstone puzzle solvers and prints a
// result table.
//
// Usage (from the repo root):
//
//	go run ./18-capstone-project/solution/cmd/puzzlerunner -all
//	go run ./18-capstone-project/solution/cmd/puzzlerunner -day 2
//	go run ./18-capstone-project/solution/cmd/puzzlerunner -all -workers 8
package main

import (
	"flag"
	"fmt"
	"os"
	"text/tabwriter"
	"time"

	"gotutorial/18-capstone-project/solution/runner"
	"gotutorial/18-capstone-project/solution/solvers"
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

	var results []runner.Result
	switch {
	case *day > 0:
		results = []runner.Result{reg.Run(*day, *inputs)}
	case *all:
		results = reg.RunAllParallel(*inputs, *workers)
	default:
		fmt.Fprintln(os.Stderr, "puzzlerunner: pass -day N or -all")
		flag.Usage()
		os.Exit(2)
	}

	w := tabwriter.NewWriter(os.Stdout, 0, 4, 2, ' ', 0)
	fmt.Fprintln(w, "DAY\tNAME\tPART 1\tPART 2\tTIME")
	failed := false
	for _, res := range results {
		if res.Err != nil {
			failed = true
			fmt.Fprintf(w, "%d\t%s\terror: %v\t\t\n", res.Day, res.Name, res.Err)
			continue
		}
		fmt.Fprintf(w, "%d\t%s\t%s\t%s\t%s\n",
			res.Day, res.Name, res.Part1, res.Part2, res.Elapsed.Round(time.Microsecond))
	}
	w.Flush()
	if failed {
		os.Exit(1)
	}
}

// register wires every solver into the registry.
func register(r *runner.Registry) error {
	if err := r.Register(1, solvers.Day1{}); err != nil {
		return err
	}
	return r.Register(2, solvers.Day2{})
}
