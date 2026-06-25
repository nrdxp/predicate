#!/usr/bin/env bash
# Tracker-freshness gate — thin bash entrypoint (K10 tier 3).
#
# Primitive: P-TRACK (primitives-spec.md §P-TRACK, I-T3).
# A live context-map tracker is FRESH when every item's `last_validated`
# date is current relative to the HEAD git commit. A stale item means the
# walk has carried an unrefreshed requirement/invariant/unknown forward past
# at least one commit; if the item has a `hydration_source`, the persistent
# AGENTS.md anchor may have drifted and reorientation (/orient) is due.
#
# This is `premise_fresh.sh` generalized to the tracker: where premise_fresh
# checks campaign-node tripwires, tracker_fresh checks the context-map's
# last_validated timestamps — both implement the same staleness principle
# (rules.md §7 / ambient.md §Boundary Reconstruction).
#
# Three-tier architecture (K10):
#   tracker_freshness.ncl  Nickel/functional  — pure staleness predicate
#   tracker_fresh.py       Python             — effectful: export the map,
#                                               get HEAD date, call Nickel
#   tracker_fresh.sh  (this file)  Bash       — thin entrypoint, routes to py
#
# DOWNSTREAM PORTABILITY:
# This script locates tracker_fresh.py by resolving its own real path
# (symlink-safe), so the gate works wherever predicate is installed. It does
# NOT use project-relative paths; the Python tier resolves the plugin root
# from its own real path in the same way.
#
# Usage:  tracker_fresh.sh <context-map.ncl> [reference-date] [git-root]
#
#   <context-map.ncl>  path to the ContextMap instance to check
#   [reference-date]   YYYY-MM-DD override (default: HEAD commit date)
#   [git-root]         git repo root for HEAD date (default: current dir)
#
# Output: FRESH/STALE per item, then a verdict line.
# Exit:   0 = FRESH (every item current), 1 = STALE (>= 1 item behind),
#         2 = usage / environment error
set -u

# Resolve this script's own real directory (symlink-safe via realpath or
# a POSIX fallback) so sibling machinery is always located relative to where
# the PLUGIN lives, not relative to whatever repo is calling the gate.
if command -v realpath >/dev/null 2>&1; then
  here="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" && pwd)"
else
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

artifact="${1:-}"
if [ -z "$artifact" ]; then
  echo "usage: tracker_fresh.sh <context-map.ncl> [reference-date] [git-root]" >&2
  exit 2
fi
if [ ! -f "$artifact" ]; then
  echo "tracker_fresh: no such artifact: $artifact" >&2
  exit 2
fi

# Build the python3 invocation. Optional overrides are passed only when
# provided so the Python defaults (HEAD date, cwd) kick in normally.
py_args=(python3 "$here/tracker_fresh.py" --artifact "$artifact")

if [ -n "${2:-}" ]; then
  py_args+=(--reference-date "$2")
fi

if [ -n "${3:-}" ]; then
  py_args+=(--git-root "$3")
fi

exec "${py_args[@]}"
