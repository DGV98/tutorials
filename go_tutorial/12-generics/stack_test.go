package generics

import "testing"

func TestStackPushPop(t *testing.T) {
	var s Stack[int]
	s.Push(1)
	s.Push(2)
	s.Push(3)
	for _, want := range []int{3, 2, 1} {
		got, ok := s.Pop()
		if !ok || got != want {
			t.Fatalf("Pop() = (%d, %t), want (%d, true)", got, ok, want)
		}
	}
	if got, ok := s.Pop(); ok {
		t.Errorf("Pop() on emptied stack = (%d, %t), want (0, false)", got, ok)
	}
}

func TestStackPopEmpty(t *testing.T) {
	var s Stack[string]
	got, ok := s.Pop()
	if ok || got != "" {
		t.Errorf(`Pop() on empty Stack[string] = (%q, %t), want ("", false)`, got, ok)
	}
}

func TestStackLen(t *testing.T) {
	var s Stack[rune]
	if got := s.Len(); got != 0 {
		t.Errorf("Len() of empty stack = %d, want 0", got)
	}
	s.Push('(')
	s.Push('[')
	if got := s.Len(); got != 2 {
		t.Errorf("Len() after 2 pushes = %d, want 2", got)
	}
	s.Pop()
	if got := s.Len(); got != 1 {
		t.Errorf("Len() after 2 pushes and 1 pop = %d, want 1", got)
	}
}

func TestStackInterleaved(t *testing.T) {
	var s Stack[string]
	s.Push("a")
	s.Push("b")
	if got, ok := s.Pop(); !ok || got != "b" {
		t.Fatalf("Pop() = (%q, %t), want (%q, true)", got, ok, "b")
	}
	s.Push("c")
	for _, want := range []string{"c", "a"} {
		got, ok := s.Pop()
		if !ok || got != want {
			t.Fatalf("Pop() = (%q, %t), want (%q, true)", got, ok, want)
		}
	}
	if got := s.Len(); got != 0 {
		t.Errorf("Len() after draining stack = %d, want 0", got)
	}
}

func TestStackStructElements(t *testing.T) {
	type point struct{ x, y int }
	var s Stack[point]
	s.Push(point{1, 2})
	got, ok := s.Pop()
	if want := (point{1, 2}); !ok || got != want {
		t.Errorf("Pop() = (%+v, %t), want (%+v, true)", got, ok, want)
	}
	// The zero value of T comes back once the stack is empty.
	got, ok = s.Pop()
	if want := (point{}); ok || got != want {
		t.Errorf("Pop() on empty Stack[point] = (%+v, %t), want (%+v, false)", got, ok, want)
	}
}
