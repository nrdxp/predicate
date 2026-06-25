# Tracker-freshness predicate — the functional core of tracker_fresh.sh.
#
# Primitive: P-TRACK (primitives-spec.md §P-TRACK, I-T3 — the tracker is
# RE-SURFACED + updated at each step, not recorded once; staleness caught via
# `last_validated`).
#
# This file is the Nickel/functional tier of the K10 three-tier architecture:
#   Nickel/functional (this file) — pure comparator; no I/O
#   Python             (tracker_fresh.py) — effectful: load exported map, get
#                                           HEAD date from git, call this predicate
#   Bash               (tracker_fresh.sh) — thin entrypoint; routes to python3
#
# DESIGN RATIONALE
# `last_validated` is an ISO 8601 date string (YYYY-MM-DD or YYYY-MM-DDThh:mm:ss).
# ISO 8601 dates compare correctly under lexicographic ordering — a later date
# sorts later. A `last_validated` value is STALE when it is strictly earlier than
# the reference date (the date of the HEAD git commit or "today"). It is FRESH
# when it is equal to or later than the reference date.
#
# The staleness threshold is parameterized (default: the exact HEAD date, so any
# item not validated AT or AFTER HEAD's commit date is stale). Callers can pass
# an earlier reference date to allow some lag.
#
# Contracts exported:
#   is_fresh      : String -> String -> Bool
#                   `is_fresh last_validated reference_date` returns true iff
#                   `last_validated >= reference_date` (lexicographic; valid for
#                   ISO 8601 dates with a consistent prefix length).
#
#   stale_items   : Array { last_validated | String, .. } -> String -> Array { .. }
#                   Given an array of context-map items and a reference date,
#                   returns the subset whose `last_validated` is stale (< ref).
#
# Verification:
#   nickel typecheck -I <plugin>/ledger/contracts ledger/contracts/tracker_freshness.ncl
{
  # is_fresh last_validated reference_date
  # True iff the item's last_validated date is >= reference_date (string compare).
  # Applies to ISO 8601 dates (YYYY-MM-DD...) where lexicographic order = date order.
  is_fresh
    | String -> String -> Bool
    = fun last_validated reference_date =>
        # std.string.compare returns 'Lesser, 'Equal, or 'Greater (Nickel stdlib).
        # Fresh = validated on or after reference_date: 'Equal or 'Greater.
        std.string.compare last_validated reference_date != 'Lesser,

  # stale_items items reference_date
  # Returns the subset of items whose last_validated < reference_date.
  stale_items
    | Array { last_validated | String, .. } -> String -> Array { last_validated | String, .. }
    = fun items reference_date =>
        std.array.filter
          (fun item => !( is_fresh item.last_validated reference_date ))
          items,
}
