package parsing

import "strings"

// CountVowels returns the number of vowel runes in s. A vowel is any rune in
// the set "aeiouAEIOU" plus the accented forms "áéíóúÁÉÍÓÚ".
//
// The count is per rune, not per byte: CountVowels("café") is 2 (the 'a' and
// the two-byte 'é'). All other runes — consonants, digits, punctuation, other
// accented letters — count zero.
func CountVowels(s string) int {
	count := 0
	// range over a string decodes UTF-8: r is a rune, so 'é' is one
	// iteration, not two.
	for _, r := range s {
		if strings.ContainsRune("aeiouAEIOUáéíóúÁÉÍÓÚ", r) {
			count++
		}
	}
	return count
}

// IsPalindrome reports whether s reads the same forwards and backwards when
// compared rune by rune (so multi-byte characters like 'é' or '海' are each
// treated as one unit).
//
// The comparison is exact: case matters, and spaces and punctuation are
// compared like any other rune. The empty string is a palindrome.
func IsPalindrome(s string) bool {
	// []rune(s) decodes the whole string once, giving indexable characters.
	// Comparing s[i] to s[len(s)-1-i] directly would compare bytes and
	// break on any multi-byte rune.
	runes := []rune(s)
	for i, j := 0, len(runes)-1; i < j; i, j = i+1, j-1 {
		if runes[i] != runes[j] {
			return false
		}
	}
	return true
}

// Caesar returns s with every ASCII letter shifted forward by shift positions
// in the alphabet, wrapping around ('z' shifted by 1 is 'a'). Case is
// preserved: 'a'–'z' stay lowercase, 'A'–'Z' stay uppercase.
//
// shift may be negative or larger than 26; it is reduced modulo 26. Every
// non-letter rune (digits, punctuation, spaces, non-ASCII characters like
// 'é') is copied through unchanged.
func Caesar(s string, shift int) string {
	// Go's % can return negative values (-1%26 == -1), so normalize into
	// [0, 26) before shifting.
	k := rune(((shift % 26) + 26) % 26)
	var b strings.Builder
	b.Grow(len(s)) // one allocation: output is at least as long as input
	for _, r := range s {
		switch {
		case 'a' <= r && r <= 'z':
			r = 'a' + (r-'a'+k)%26
		case 'A' <= r && r <= 'Z':
			r = 'A' + (r-'A'+k)%26
		}
		b.WriteRune(r)
	}
	return b.String()
}

// JoinWithAnd joins items into an English-style list:
//
//	nil or empty      -> ""
//	["a"]             -> "a"
//	["a","b"]         -> "a and b"
//	["a","b","c"]     -> "a, b and c"
//	["a","b","c","d"] -> "a, b, c and d"
//
// All items except the last are separated by ", "; the last is attached with
// " and ". Build the result with strings.Builder, not repeated +=.
func JoinWithAnd(items []string) string {
	switch len(items) {
	case 0:
		return ""
	case 1:
		return items[0]
	}
	var b strings.Builder
	for i, item := range items[:len(items)-1] {
		if i > 0 {
			b.WriteString(", ")
		}
		b.WriteString(item)
	}
	b.WriteString(" and ")
	b.WriteString(items[len(items)-1])
	return b.String()
}
