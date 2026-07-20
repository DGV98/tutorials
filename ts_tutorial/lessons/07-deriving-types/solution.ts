/**
 * Lesson 07 — solution with commentary.
 */
import type { Expect, Equal } from "../../helpers/type-assertions"
import { check, summary } from "../../helpers/test"

// Exercise 1 — `typeof defaultSettings` IS the type of the object, kept in
// sync by the compiler forever. The hand-written version had already drifted
// twice (fontSize: string, no autosave) — deleting it deletes the drift.

const defaultSettings = {
  theme: "dark",
  fontSize: 14,
  autosave: true,
}

type Settings = typeof defaultSettings

function describeSettings(s: Settings): string {
  return `${s.theme} @ ${s.fontSize}px`
}

type _e1 = Expect<Equal<Settings, typeof defaultSettings>>
check("settings describe themselves", describeSettings(defaultSettings), "dark @ 14px")

// Exercise 2 — read the derivations inside-out: HttpConfig is already
// `typeof httpConfig`, so `keyof HttpConfig` is its keys as a literal union,
// and HttpConfig["retries"] plucks out one property's type (number — the
// object isn't `as const`, so properties widened). Add a key to httpConfig
// and ConfigKey grows by itself.

const httpConfig = {
  baseUrl: "https://api.example.com",
  retries: 3,
  verbose: false,
}

type HttpConfig = typeof httpConfig

type ConfigKey = keyof HttpConfig
type RetryCount = HttpConfig["retries"]

function readConfig(key: ConfigKey) {
  return httpConfig[key]
}

type _e2a = Expect<Equal<ConfigKey, "baseUrl" | "retries" | "verbose">>
type _e2b = Expect<Equal<RetryCount, number>>
check("reads retries", readConfig("retries"), 3)
check("reads verbose", readConfig("verbose"), false)

// Exercise 3 — the two-word fix: `as const`. Without it the array infers
// string[], and string[][number] is just string. With it, ALIGNMENTS is the
// readonly tuple ["left", "center", "right"], and indexing a tuple by
// `number` unions every element: the literal union we wanted.

const ALIGNMENTS = ["left", "center", "right"] as const

type Alignment = (typeof ALIGNMENTS)[number]

function formatAlignment(a: Alignment): string {
  return `align-${a}`
}

type _e3 = Expect<Equal<Alignment, "left" | "center" | "right">>
check("three alignments exist", ALIGNMENTS.length, 3)
check("center is valid", formatAlignment("center"), "align-center")

// Exercise 4 — both unions come from the one `as const` object:
// keys via `keyof typeof`, values via indexed access with the key union
// (indexing with a union unions the results). Note StatusLabel is built on
// Status, so both stay in sync through a single derivation chain.

const STATUS_LABELS = {
  draft: "Draft",
  published: "Published",
  archived: "Archived",
} as const

type Status = keyof typeof STATUS_LABELS
type StatusLabel = (typeof STATUS_LABELS)[Status]

type _e4a = Expect<Equal<Status, "draft" | "published" | "archived">>
type _e4b = Expect<Equal<StatusLabel, "Draft" | "Published" | "Archived">>
check("draft has a label", STATUS_LABELS.draft, "Draft")
check("every status has a label", Object.keys(STATUS_LABELS).length, 3)

// Exercise 5 — `satisfies` checks ROUTES against Record<string, string> but
// leaves the inferred type alone, so the keys survive for `keyof` to find.
// An annotation REPLACES the inferred type; satisfies only AUDITS it. And
// because there's no `as const`, the property values still widen to string —
// which is why _e5b passed before and after.

const ROUTES = {
  home: "/",
  settings: "/settings",
  profile: "/profile/:id",
} satisfies Record<string, string>

type RouteName = keyof typeof ROUTES

type _e5a = Expect<Equal<RouteName, "home" | "settings" | "profile">>
type _e5b = Expect<Equal<(typeof ROUTES)["home"], string>>
check("settings route", ROUTES.settings, "/settings")

// Exercise 6 — the combination: `as const` keeps every value a literal
// (so ThemeColor is a union of hex strings, not string), and `satisfies`
// validates each one (the moment you added it, TypeScript flagged 0xef4444 —
// `as const` alone would have happily frozen the bug in place).

const THEME = {
  primary: "#4f46e5",
  accent: "#22d3ee",
  danger: "#ef4444",
} as const satisfies Record<string, string>

type ThemeColor = (typeof THEME)[keyof typeof THEME]

type _e6 = Expect<Equal<ThemeColor, "#4f46e5" | "#22d3ee" | "#ef4444">>
check("danger is a hex string", THEME.danger, "#ef4444")

// Exercise 7 — one derivation fixed four errors at once: the two assertions,
// the impossible NOTIFICATION_STYLES["warning"] lookup inside renderBadge,
// and the { kind: "error" } call site. That's the payoff: props derived from
// the config can never disagree with it. Add an "urgent" style tomorrow and
// <Badge kind="urgent"> just works.

const NOTIFICATION_STYLES = {
  info: { icon: "i", color: "blue" },
  success: { icon: "check", color: "green" },
  error: { icon: "cross", color: "red" },
} as const

type NotificationKind = keyof typeof NOTIFICATION_STYLES

type BadgeProps = {
  kind: NotificationKind
  label: string
}

function renderBadge(props: BadgeProps): string {
  const style = NOTIFICATION_STYLES[props.kind]
  return `[${style.icon}] ${props.label} (${style.color})`
}

type _e7a = Expect<Equal<NotificationKind, "info" | "success" | "error">>
type _e7b = Expect<Equal<BadgeProps["kind"], "info" | "success" | "error">>
check("success badge", renderBadge({ kind: "success", label: "Saved" }), "[check] Saved (green)")
check("error badge", renderBadge({ kind: "error", label: "Failed" }), "[cross] Failed (red)")

summary()
export {}
