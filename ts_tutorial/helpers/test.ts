/**
 * Tiny runtime checker for exercises you can actually run:
 *
 *   npx tsx lessons/01-types-basics/exercises.ts
 *
 * Prints a green check or a red cross per assertion. This checks runtime
 * VALUES; the helpers in type-assertions.ts check TYPES. Early lessons use
 * both so you can see that types exist only at compile time.
 */

import process from "node:process"

let passed = 0
let failed = 0

export function check(label: string, actual: unknown, expected: unknown): void {
  const a = JSON.stringify(actual)
  const e = JSON.stringify(expected)
  if (a === e) {
    passed++
    console.log(`  \x1b[32m✓\x1b[0m ${label}`)
  } else {
    failed++
    console.log(`  \x1b[31m✗\x1b[0m ${label}`)
    console.log(`      expected: ${e}`)
    console.log(`      received: ${a}`)
  }
}

export function summary(): void {
  console.log(`\n${passed} passed, ${failed} failed`)
  if (failed > 0) process.exitCode = 1
}
