package records

import "testing"

// mustNewInventory fails the test immediately if the constructor is not
// implemented, instead of letting later method calls panic on a nil map.
func mustNewInventory(t *testing.T) *Inventory {
	t.Helper()
	inv := NewInventory()
	if inv == nil {
		t.Fatal("NewInventory() = nil, want a ready-to-use *Inventory")
	}
	return inv
}

func TestNewInventory(t *testing.T) {
	inv := mustNewInventory(t)
	if got := inv.Total(); got != 0 {
		t.Errorf("Total() on a new inventory = %d, want 0", got)
	}
	inv.Add("torch", 1) // must not panic: the internal map must be allocated
	if got := inv.Total(); got != 1 {
		t.Errorf("Total() after Add(\"torch\", 1) = %d, want 1", got)
	}
}

func TestInventoryAddAndTotal(t *testing.T) {
	inv := mustNewInventory(t)
	inv.Add("ore", 3)
	inv.Add("wood", 2)
	inv.Add("ore", 4)   // same name accumulates
	inv.Add("dust", 0)  // qty <= 0 is ignored
	inv.Add("dust", -5) // qty <= 0 is ignored
	if got := inv.Total(); got != 9 {
		t.Errorf("Total() after adding 3+4 ore and 2 wood = %d, want 9", got)
	}
}

func TestInventoryRemove(t *testing.T) {
	tests := []struct {
		name      string
		stock     map[string]int // loaded via Add before the Remove call
		item      string
		qty       int
		wantOK    bool
		wantTotal int
	}{
		{"exact stock", map[string]int{"ore": 3}, "ore", 3, true, 0},
		{"partial stock", map[string]int{"ore": 5}, "ore", 2, true, 3},
		{"insufficient stock", map[string]int{"ore": 1}, "ore", 2, false, 1},
		{"missing item", map[string]int{"wood": 4}, "ore", 1, false, 4},
		{"non-positive qty", map[string]int{"ore": 3}, "ore", 0, false, 3},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			inv := mustNewInventory(t)
			for name, qty := range tt.stock {
				inv.Add(name, qty)
			}
			if ok := inv.Remove(tt.item, tt.qty); ok != tt.wantOK {
				t.Errorf("Remove(%q, %d) = %t, want %t", tt.item, tt.qty, ok, tt.wantOK)
			}
			if got := inv.Total(); got != tt.wantTotal {
				t.Errorf("Total() after Remove(%q, %d) = %d, want %d", tt.item, tt.qty, got, tt.wantTotal)
			}
		})
	}
}
