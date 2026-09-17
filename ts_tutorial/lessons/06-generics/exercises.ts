/**
 * Lesson 06 — exercises.
 *
 * This file intentionally does not type-check. Work top to bottom, fixing
 * each exercise until `./check 06` reports zero errors. Never edit lines
 * containing Expect<Equal<...>> — they are the assertions you're satisfying.
 *
 * Then run it:  npx tsx lessons/06-generics/exercises.ts
 */
import type { Expect, Equal } from "../../helpers/type-assertions";
import { check, summary } from "../../helpers/test";

// ---------------------------------------------------------------------------
// Exercise 1 — From unknown to generic.
// firstItem accepts any array but its `unknown` typing throws the element
// type away on the way out. Make it generic — <T>(items: T[]): T — so each
// call site keeps its own type. Fix the function; don't touch the calls.
// ---------------------------------------------------------------------------

function firstItem<T>(items: T[]): T {
  return items[0];
}

const firstTag = firstItem(["urgent", "bug", "ui"]);
const firstScore = firstItem([98, 87, 91]);

type _e1a = Expect<Equal<typeof firstTag, string>>;
type _e1b = Expect<Equal<typeof firstScore, number>>;

check("firstTag keeps its string type", firstTag, "urgent");
check("firstScore keeps its number type", firstScore, 98);

// ---------------------------------------------------------------------------
// Exercise 2 — Explicit type arguments.
// lastOf is already correctly generic — the problems are at the call sites.
// (a) `lastQueued` is built from an empty array: inference has nothing to
//     look at, so T becomes never. Pass the type argument explicitly.
// (b) whoever called lastOf for `lastMeeting` guessed the wrong explicit
//     type argument. Fix the type argument, not the array.
// ---------------------------------------------------------------------------

function lastOf<T>(items: T[]): T | undefined {
  return items[items.length - 1];
}

const lastQueued = lastOf<string>([]);
const lastMeeting = lastOf<string>(["standup", "retro"]);

type _e2a = Expect<Equal<typeof lastQueued, string | undefined>>;
type _e2b = Expect<Equal<typeof lastMeeting, string | undefined>>;

check("nothing queued yet", lastQueued, undefined);
check("last meeting of the day", lastMeeting, "retro");

// ---------------------------------------------------------------------------
// Exercise 3 — Multiple type parameters.
// mapItems was written for one use case and hardcodes string → string. Make
// it generic over the input AND output element types — <In, Out> — so the
// second call can transform strings into numbers. Fix the signature and the
// one annotation inside the body; don't touch the calls.
// ---------------------------------------------------------------------------

function mapItems<In, Out>(items: In[], transform: (item: In) => Out): Out[] {
  const out: Out[] = [];
  for (const item of items) {
    out.push(transform(item));
  }
  return out;
}

const shouts = mapItems(["ok", "go"], (s) => s.toUpperCase());
const lengths = mapItems(["ok", "error", "retry"], (s) => s.length);

type _e3a = Expect<Equal<typeof shouts, string[]>>;
type _e3b = Expect<Equal<typeof lengths, number[]>>;

check("strings map to strings", shouts, ["OK", "GO"]);
check("strings map to numbers", lengths, [2, 5, 5]);

// ---------------------------------------------------------------------------
// Exercise 4 — Add a constraint.
// findById should work on ANY array of things that have a string id. But
// with an unconstrained T, TypeScript refuses to read .id in the body — as
// far as it knows, T could be number. Constrain T with `extends` so the
// body compiles. Don't change the body or the calls.
// ---------------------------------------------------------------------------

function findById<T extends { id: string }>(
  items: T[],
  id: string,
): T | undefined {
  return items.find((item) => item.id === id);
}

const users = [
  { id: "u1", name: "Ada" },
  { id: "u2", name: "Grace" },
];
const ada = findById(users, "u1");

type _e4 = Expect<Equal<typeof ada, { id: string; name: string } | undefined>>;

check("found Ada by id", ada?.name, "Ada");
check("missing id gives undefined", findById(users, "u9"), undefined);

// ---------------------------------------------------------------------------
// Exercise 5 — The lookup pattern.
// getProp returns `unknown` for every property, so the reads below lose
// their types. Rewrite the signature using the canonical lookup shape from
// the notes — <T, K extends keyof T>(obj: T, key: K): T[K] — the body is
// already correct. Don't touch the calls.
// ---------------------------------------------------------------------------

function getProp<T, K extends keyof T>(obj: T, key: K): T[K] {
  return obj[key];
}

const editorConfig = { theme: "dark", fontSize: 14, relativeNumbers: true };

const theme = getProp(editorConfig, "theme");
const fontSize = getProp(editorConfig, "fontSize");

type _e5a = Expect<Equal<typeof theme, string>>;
type _e5b = Expect<Equal<typeof fontSize, number>>;

check("theme keeps its property type", theme, "dark");
check("fontSize keeps its property type", fontSize, 14);

// ---------------------------------------------------------------------------
// Exercise 6 — Make the TYPE generic.
// ApiResponse was written for one endpoint and hardcodes `data: string`.
// Now two more endpoints need it. Give the alias a type parameter —
// ApiResponse<T> with `data: T` — so all three annotations below work.
// Fix the type alias only; the variables are correct.
// ---------------------------------------------------------------------------

type ApiResponse<T> = {
  status: number;
  data: T;
};

const healthResponse: ApiResponse<string> = { status: 200, data: "ok" };
const userResponse: ApiResponse<{ id: string; name: string }> = {
  status: 200,
  data: { id: "u1", name: "Ada" },
};
const countResponse: ApiResponse<number> = { status: 200, data: 42 };

type _e6a = Expect<
  Equal<typeof userResponse.data, { id: string; name: string }>
>;
type _e6b = Expect<Equal<typeof countResponse.data, number>>;

check("health endpoint data", healthResponse.data, "ok");
check("user endpoint data", userResponse.data.name, "Ada");
check("count endpoint data", countResponse.data, 42);

// ---------------------------------------------------------------------------
// Exercise 7 — Default type parameters.
// Most lists in this app hold strings, so the team wants a bare
// `PaginatedList` (no type argument) to mean PaginatedList<string>. Right
// now that's an error: "Generic type 'PaginatedList<T>' requires 1 type
// argument(s)". Give T a default. Don't touch the variables.
// ---------------------------------------------------------------------------

type PaginatedList<T = string> = {
  items: T[];
  page: number;
  totalPages: number;
};

const tagPage: PaginatedList = {
  items: ["typescript", "react", "nextjs"],
  page: 1,
  totalPages: 4,
};

const scorePage: PaginatedList<number> = {
  items: [88, 92, 79],
  page: 2,
  totalPages: 3,
};

type _e7a = Expect<Equal<typeof tagPage.items, string[]>>;
type _e7b = Expect<Equal<typeof scorePage.items, number[]>>;

check("tag page holds strings", tagPage.items[0], "typescript");
check("score page holds numbers", scorePage.items.length, 3);

// ---------------------------------------------------------------------------
summary();
export {};
