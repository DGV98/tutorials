package records

import "testing"

func TestAnimalSpeak(t *testing.T) {
	a := Animal{Name: "Rex"}
	if got, want := a.Speak(), "Rex makes a sound"; got != want {
		t.Errorf("Speak() = %q, want %q", got, want)
	}
}

func TestAnimalDescribe(t *testing.T) {
	a := Animal{Name: "Rex"}
	if got, want := a.Describe(), "Rex is an animal"; got != want {
		t.Errorf("Describe() = %q, want %q", got, want)
	}
}

// TestDogSpeakOverride checks that Dog's own Speak shadows the promoted
// Animal.Speak — and that the shadowed method is still reachable through
// the embedded field.
func TestDogSpeakOverride(t *testing.T) {
	d := Dog{Animal: Animal{Name: "Rex"}, Breed: "corgi"}
	if got, want := d.Speak(), "Rex says woof"; got != want {
		t.Errorf("Dog.Speak() = %q, want %q", got, want)
	}
	if got, want := d.Animal.Speak(), "Rex makes a sound"; got != want {
		t.Errorf("Dog.Animal.Speak() = %q, want %q", got, want)
	}
}

// TestDogDescribePromoted checks method promotion: Dog defines no Describe
// of its own, so calling d.Describe() must reach Animal.Describe through
// the embedded field.
func TestDogDescribePromoted(t *testing.T) {
	d := Dog{Animal: Animal{Name: "Bea"}, Breed: "beagle"}
	if got, want := d.Describe(), "Bea is an animal"; got != want {
		t.Errorf("Dog.Describe() = %q, want %q", got, want)
	}
	if got, want := d.Name, "Bea"; got != want { // field promotion, too
		t.Errorf("Dog.Name = %q, want %q", got, want)
	}
}
