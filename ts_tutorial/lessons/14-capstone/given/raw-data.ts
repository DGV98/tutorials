/**
 * Given file — complete and correct. Do not edit.
 *
 * The untrusted outside world. Everything in here is what the network
 * would hand you: strings and unknowns, no domain types anywhere. That
 * is the point — stages 04 and 08 have to EARN the types.
 */

/**
 * What GET /api/tracks would respond with. One entry is malformed on
 * purpose (its title is a number — a field NOTHING in the compiler forces
 * your predicate to check) — your isTrack predicate is the only thing
 * standing between it and your UI.
 */
export const RAW_CATALOG_JSON: string = `[
  { "id": "t10", "title": "Everything In Its Right Place", "artist": "Radiohead", "album": "Kid A", "genre": "rock", "durationSec": 251 },
  { "id": "t11", "title": 245, "artist": "Aphex Twin", "album": "Windowlicker", "genre": "electronic", "durationSec": 245 },
  { "id": "t12", "title": "Blue in Green", "artist": "Miles Davis", "album": "Kind of Blue", "genre": "jazz", "durationSec": 337 }
]`

/** What GET /api/prefs would respond with on a good day. */
export const RAW_PREFS_JSON: string = `{"volume":7,"muted":false}`

/** ...and on a bad day. */
export const RAW_BAD_PREFS_JSON: string = `{"volume":"loud"}`

/**
 * What fetching GET /api/tracks/:id looks like from the caller's side:
 * a Promise of you-don't-know-what. No network, no timers — but typed
 * exactly as honestly as a real fetch-and-parse would be.
 */
export function fakeFetchTrack(id: string): Promise<unknown> {
  const payload: unknown = {
    id,
    title: "Pyramid Song",
    artist: "Radiohead",
    album: "Amnesiac",
    genre: "rock",
    durationSec: 299,
  }
  return Promise.resolve(payload)
}
