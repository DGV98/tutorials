package records

// Inventory tracks how many of each item you hold, keyed by item name.
// Unlike Counter, the zero value is NOT ready to use: the internal map
// must be allocated first. That is exactly what the NewInventory
// constructor is for — always create an Inventory with it.
type Inventory struct {
	items map[string]int
}

// NewInventory returns an empty, ready-to-use Inventory with its internal
// map allocated. It returns a pointer because Inventory's methods have
// pointer receivers.
func NewInventory() *Inventory {
	// TODO: implement
	return nil
}

// Add records qty more of item name. Adding a name that is already
// present accumulates. Calls with qty <= 0 change nothing.
func (inv *Inventory) Add(name string, qty int) {
	// TODO: implement
}

// Remove takes qty of item name out of the inventory and reports whether
// it succeeded. If qty <= 0, or the inventory holds fewer than qty of
// name, Remove changes nothing and returns false.
func (inv *Inventory) Remove(name string, qty int) bool {
	// TODO: implement
	return false
}

// Total returns the sum of the quantities of every item held. An empty
// inventory has a total of 0.
func (inv *Inventory) Total() int {
	// TODO: implement
	return 0
}
