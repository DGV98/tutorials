// A tiny runnable program used by the module 1 README to demonstrate
// go run, go build, and the essential fmt verbs. From the repository
// root, try:
//
//	go run ./01-hello/demo
package main

import "fmt"

func main() {
	fmt.Println("Hello, Go!") // Println adds a trailing newline

	name, stars, ratio := "Gopher", 50, 0.98765

	fmt.Printf("%v\n", name)      // Gopher      (%v: default format, works for anything)
	fmt.Printf("%d\n", stars)     // 50          (%d: base-10 integer)
	fmt.Printf("%s\n", name)      // Gopher      (%s: plain string)
	fmt.Printf("%f\n", ratio)     // 0.987650    (%f: decimal float, 6 digits by default)
	fmt.Printf("%.2f\n", ratio)   // 0.99        (%.2f: 2 digits after the point, rounded)
	fmt.Printf("%q\n", name)      // "Gopher"    (%q: quoted + escaped, like Go source)
	fmt.Printf("%T\n", ratio)     // float64     (%T: the TYPE of the value)
	fmt.Printf("%x\n", 255)       // ff          (%x: lowercase hexadecimal)
	fmt.Printf("[%5d]\n", stars)  // [   50]     (width 5, right-aligned)
	fmt.Printf("[%-10s]\n", name) // [Gopher    ] (width 10, minus = left-aligned)

	// Sprintf formats the same way but RETURNS the string instead of
	// printing it — that's what every exercise in this module uses.
	line := fmt.Sprintf("%-10s|%5d", name, stars)
	fmt.Println(line) // Gopher    |   50
}
