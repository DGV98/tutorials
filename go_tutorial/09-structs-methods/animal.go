package records

// Animal is a basic creature. It exists to be embedded in more specific
// types, which then inherit — no, wait, Go has no inheritance — which
// then *contain* an Animal and get its methods promoted for free.
type Animal struct {
	Name string
}

// Speak returns the string "<Name> makes a sound",
// e.g. Animal{Name: "Rex"}.Speak() == "Rex makes a sound".
func (a Animal) Speak() string {
	// TODO: implement
	return ""
}

// Describe returns the string "<Name> is an animal",
// e.g. Animal{Name: "Rex"}.Describe() == "Rex is an animal".
func (a Animal) Describe() string {
	// TODO: implement
	return ""
}

// Dog embeds Animal. The embedded field gives Dog all of Animal's fields
// and methods "promoted" onto itself: d.Name means d.Animal.Name, and
// d.Describe() calls the promoted Animal.Describe. This is composition —
// a Dog HAS an Animal inside it — not inheritance.
type Dog struct {
	Animal
	Breed string
}

// Speak returns the string "<Name> says woof",
// e.g. a Dog named "Rex" speaks "Rex says woof".
//
// Defining Speak on Dog shadows the promoted Animal.Speak for Dog values;
// the original stays reachable as d.Animal.Speak().
func (d Dog) Speak() string {
	// TODO: implement
	return ""
}
