/**
 * Lesson 03 — exercises.
 *
 * This file intentionally does not type-check. Work top to bottom, fixing
 * each exercise until `./check 03` reports zero errors. Never edit lines
 * containing Expect<Equal<...>> — they are the assertions you're satisfying.
 *
 * Then run it:  npx tsx lessons/03-functions/exercises.ts
 */
import type { Expect, Equal } from "../../helpers/type-assertions";
import { check, summary } from "../../helpers/test";

// ---------------------------------------------------------------------------
// Exercise 1 — Annotate the parameters.
// A parameter has no value to infer from — nothing has called the function
// yet — so under strict mode un-annotated parameters are an error
// ("implicitly has an 'any' type"). Annotate both. Leave the return type
// alone: hover areaOfRect and see that TypeScript infers it.
// ---------------------------------------------------------------------------

function areaOfRect(width: number, height: number) {
  return width * height;
}

const area = areaOfRect(6, 7);

type _e1 = Expect<Equal<typeof area, number>>;
check("area of a 6x7 rectangle", area, 42);

// ---------------------------------------------------------------------------
// Exercise 2 — The annotation caught a bug; fix the bug.
// describeScore PROMISES a string, and one branch breaks that promise. Fix
// the last return so low scores read `failed: <score>` (e.g. "failed: 20").
// Do NOT remove or loosen the return annotation — it is doing its job:
// the error lands here at the source, not at some far-away call site.
// ---------------------------------------------------------------------------

function describeScore(score: number): string {
  if (score >= 90) return "excellent";
  if (score >= 50) return "passing";
  return `failed: ${score}`;
}

check("a great score", describeScore(95), "excellent");
check("a decent score", describeScore(70), "passing");
check("a failing score", describeScore(20), "failed: 20");

// ---------------------------------------------------------------------------
// Exercise 3 — Optional and default parameters.
// Every CALL below is correct — fix the SIGNATURES, not the calls.
//   3a. greet is usually called without punctuation: give `punctuation` a
//       default value of "." instead of requiring it.
//   3b. Not everyone has a middle name: make `middle` optional with `?`.
//       (It already sits last in the list — optional params must be last.)
//       Inside the body, hover `middle` after the fix: `?` means the type
//       is `string | undefined` in there.
// ---------------------------------------------------------------------------

function greet(name: string, punctuation = ".") {
  return `Hello, ${name}${punctuation}`;
}

const casual = greet("Ada");
const excited = greet("Ada", "!");

check("greet falls back to a period", casual, "Hello, Ada.");
check("greet accepts punctuation", excited, "Hello, Ada!");

function fullName(first: string, last: string, middle?: string) {
  type _e3 = Expect<Equal<typeof middle, string | undefined>>;
  return middle ? `${first} ${middle} ${last}` : `${first} ${last}`;
}

check("no middle name", fullName("Grace", "Hopper"), "Grace Hopper");
check(
  "with middle name",
  fullName("Grace", "Hopper", "Brewster"),
  "Grace Brewster Hopper",
);

// ---------------------------------------------------------------------------
// Exercise 4 — Rest parameters.
// sum should accept ANY number of numbers. A rest parameter gathers its
// arguments into an array, so its annotation must be an ARRAY type — right
// now it's an implicit any[]. Annotate it. Then hover `acc` and `n` in the
// reduce callback: no annotations needed there — that's contextual typing.
// ---------------------------------------------------------------------------

function sum(...values: number[]) {
  return values.reduce((acc, n) => acc + n, 0);
}

const total = sum(1, 2, 3, 4);

type _e4 = Expect<Equal<typeof total, number>>;
check("sum of four numbers", total, 10);
check("sum of no numbers", sum(), 0);

// ---------------------------------------------------------------------------
// Exercise 5 — Type the callback with a function type expression.
// forEachUser runs `callback` once per id, passing the id along. Give
// `callback` a function type expression: takes a string id, returns nothing.
// Do NOT annotate `user` down at the call site — once the declaration is
// right, contextual typing infers it for free (hover `user` and watch it
// switch from any to string).
// ---------------------------------------------------------------------------

function forEachUser(ids: string[], callback: (id: string) => void) {
  for (const id of ids) {
    callback(id);
  }
}

const notified: string[] = [];
forEachUser(["ada", "grace"], (user) => {
  type _e5 = Expect<Equal<typeof user, string>>;
  notified.push(user.toUpperCase());
});

check("every user was notified", notified, ["ADA", "GRACE"]);

// ---------------------------------------------------------------------------
// Exercise 6 — void: "any return value will be ignored."
// Two things to see, ONE thing to fix:
//   • NOT a bug: the listener arrow returns a number (push returns the new
//     length), yet it's accepted where `(message: string) => void` is
//     expected. That's the void assignability rule — leave that line alone.
//   • THE bug: emit claims to return `number` but returns nothing. It's
//     fire-and-forget — fix its return type annotation.
// ---------------------------------------------------------------------------

type Listener = (message: string) => void;

const listeners: Listener[] = [];

function addListener(listener: Listener): void {
  listeners.push(listener);
}

const received: string[] = [];
addListener((message) => received.push(message));

function emit(message: string): void {
  for (const listener of listeners) {
    listener(message);
  }
}

const result = emit("deploy finished");

type _e6 = Expect<Equal<typeof result, void>>;
check("the listener heard it", received, ["deploy finished"]);

// ---------------------------------------------------------------------------
// Exercise 7 — never: "this function does not return, period."
// crash() always throws. But with no annotation, TypeScript infers `void`
// for it ("returns, carrying nothing") — a lie, and it breaks parseBoolean:
// the checker can't tell that the last line makes the end of the function
// unreachable. Annotate crash's return type as `never`. One annotation,
// and both errors disappear.
// ---------------------------------------------------------------------------

function crash(message: string): never {
  throw new Error(message);
}

type _e7 = Expect<Equal<typeof crash, (message: string) => never>>;

function parseBoolean(input: string): boolean {
  if (input === "true") return true;
  if (input === "false") return false;
  crash(`expected "true" or "false", got "${input}"`);
}

check("parses true", parseBoolean("true"), true);
check("parses false", parseBoolean("false"), false);

// ---------------------------------------------------------------------------
summary();
export {};
