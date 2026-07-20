package runner

// LoadInput reads the puzzle input for the given day from dir.
// Inputs live in files named day1.txt, day2.txt, ... inside dir.
//
// The returned string has any trailing newline characters stripped
// (editors and generators leave a final "\n"; solvers shouldn't care).
// On failure the error must wrap the underlying os error — with %w, so
// callers can still test errors.Is(err, fs.ErrNotExist) — and add the
// day number as context.
func LoadInput(dir string, day int) (string, error) {
	// TODO: implement
	return "", nil
}
