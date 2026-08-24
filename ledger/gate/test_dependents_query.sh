#!/usr/bin/env bash
# Suite for entries_query.ncl's `dependents_of` view -- the reverse of
# `chain_floor`. `chain_floor` follows a claim's support edges DOWN to
# where it bottoms out; `dependents_of` follows the SAME edges UP, from a
# claim to everything that transitively rests on it -- what a "this claim
# is false" repair must reconsider.
#
# ledger/fixtures/entry/dependents-of-chain.yaml is the hand-authored
# multi-hop fixture (see its own header for the shape): a genuine 3-hop
# `because` chain (dep:A <- dep:B <- dep:C <- dep:D) so a shallow,
# one-hop-only reverse lookup fails this suite even though it would pass a
# two-node fixture; a `depends` edge disjoint from that chain (dep:I <-
# dep:H); a `depends` edge feeding INTO the because chain (dep:E depends
# on dep:B, proving the two edge kinds compose in one walk); a `because`
# CYCLE (dep:F <-> dep:G) proving termination; an `external`-tagged
# `because` ref that names a real id string but must not resolve as one
# (dep:Z); and a leaf nothing points at (dep:Lonely), proving an empty
# answer prints `[]`, not silence.
#
# Usage: test_dependents_query.sh
# Exit:  0 = every case matched, 1 = a case mismatched, 2 = environment error.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
query="$root/ledger/contracts/entries_query.ncl"
fixture="$root/ledger/fixtures/entry/dependents-of-chain.yaml"
regression_fixture="$root/ledger/fixtures/entry/regression-chain-floor-scale.yaml"

command -v python3 >/dev/null 2>&1 || { echo "ENV: python3 not found on PATH"; exit 2; }
command -v nickel >/dev/null 2>&1 || { echo "ENV: nickel not found on PATH"; exit 2; }
[ -f "$query" ] || { echo "ENV: query contract missing: $query"; exit 2; }
[ -f "$fixture" ] || { echo "ENV: fixture missing: $fixture"; exit 2; }
[ -f "$regression_fixture" ] || { echo "ENV: regression fixture missing: $regression_fixture"; exit 2; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fails=0

# YAML -> JSON once, same idiom test_entries_extract.sh's callers use
# (nickel export accepts JSON input directly; the fixture is authored as
# YAML for readability, same as regression-chain-floor-scale.yaml).
python3 -c "
import yaml, json, sys
d = yaml.safe_load(open(sys.argv[1]))
json.dump(d, open(sys.argv[2], 'w'))
" "$fixture" "$tmp/fixture.json"
[ -f "$tmp/fixture.json" ] || { echo "ENV: YAML->JSON conversion failed"; exit 2; }

nickel export "$tmp/fixture.json" --apply-contract "$query" \
  > "$tmp/out.json" 2> "$tmp/out.err"
export_rc=$?
if [ "$export_rc" -ne 0 ]; then
  echo "FAIL  (rc=$export_rc) export over the multi-hop fixture failed -- dependents_of missing or the corpus itself is malformed"
  tail -20 "$tmp/out.err"
  fails=$((fails + 1))
else
  echo "PASS  (0) export over the multi-hop fixture succeeds"
fi

# One python check asserting every case at once against dependents_of's
# shape: {id, dependents: [...]} per claim, dependents an array of ids.
python3 - "$tmp/out.json" <<'PYEOF'
import json, sys

fails = []

def check(cond, msg):
    if not cond:
        fails.append(msg)

try:
    export = json.load(open(sys.argv[1]))
except Exception as e:
    print(f"FAIL  could not parse export JSON: {e}")
    sys.exit(1)

check("dependents_of" in export, "dependents_of view is absent from the export")
if "dependents_of" in export:
    by_id = {row["id"]: set(row["dependents"]) for row in export["dependents_of"]}

    check("dep:A" in by_id, "dep:A missing from dependents_of")
    check("dep:B" in by_id, "dep:B missing from dependents_of")

    # The multi-hop claim: C and D are NOT direct successors of A, only
    # reachable transitively through B -- this is the case a one-hop
    # reverse lookup gets wrong.
    check(by_id.get("dep:A") == {"dep:B", "dep:C", "dep:D", "dep:E"},
          f"dep:A dependents wrong: {by_id.get('dep:A')} (want B,C,D,E)")
    check(by_id.get("dep:B") == {"dep:C", "dep:D", "dep:E"},
          f"dep:B dependents wrong: {by_id.get('dep:B')} (want C,D,E)")
    check(by_id.get("dep:C") == {"dep:D"},
          f"dep:C dependents wrong: {by_id.get('dep:C')} (want D)")
    check(by_id.get("dep:D") == set(),
          f"dep:D dependents wrong: {by_id.get('dep:D')} (want empty)")

    # depends reverses too, disjoint chain.
    check(by_id.get("dep:I") == {"dep:H"},
          f"dep:I dependents wrong: {by_id.get('dep:I')} (want H)")

    # The cycle terminates and each side sees exactly the other.
    check(by_id.get("dep:F") == {"dep:G"},
          f"dep:F dependents wrong: {by_id.get('dep:F')} (want G)")
    check(by_id.get("dep:G") == {"dep:F"},
          f"dep:G dependents wrong: {by_id.get('dep:G')} (want F)")

    # dep:Z's because ref is EXTERNAL and must not count, even though it
    # names dep:A's own id string.
    check("dep:Z" not in by_id.get("dep:A", set()),
          "dep:Z (external-tagged because ref) wrongly counted as a dependent of dep:A")

    # A leaf nothing points at answers the explicit empty array, not
    # silence / a missing row.
    check(by_id.get("dep:Lonely") == set(),
          f"dep:Lonely dependents wrong: {by_id.get('dep:Lonely')} (want empty)")

if fails:
    for f in fails:
        print(f"FAIL  {f}")
    sys.exit(1)
print("PASS  (0) all dependents_of cases match: multi-hop, mixed edge kinds, cycle, external exclusion, empty leaf")
PYEOF
python_rc=$?
[ "$python_rc" -eq 0 ] || fails=$((fails + 1))

# --- performance regression: reuse chain_floor's own generated fixture ------
#
# 900 entries, 45 independent because-chains of depth 20 -- the same shape
# and cap chain_floor's own regression guards against
# (test_entries_extract.sh), reused here because dependents_of shares its
# per-claim bounded-DFS design and the identical failure mode (a
# whole-corpus fixed point reconstructed every round) is exactly as
# reachable in reverse as it was forward.
expect_perf() {
  local desc="$1"
  if bash -c "ulimit -v 4000000; timeout 60 nickel export '$regression_fixture' --apply-contract '$query'" >/dev/null 2>"$tmp/perf.err"; then
    echo "PASS  (0) $desc"
  else
    echo "FAIL  $desc"
    tail -10 "$tmp/perf.err"
    fails=$((fails + 1))
  fi
}
expect_perf "dependents_of over a 900-entry/depth-20 corpus stays under a 4GB cap and 60s"

echo
if [ "$fails" -eq 0 ]; then echo "test_dependents_query: ALL PASS"; exit 0; fi
echo "test_dependents_query: $fails FAILURE(S)"; exit 1
