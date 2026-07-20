package runner

import (
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"sync"
	"testing"
	"time"
)

// fakeSolver lets each test define solver behavior inline.
type fakeSolver struct {
	name  string
	solve func(input string) (string, string, error)
}

func (f fakeSolver) Name() string { return f.name }

func (f fakeSolver) Solve(input string) (string, string, error) {
	return f.solve(input)
}

// echoSolver answers with the input as part 1 and its upper-casing as part 2.
func echoSolver(name string) Solver {
	return fakeSolver{name: name, solve: func(in string) (string, string, error) {
		return in, strings.ToUpper(in), nil
	}}
}

func writeInput(t *testing.T, dir string, day int, content string) {
	t.Helper()
	path := filepath.Join(dir, fmt.Sprintf("day%d.txt", day))
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}
}

func mustRegister(t *testing.T, r *Registry, day int, s Solver) {
	t.Helper()
	if err := r.Register(day, s); err != nil {
		t.Fatalf("Register(%d, ...) = %v, want nil", day, err)
	}
}

func TestRegisterAndGet(t *testing.T) {
	r := NewRegistry()
	if r == nil {
		t.Fatal("NewRegistry() = nil, want a usable registry")
	}

	mustRegister(t, r, 1, echoSolver("first"))

	s, err := r.Get(1)
	if err != nil {
		t.Fatalf("Get(1) error = %v, want nil", err)
	}
	if s == nil || s.Name() != "first" {
		t.Fatalf("Get(1) returned wrong solver: %v", s)
	}

	if _, err := r.Get(99); !errors.Is(err, ErrUnknownDay) {
		t.Errorf("Get(99) error = %v, want errors.Is(err, ErrUnknownDay)", err)
	}

	if err := r.Register(1, echoSolver("usurper")); !errors.Is(err, ErrDuplicateDay) {
		t.Errorf("Register(1) twice: error = %v, want errors.Is(err, ErrDuplicateDay)", err)
	}
	if s, _ := r.Get(1); s != nil && s.Name() != "first" {
		t.Errorf("failed Register must not replace the original solver; Get(1).Name() = %q", s.Name())
	}

	if err := r.Register(0, echoSolver("zero")); err == nil {
		t.Error("Register(0, ...) = nil, want an error (days start at 1)")
	}
}

func TestDaysSorted(t *testing.T) {
	r := NewRegistry()
	for _, day := range []int{7, 2, 25, 1} {
		mustRegister(t, r, day, echoSolver(fmt.Sprintf("day %d", day)))
	}
	got := r.Days()
	want := []int{1, 2, 7, 25}
	if !slices.Equal(got, want) {
		t.Errorf("Days() = %v, want %v", got, want)
	}
}

func TestLoadInput(t *testing.T) {
	dir := t.TempDir()
	writeInput(t, dir, 7, "hello world\n")
	writeInput(t, dir, 9, "a\nb\n\n")

	t.Run("reads and trims trailing newline", func(t *testing.T) {
		got, err := LoadInput(dir, 7)
		if err != nil {
			t.Fatalf("LoadInput(dir, 7) error = %v, want nil", err)
		}
		if want := "hello world"; got != want {
			t.Errorf("LoadInput(dir, 7) = %q, want %q", got, want)
		}
	})

	t.Run("trims only trailing newlines, keeps inner ones", func(t *testing.T) {
		got, err := LoadInput(dir, 9)
		if err != nil {
			t.Fatalf("LoadInput(dir, 9) error = %v, want nil", err)
		}
		if want := "a\nb"; got != want {
			t.Errorf("LoadInput(dir, 9) = %q, want %q", got, want)
		}
	})

	t.Run("missing file wraps fs.ErrNotExist", func(t *testing.T) {
		_, err := LoadInput(dir, 8)
		if !errors.Is(err, fs.ErrNotExist) {
			t.Errorf("LoadInput(dir, 8) error = %v, want errors.Is(err, fs.ErrNotExist)", err)
		}
	})
}

func TestRunSingle(t *testing.T) {
	dir := t.TempDir()
	writeInput(t, dir, 2, "abc\n")

	r := NewRegistry()
	mustRegister(t, r, 2, fakeSolver{name: "slowpoke", solve: func(in string) (string, string, error) {
		time.Sleep(5 * time.Millisecond)
		return in, strings.ToUpper(in), nil
	}})

	res := r.Run(2, dir)
	if res.Err != nil {
		t.Fatalf("Run(2, dir).Err = %v, want nil", res.Err)
	}
	if res.Day != 2 {
		t.Errorf("Result.Day = %d, want 2", res.Day)
	}
	if res.Name != "slowpoke" {
		t.Errorf("Result.Name = %q, want %q", res.Name, "slowpoke")
	}
	if res.Part1 != "abc" || res.Part2 != "ABC" {
		t.Errorf("Result parts = %q, %q, want %q, %q (input must be loaded and newline-trimmed)",
			res.Part1, res.Part2, "abc", "ABC")
	}
	if res.Elapsed < 5*time.Millisecond {
		t.Errorf("Result.Elapsed = %v, want >= 5ms (time the Solve call)", res.Elapsed)
	}
}

