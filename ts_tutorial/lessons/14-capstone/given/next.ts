/**
 * Given file — complete and correct. Do not edit.
 *
 * This is (a simplified version of) what Next.js generates for you. We
 * import NOTHING from "next" — lesson 13's rule still holds. When you
 * scaffold a real app later, shapes like these arrive for free; here you
 * get to see that they are just types.
 */

/** What arrives in a page's `searchParams` once you await it. */
export type SearchParams = Record<string, string | string[] | undefined>

/**
 * Props Next hands every page component. Both fields are Promises in
 * Next 15 — you must await them (that's half of stage 08).
 */
export type PageProps<Params = Record<string, never>> = {
  params: Promise<Params>
  searchParams: Promise<SearchParams>
}

/** Second argument of a dynamic route handler (GET/DELETE/...). */
export type RouteContext<Params> = {
  params: Promise<Params>
}

/** What a server action reports back to the form that called it. */
export type ActionState =
  | { ok: true; message: string }
  | { ok: false; error: string }
