package errs

import (
	"errors"
	"strconv"
	"strings"
	"testing"
)

func TestSafeDivide(t *testing.T) {
	tests := []struct {
		name    string
		a, b    float64
		want    float64
		wantErr bool
	}{
		{"exact division", 10, 2, 5, false},
		{"fractional result", 1, 4, 0.25, false},
		{"negative divisor", 9, -3, -3, false},
		{"zero numerator", 0, 5, 0, false},
		{"divide by zero", 7, 0, 0, true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := SafeDivide(tt.a, tt.b)
			if (err != nil) != tt.wantErr {
				t.Fatalf("SafeDivide(%v, %v) error = %v, want error: %t",
					tt.a, tt.b, err, tt.wantErr)
			}
			if got != tt.want {
				t.Errorf("SafeDivide(%v, %v) = %v, want %v", tt.a, tt.b, got, tt.want)
			}
		})
	}

	// Error messages follow the Go convention: lowercase, no
	// trailing punctuation.
	if _, err := SafeDivide(1, 0); err != nil && err.Error() != "division by zero" {
		t.Errorf(`SafeDivide(1, 0) error message = %q, want "division by zero"`, err.Error())
	}
}

func TestParseAge(t *testing.T) {
	t.Run("valid input", func(t *testing.T) {
		tests := []struct {
			s    string
			want int
		}{
			{"0", 0},
			{"42", 42},
			{"150", 150},
		}
		for _, tt := range tests {
			got, err := ParseAge(tt.s)
			if err != nil {
				t.Errorf("ParseAge(%q) error = %v, want nil", tt.s, err)
				continue
			}
			if got != tt.want {
				t.Errorf("ParseAge(%q) = %d, want %d", tt.s, got, tt.want)
			}
		}
	})

	t.Run("garbage wraps the strconv error", func(t *testing.T) {
		_, err := ParseAge("abc")
		if err == nil {
			t.Fatal(`ParseAge("abc") error = nil, want non-nil`)
		}
		// Because the wrap used %w, errors.Is can still see strconv's
		// sentinel underneath the added context.
		if !errors.Is(err, strconv.ErrSyntax) {
			t.Errorf(`ParseAge("abc") error = %v, want errors.Is(err, strconv.ErrSyntax) to be true`, err)
		}
		if !strings.Contains(err.Error(), `"abc"`) {
			t.Errorf(`ParseAge("abc") error = %q, want the quoted input "abc" in the message`, err.Error())
		}
	})

	t.Run("overflow wraps the strconv error", func(t *testing.T) {
		huge := "99999999999999999999"
		_, err := ParseAge(huge)
		if !errors.Is(err, strconv.ErrRange) {
			t.Errorf("ParseAge(%q) error = %v, want errors.Is(err, strconv.ErrRange) to be true",
				huge, err)
		}
	})

	t.Run("negative age is a plain error", func(t *testing.T) {
		_, err := ParseAge("-3")
		if err == nil {
			t.Fatal(`ParseAge("-3") error = nil, want non-nil`)
		}
		if got, want := err.Error(), "age -3 must not be negative"; got != want {
			t.Errorf(`ParseAge("-3") error = %q, want %q`, got, want)
		}
		// "-3" parsed fine; the error must not claim a syntax problem.
		if errors.Is(err, strconv.ErrSyntax) {
			t.Error(`ParseAge("-3") error wraps strconv.ErrSyntax, want a plain validation error`)
		}
	})

	t.Run("failures return the zero value", func(t *testing.T) {
		if got, _ := ParseAge("xyz"); got != 0 {
			t.Errorf(`ParseAge("xyz") = %d, want 0`, got)
		}
	})
}

func TestLookup(t *testing.T) {
	inventory := map[string]int{"torch": 3, "rope": 1, "lantern": 0}

	t.Run("present key", func(t *testing.T) {
		got, err := Lookup(inventory, "torch")
		if err != nil {
			t.Fatalf(`Lookup(inventory, "torch") error = %v, want nil`, err)
		}
		if got != 3 {
			t.Errorf(`Lookup(inventory, "torch") = %d, want 3`, got)
		}
	})

	t.Run("present key storing zero", func(t *testing.T) {
		// A stored 0 must not be mistaken for "absent".
		got, err := Lookup(inventory, "lantern")
		if err != nil {
			t.Fatalf(`Lookup(inventory, "lantern") error = %v, want nil`, err)
		}
		if got != 0 {
			t.Errorf(`Lookup(inventory, "lantern") = %d, want 0`, got)
		}
	})

	t.Run("absent key", func(t *testing.T) {
		_, err := Lookup(inventory, "xyzzy")
		if err == nil {
			t.Fatal(`Lookup(inventory, "xyzzy") error = nil, want non-nil`)
		}
		// errors.Is, not ==: the sentinel arrives wrapped in context.
		if !errors.Is(err, ErrNotFound) {
			t.Errorf(`Lookup(inventory, "xyzzy") error = %v, want errors.Is(err, ErrNotFound) to be true`, err)
		}
		if err == ErrNotFound {
			t.Error(`Lookup returned the bare sentinel; wrap it with context via fmt.Errorf and %w`)
		}
		if want := `lookup "xyzzy": not found`; err.Error() != want {
			t.Errorf(`Lookup(inventory, "xyzzy") error = %q, want %q`, err.Error(), want)
		}
	})

	t.Run("nil map", func(t *testing.T) {
		// Reading a nil map is safe in Go; every key is simply absent.
		_, err := Lookup(nil, "anything")
		if !errors.Is(err, ErrNotFound) {
			t.Errorf(`Lookup(nil, "anything") error = %v, want errors.Is(err, ErrNotFound) to be true`, err)
		}
	})
}

