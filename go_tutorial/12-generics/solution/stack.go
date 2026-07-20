package generics

// Stack is a last-in-first-out stack of values of type T.
// The zero value of Stack is an empty stack, ready to use:
//
//	var s Stack[int]
//	s.Push(1)
type Stack[T any] struct {
	items []T
}

// Push adds v to the top of the stack.
func (s *Stack[T]) Push(v T) {
	s.items = append(s.items, v)
}

// Pop removes and returns the top element of the stack (the most recently
// pushed one) and true. If the stack is empty, it returns the zero value
// of T and false.
func (s *Stack[T]) Pop() (T, bool) {
	var zero T
	if len(s.items) == 0 {
		return zero, false
	}
	n := len(s.items) - 1
	top := s.items[n]
	// Overwrite the vacated slot so that if T holds pointers, the popped
	// value doesn't linger in the backing array and block the GC.
	s.items[n] = zero
	s.items = s.items[:n]
	return top, true
}

// Len returns the number of elements currently on the stack.
func (s *Stack[T]) Len() int {
	return len(s.items)
}
