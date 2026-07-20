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
	return &Inventory{items: make(map[string]int)}
}

// Add records qty more of item name. Adding a name that is already
// present accumulates. Calls with qty <= 0 change nothing.
func (inv *Inventory) Add(name string, qty int) {
	if qty <= 0 {
		return
	}
	inv.items[name] += qty
}

// Remove takes qty of item name out of the inventory and reports whether
// it succeeded. If qty <= 0, or the inventory holds fewer than qty of
// name, Remove changes nothing and returns false.
func (inv *Inventory) Remove(name string, qty int) bool {
	if qty <= 0 || inv.items[name] < qty {
		return false
	}
	inv.items[name] -= qty
	if inv.items[name] == 0 {
		delete(inv.items, name) // don't let sold-out items linger as zeros
	}
	return true
}

// Total returns the sum of the quantities of every item held. An empty
// inventory has a total of 0.
func (inv *Inventory) Total() int {
	total := 0
	for _, qty := range inv.items {
		total += qty
	}
	return total
}