func TestRunErrors(t *testing.T) {
	dir := t.TempDir()
	writeInput(t, dir, 3, "x\n")
	errBoom := errors.New("boom")

	r := NewRegistry()
	mustRegister(t, r, 3, fakeSolver{name: "exploder", solve: func(string) (string, string, error) {
		return "", "", errBoom
	}})
	mustRegister(t, r, 4, echoSolver("starved")) // no day4.txt on disk

	t.Run("unknown day", func(t *testing.T) {
		res := r.Run(42, dir)
		if !errors.Is(res.Err, ErrUnknownDay) {
			t.Errorf("Run(42).Err = %v, want errors.Is(err, ErrUnknownDay)", res.Err)
		}
	})

	t.Run("missing input", func(t *testing.T) {
		res := r.Run(4, dir)
		if !errors.Is(res.Err, fs.ErrNotExist) {
			t.Errorf("Run(4).Err = %v, want errors.Is(err, fs.ErrNotExist)", res.Err)
		}
	})

	t.Run("solver failure is preserved", func(t *testing.T) {
		res := r.Run(3, dir)
		if !errors.Is(res.Err, errBoom) {
			t.Errorf("Run(3).Err = %v, want the solver's own error", res.Err)
		}
	})
}

func TestRunAllSequential(t *testing.T) {
	dir := t.TempDir()
	r := NewRegistry()
	for _, day := range []int{3, 1, 2} {
		writeInput(t, dir, day, fmt.Sprintf("v%d\n", day))
		mustRegister(t, r, day, echoSolver(fmt.Sprintf("day %d", day)))
	}

	results := r.RunAll(dir)
	if len(results) != 3 {
		t.Fatalf("RunAll returned %d results, want 3", len(results))
	}
	for i, res := range results {
		wantDay := i + 1
		if res.Day != wantDay {
			t.Errorf("results[%d].Day = %d, want %d (ascending day order)", i, res.Day, wantDay)
		}
		if want := fmt.Sprintf("v%d", wantDay); res.Part1 != want {
			t.Errorf("results[%d].Part1 = %q, want %q", i, res.Part1, want)
		}
		if res.Err != nil {
			t.Errorf("results[%d].Err = %v, want nil", i, res.Err)
		}
	}
}

func TestRunAllParallelOrdersResults(t *testing.T) {
	dir := t.TempDir()
	r := NewRegistry()
	days := []int{5, 2, 8, 1}
	for _, day := range days {
		writeInput(t, dir, day, fmt.Sprintf("v%d\n", day))
		// Later days finish first, so sorting the results is mandatory.
		delay := time.Duration(10-day) * 5 * time.Millisecond
		mustRegister(t, r, day, fakeSolver{
			name: fmt.Sprintf("day %d", day),
			solve: func(in string) (string, string, error) {
				time.Sleep(delay)
				return in, strings.ToUpper(in), nil
			},
		})
	}

	results := r.RunAllParallel(dir, 2)
	if len(results) != len(days) {
		t.Fatalf("RunAllParallel returned %d results, want %d", len(results), len(days))
	}
	wantDays := []int{1, 2, 5, 8}
	for i, res := range results {
		if res.Day != wantDays[i] {
			t.Fatalf("results[%d].Day = %d, want %d (sort results by day)", i, res.Day, wantDays[i])
		}
		if want := fmt.Sprintf("v%d", wantDays[i]); res.Part1 != want {
			t.Errorf("results[%d].Part1 = %q, want %q", i, res.Part1, want)
		}
	}
}

func TestRunAllParallelWorkersFloor(t *testing.T) {
	dir := t.TempDir()
	r := NewRegistry()
	writeInput(t, dir, 1, "solo\n")
	mustRegister(t, r, 1, echoSolver("solo"))

	results := r.RunAllParallel(dir, 0) // workers < 1 must still work (as 1)
	if len(results) != 1 || results[0].Part1 != "solo" {
		t.Fatalf("RunAllParallel(dir, 0) = %+v, want one result with Part1 %q", results, "solo")
	}
}

func TestRunAllParallelIsConcurrent(t *testing.T) {
	const n = 6
	dir := t.TempDir()
	r := NewRegistry()

	// Every solver blocks until all n solvers are running at the same time.
	// A sequential implementation deadlocks here (caught by the timeout);
	// a real worker pool with n workers sails through.
	var barrier sync.WaitGroup
	barrier.Add(n)
	for day := 1; day <= n; day++ {
		writeInput(t, dir, day, fmt.Sprintf("v%d\n", day))
		mustRegister(t, r, day, fakeSolver{
			name: fmt.Sprintf("day %d", day),
			solve: func(in string) (string, string, error) {
				barrier.Done()
				barrier.Wait()
				return in, strings.ToUpper(in), nil
			},
		})
	}

	done := make(chan []Result, 1)
	go func() { done <- r.RunAllParallel(dir, n) }()

	select {
	case results := <-done:
		if len(results) != n {
			t.Fatalf("RunAllParallel returned %d results, want %d", len(results), n)
		}
		for i, res := range results {
			if res.Err != nil {
				t.Errorf("results[%d].Err = %v, want nil", i, res.Err)
			}
		}
	case <-time.After(2 * time.Second):
		t.Fatal("RunAllParallel(dir, 6) timed out — with 6 workers, all 6 solvers must run concurrently")
	}
}
