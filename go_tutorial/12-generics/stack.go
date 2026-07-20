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
	// TODO: implement
}

// Pop removes and returns the top element of the stack (the most recently
// pushed one) and true. If the stack is empty, it returns the zero value
// of T and false.
func (s *Stack[T]) Pop() (T, bool) {
	// TODO: implement
	var zero T
	return zero, false
}

// Len returns the number of elements currently on the stack.
func (s *Stack[T]) Len() int {
	// TODO: implement
	return 0
}