func TestValidationErrorError(t *testing.T) {
	tests := []struct {
		name string
		err  *ValidationError
		want string
	}{
		{"name field", &ValidationError{Field: "name", Reason: "must not be empty"},
			"name: must not be empty"},
		{"age field", &ValidationError{Field: "age", Reason: "must be between 0 and 150"},
			"age: must be between 0 and 150"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := tt.err.Error(); got != tt.want {
				t.Errorf("(&ValidationError{%q, %q}).Error() = %q, want %q",
					tt.err.Field, tt.err.Reason, got, tt.want)
			}
		})
	}
}

func TestValidateUser(t *testing.T) {
	t.Run("valid user", func(t *testing.T) {
		if err := ValidateUser("Ada", 36); err != nil {
			t.Errorf(`ValidateUser("Ada", 36) = %v, want nil`, err)
		}
	})

	tests := []struct {
		name       string
		user       string
		age        int
		wantField  string
		wantReason string
	}{
		{"empty name", "", 30, "name", "must not be empty"},
		{"negative age", "Ada", -1, "age", "must be between 0 and 150"},
		{"age too large", "Ada", 200, "age", "must be between 0 and 150"},
		{"name is checked first", "", -1, "name", "must not be empty"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := ValidateUser(tt.user, tt.age)
			if err == nil {
				t.Fatalf("ValidateUser(%q, %d) = nil, want a *ValidationError",
					tt.user, tt.age)
			}
			// errors.As finds the concrete type in the chain and fills
			// in the target pointer, giving access to the fields.
			var ve *ValidationError
			if !errors.As(err, &ve) {
				t.Fatalf("ValidateUser(%q, %d) = %v (type %T), want a *ValidationError extractable with errors.As",
					tt.user, tt.age, err, err)
			}
			if ve.Field != tt.wantField || ve.Reason != tt.wantReason {
				t.Errorf("ValidateUser(%q, %d) = {Field: %q, Reason: %q}, want {Field: %q, Reason: %q}",
					tt.user, tt.age, ve.Field, ve.Reason, tt.wantField, tt.wantReason)
			}
		})
	}
}

func TestChain(t *testing.T) {
	t.Run("nil in, nil out", func(t *testing.T) {
		if err := Chain(nil); err != nil {
			t.Errorf("Chain(nil) = %v, want nil", err)
		}
	})

	t.Run("context accumulates outermost first", func(t *testing.T) {
		err := Chain(errors.New("boom"))
		if err == nil {
			t.Fatal(`Chain(errors.New("boom")) = nil, want non-nil`)
		}
		if got, want := err.Error(), "outer: inner: boom"; got != want {
			t.Errorf(`Chain(errors.New("boom")).Error() = %q, want %q`, got, want)
		}
	})

	t.Run("errors.Is sees through both layers", func(t *testing.T) {
		base := errors.New("boom")
		if err := Chain(base); !errors.Is(err, base) {
			t.Errorf("errors.Is(Chain(base), base) = false, want true")
		}
		if err := Chain(ErrNotFound); !errors.Is(err, ErrNotFound) {
			t.Errorf("errors.Is(Chain(ErrNotFound), ErrNotFound) = false, want true")
		}
	})

	t.Run("errors.As sees through both layers", func(t *testing.T) {
		err := Chain(&ValidationError{Field: "age", Reason: "must be between 0 and 150"})
		var ve *ValidationError
		if !errors.As(err, &ve) {
			t.Fatalf("errors.As(Chain(&ValidationError{...}), &ve) = false, want true (err = %v)", err)
		}
		if ve.Field != "age" {
			t.Errorf("extracted ValidationError.Field = %q, want %q", ve.Field, "age")
		}
	})
}

func TestDontPanic(t *testing.T) {
	t.Run("no panic returns nil", func(t *testing.T) {
		called := false
		err := DontPanic(func() { called = true })
		if err != nil {
			t.Errorf("DontPanic(calm func) = %v, want nil", err)
		}
		if !called {
			t.Error("DontPanic did not call f")
		}
	})

	tests := []struct {
		name string
		f    func()
		want string
	}{
		{"panic with string", func() { panic("boom") }, "panic: boom"},
		{"panic with int", func() { panic(42) }, "panic: 42"},
		{"panic with error", func() { panic(errors.New("kaboom")) }, "panic: kaboom"},
		{"runtime panic", func() {
			var xs []int
			_ = xs[3]
		}, "panic: runtime error: index out of range [3] with length 0"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := DontPanic(tt.f)
			if err == nil {
				t.Fatalf("DontPanic(%s) = nil, want error with message %q", tt.name, tt.want)
			}
			if err.Error() != tt.want {
				t.Errorf("DontPanic(%s) = %q, want %q", tt.name, err.Error(), tt.want)
			}
		})
	}
}
