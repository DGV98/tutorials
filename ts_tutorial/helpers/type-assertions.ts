/**
 * Type-level assertion helpers, used throughout the exercises.
 *
 * You do NOT need to understand how these work yet — by lesson 09 you will.
 * All you need to know is how to read them:
 *
 *   type _check = Expect<Equal<typeof result, string[]>>
 *
 * means: "assert that the type of `result` is exactly `string[]`".
 * If the assertion holds, the line is quiet. If it fails, TypeScript
 * reports an error on that line — your job is to fix the code above it
 * (never the assertion itself) until the error disappears.
 */

/** Fails to compile unless T is exactly `true`. */
export type Expect<T extends true> = T

/** Resolves to `true` when X and Y are exactly the same type, else `false`. */
export type Equal<X, Y> =
  (<T>() => T extends X ? 1 : 2) extends (<T>() => T extends Y ? 1 : 2)
    ? true
    : false

/** Resolves to `true` when X and Y are NOT the same type. */
export type NotEqual<X, Y> = Equal<X, Y> extends true ? false : true
