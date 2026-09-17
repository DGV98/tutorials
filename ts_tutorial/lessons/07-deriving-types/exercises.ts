/**
 * Lesson 07 — exercises.
 *
 * This file intentionally does not type-check. Work top to bottom, fixing
 * each exercise until `./check 07` reports zero errors. Never edit lines
 * containing Expect<Equal<...>> — they are the assertions you're satisfying.
 *
 * Then run it:  npx tsx lessons/07-deriving-types/exercises.ts
 */
import type { Expect, Equal } from "../../helpers/type-assertions";
import { check, summary } from "../../helpers/test";

// ---------------------------------------------------------------------------
// Exercise 1 — One source of truth.
// `Settings` was written by hand and has drifted from the real object:
// fontSize is wrong and autosave is missing entirely. Don't patch it field
// by field — DELETE the hand-written shape and derive the whole thing with
// `typeof`. Don't touch defaultSettings or describeSettings.
// ---------------------------------------------------------------------------

const defaultSettings = {
  theme: "dark",
  fontSize: 14,
  autosave: true,
};

type Settings = typeof defaultSettings;

function describeSettings(s: Settings): string {
  return `${s.theme} @ ${s.fontSize}px`;
}

type _e1 = Expect<Equal<Settings, typeof defaultSettings>>;
check(
  "settings describe themselves",
  describeSettings(defaultSettings),
  "dark @ 14px",
);

// ---------------------------------------------------------------------------
// Exercise 2 — keyof and indexed access.
// Both hand-written types below have drifted. Derive ConfigKey from
// HttpConfig with `keyof`, and RetryCount with indexed access
// (HttpConfig["..."]). Don't touch httpConfig or readConfig.
// ---------------------------------------------------------------------------

const httpConfig = {
  baseUrl: "https://api.example.com",
  retries: 3,
  verbose: false,
};

type HttpConfig = typeof httpConfig;

type ConfigKey = keyof HttpConfig;
type RetryCount = HttpConfig["retries"];

function readConfig(key: ConfigKey) {
  return httpConfig[key];
}

type _e2a = Expect<Equal<ConfigKey, "baseUrl" | "retries" | "verbose">>;
type _e2b = Expect<Equal<RetryCount, number>>;
check("reads retries", readConfig("retries"), 3);
check("reads verbose", readConfig("verbose"), false);

// ---------------------------------------------------------------------------
// Exercise 3 — as const + T[number].
// Hover ALIGNMENTS: it's string[], so the derived Alignment is just string —
// useless as a prop type. One two-word addition to the ALIGNMENTS line makes
// the derivation produce the literal union. Don't touch the Alignment line.
// ---------------------------------------------------------------------------

const ALIGNMENTS = ["left", "center", "right"] as const;

type Alignment = (typeof ALIGNMENTS)[number];

function formatAlignment(a: Alignment): string {
  return `align-${a}`;
}

type _e3 = Expect<Equal<Alignment, "left" | "center" | "right">>;
check("three alignments exist", ALIGNMENTS.length, 3);
check("center is valid", formatAlignment("center"), "align-center");

// ---------------------------------------------------------------------------
// Exercise 4 — keys AND values from one const object.
// STATUS_LABELS is the single source of truth, but both types below were
// written by hand and have drifted. Derive Status from the object's keys
// and StatusLabel from its values. Don't touch STATUS_LABELS.
// ---------------------------------------------------------------------------

const STATUS_LABELS = {
  draft: "Draft",
  published: "Published",
  archived: "Archived",
} as const;

type Status = keyof typeof STATUS_LABELS;
type StatusLabel = (typeof STATUS_LABELS)[keyof typeof STATUS_LABELS];

type _e4a = Expect<Equal<Status, "draft" | "published" | "archived">>;
type _e4b = Expect<Equal<StatusLabel, "Draft" | "Published" | "Archived">>;
check("draft has a label", STATUS_LABELS.draft, "Draft");
check("every status has a label", Object.keys(STATUS_LABELS).length, 3);

// ---------------------------------------------------------------------------
// Exercise 5 — annotation vs satisfies.
// The `: Record<string, string>` annotation validates ROUTES but WIDENS it —
// TypeScript forgets which routes exist, so RouteName collapses to string.
// Keep the validation but keep the keys too: replace the annotation with
// `satisfies`. Don't touch the RouteName line.
// ---------------------------------------------------------------------------

const ROUTES: Record<string, string> = {
  home: "/",
  settings: "/settings",
  profile: "/profile/:id",
};

type RouteName = keyof typeof ROUTES;

type _e5a = Expect<Equal<RouteName, "home" | "settings" | "profile">>;
// This one already passes — and still will after your fix. `satisfies`
// without `as const` keeps property VALUES widened to string.
type _e5b = Expect<Equal<(typeof ROUTES)["home"], string>>;
check("settings route", ROUTES.settings, "/settings");

// ---------------------------------------------------------------------------
// Exercise 6 — as const satisfies: narrow AND checked.
// ThemeColor should be a union of hex-string literals, but the values widen
// to string — and one entry isn't even a string (0xef4444 is a number that
// nothing currently rejects). Add `as const satisfies Record<string, string>`
// to THEME; the satisfies will then point straight at the bad entry — fix it
// to the string "#ef4444". Don't touch the ThemeColor line.
// ---------------------------------------------------------------------------

const THEME = {
  primary: "#4f46e5",
  accent: "#22d3ee",
  danger: 0xef4444,
};

type ThemeColor = (typeof THEME)[keyof typeof THEME];

type _e6 = Expect<Equal<ThemeColor, "#4f46e5" | "#22d3ee" | "#ef4444">>;
check("danger is a hex string", THEME.danger, "#ef4444");

// ---------------------------------------------------------------------------
// Exercise 7 — the React payoff.
// NOTIFICATION_STYLES is the source of truth for a Badge component, but
// NotificationKind was hand-written and has drifted: "warning" doesn't exist
// in the styles object, and "error" is missing. Derive NotificationKind from
// the object and every error below disappears at once. Don't touch
// NOTIFICATION_STYLES, BadgeProps, or renderBadge's body.
// ---------------------------------------------------------------------------

const NOTIFICATION_STYLES = {
  info: { icon: "i", color: "blue" },
  success: { icon: "check", color: "green" },
  error: { icon: "cross", color: "red" },
} as const;

type NotificationKind = "info" | "success" | "warning";

type BadgeProps = {
  kind: NotificationKind;
  label: string;
};

function renderBadge(props: BadgeProps): string {
  const style = NOTIFICATION_STYLES[props.kind];
  return `[${style.icon}] ${props.label} (${style.color})`;
}

type _e7a = Expect<Equal<NotificationKind, "info" | "success" | "error">>;
type _e7b = Expect<Equal<BadgeProps["kind"], "info" | "success" | "error">>;
check(
  "success badge",
  renderBadge({ kind: "success", label: "Saved" }),
  "[check] Saved (green)",
);
check(
  "error badge",
  renderBadge({ kind: "error", label: "Failed" }),
  "[cross] Failed (red)",
);

// ---------------------------------------------------------------------------
summary();
export {};
