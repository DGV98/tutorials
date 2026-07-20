#!/usr/bin/env node
/**
 * Per-lesson type checker.
 *
 *   ./check              type-check the whole course
 *   ./check 03           type-check lesson 03 only (exercises + solution)
 *   ./check 03 --watch   re-check lesson 03 on every save
 *   ./check solutions    type-check only the solution files (should be clean)
 *
 * Works by writing a throwaway tsconfig that extends the root one with a
 * narrower `include`, then running tsc against it.
 */
import { readdirSync, writeFileSync } from "node:fs"
import { spawnSync } from "node:child_process"
import { join, dirname } from "node:path"
import { fileURLToPath } from "node:url"

const root = join(dirname(fileURLToPath(import.meta.url)), "..")
const args = process.argv.slice(2)
const watch = args.includes("--watch") || args.includes("-w")
const target = args.find((a) => !a.startsWith("-"))

const TEMP = ".check-lesson.tsconfig.json"

function run(tscArgs) {
  const result = spawnSync("npx", ["tsc", ...tscArgs], {
    cwd: root,
    stdio: "inherit",
  })
  process.exit(result.status ?? 1)
}

if (!target || target === "all") {
  run(watch ? ["-p", ".", "--watch"] : ["-p", "."])
}

let include
if (target === "solutions") {
  include = [
    "lessons/*/solution.ts",
    "lessons/*/solution.tsx",
    "lessons/*/solution/*",
    "helpers",
  ]
} else {
  const num = target.padStart(2, "0")
  const lessons = readdirSync(join(root, "lessons"))
  const dir = lessons.find((d) => d.startsWith(`${num}-`))
  if (!dir) {
    console.error(`No lesson matching "${num}" under lessons/. Try: ./check 01`)
    process.exit(1)
  }
  include = [`lessons/${dir}`, "helpers"]
  console.log(`Checking lessons/${dir}\n`)
}

writeFileSync(
  join(root, TEMP),
  JSON.stringify({ extends: "./tsconfig.json", include }, null, 2),
)
run(watch ? ["-p", TEMP, "--watch"] : ["-p", TEMP])
