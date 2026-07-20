package parsing

import "testing"

func TestCountVowels(t *testing.T) {
	tests := []struct {
		name  string
		input string
		want  int
	}{
		{"simple word", "hello", 2},
		{"mixed case", "AeIoU", 5},
		{"no vowels", "rhythm", 0},
		{"accented vowels count as one each", "café", 2},
		{"spanish word", "Canción", 3},
		{"other multi-byte runes are not vowels", "日本語", 0},
		{"empty string", "", 0},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := CountVowels(tt.input); got != tt.want {
				t.Errorf("CountVowels(%q) = %d, want %d", tt.input, got, tt.want)
			}
		})
	}
}

func TestIsPalindrome(t *testing.T) {
	tests := []struct {
		name  string
		input string
		want  bool
	}{
		{"classic", "racecar", true},
		{"empty string", "", true},
		{"single rune", "x", true},
		{"two different runes", "ab", false},
		{"multi-byte palindrome", "été", true},
		{"cjk palindrome", "上海海上", true},
		{"multi-byte non-palindrome", "éa", false},
		{"case matters", "Racecar", false},
		{"not a palindrome", "gopher", false},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := IsPalindrome(tt.input); got != tt.want {
				t.Errorf("IsPalindrome(%q) = %t, want %t", tt.input, got, tt.want)
			}
		})
	}
}

func TestCaesar(t *testing.T) {
	tests := []struct {
		name  string
		input string
		shift int
		want  string
	}{
		{"shift by one", "abc", 1, "bcd"},
		{"wrap around z", "xyz", 3, "abc"},
		{"rot13 with punctuation", "Hello, World!", 13, "Uryyb, Jbeyq!"},
		{"negative shift", "bcd", -1, "abc"},
		{"shift larger than alphabet", "abc", 27, "bcd"},
		{"zero shift", "already fine", 0, "already fine"},
		{"non-ascii passes through", "héllo", 1, "iémmp"},
		{"digits unchanged", "a1b2", 2, "c1d2"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := Caesar(tt.input, tt.shift); got != tt.want {
				t.Errorf("Caesar(%q, %d) = %q, want %q", tt.input, tt.shift, got, tt.want)
			}
		})
	}
}

func TestJoinWithAnd(t *testing.T) {
	tests := []struct {
		name  string
		input []string
		want  string
	}{
		{"empty", nil, ""},
		{"one item", []string{"a"}, "a"},
		{"two items", []string{"a", "b"}, "a and b"},
		{"three items", []string{"a", "b", "c"}, "a, b and c"},
		{"four items", []string{"gold", "myrrh", "rope", "sand"}, "gold, myrrh, rope and sand"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := JoinWithAnd(tt.input); got != tt.want {
				t.Errorf("JoinWithAnd(%q) = %q, want %q", tt.input, got, tt.want)
			}
		})
	}
}
