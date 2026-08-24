#!/usr/bin/env bash
# Suite for entries_query.ncl's `refutations` / `impeachment_queue` views --
# the falsity edge's species DERIVATION (born-false / became-false /
# unclassifiable-refutation, RF4) and the derived collision queue
# (the `impeachment` theorem: a snapshot-sound closure and a true
# refutation at the same anchor are jointly impossible).
#
# ledger/fixtures/entry/refutations-species.yaml is the hand-authored
# fixture (see its own header) -- five ref:T*/ref:R* pairs, one per
# species-derivation branch, so a shallow implementation that only handles
# the equal-anchor case fails this suite even though it would pass a
# one-pair fixture.
#
# Usage: test_refutations_query.sh
# Exit:  0 = every case matched, 1 = a case mismatched, 2 = environment error.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
query="$root/ledger/contracts/entries_query.ncl"
fixture="$root/ledger/fixtures/entry/refutations-species.yaml"

command -v python3 >/dev/null 2>&1 || { echo "ENV: python3 not found on PATH"; exit 2; }
command -v nickel >/dev/null 2>&1 || { echo "ENV: nickel not found on PATH"; exit 2; }
[ -f "$query" ] || { echo "ENV: query contract missing: $query"; exit 2; }
[ -f "$fixture" ] || { echo "ENV: fixture missing: $fixture"; exit 2; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fails=0

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
  echo "FAIL  (rc=$export_rc) export over the species fixture failed -- refutations/impeachment_queue missing or the corpus itself is malformed"
  tail -20 "$tmp/out.err"
  fails=$((fails + 1))
else
  echo "PASS  (0) export over the species fixture succeeds"
fi

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

check("refutations" in export, "refutations view is absent from the export")
check("impeachment_queue" in export, "impeachment_queue view is absent from the export")

if "refutations" in export:
    by_pair = {(row["refutation"], row["target"]): row["species"] for row in export["refutations"]}

    check(by_pair.get(("ref:R1", "ref:T1")) == "born-false",
          f"R1->T1 (equal check anchor) wrong: {by_pair.get(('ref:R1', 'ref:T1'))} (want born-false)")
    check(by_pair.get(("ref:R2", "ref:T2")) == "became-false",
          f"R2->T2 (differing anchor, non-monotone) wrong: {by_pair.get(('ref:R2', 'ref:T2'))} (want became-false)")
    check(by_pair.get(("ref:R3", "ref:T3")) == "born-false",
          f"R3->T3 (differing anchor, MONOTONE target) wrong: {by_pair.get(('ref:R3', 'ref:T3'))} (want born-false, mechanical promotion)")
    check(by_pair.get(("ref:R4", "ref:T4")) == "unclassifiable-refutation",
          f"R4->T4 (unanchored target) wrong: {by_pair.get(('ref:R4', 'ref:T4'))} (want unclassifiable-refutation)")
    check(by_pair.get(("ref:R5", "ref:T5")) == "born-false",
          f"R5->T5 (equal WITNESS anchor) wrong: {by_pair.get(('ref:R5', 'ref:T5'))} (want born-false)")

    check(len(by_pair) == 5, f"expected exactly 5 refutation rows, got {len(by_pair)}: {sorted(by_pair)}")

if "impeachment_queue" in export:
    queued = {(row["refutation"], row["target"]) for row in export["impeachment_queue"]}

    # Only the three born-false-on-CLOSED pairs queue; became-false (R2/T2,
    # closed but wrong species) and the unclosed target (R4/T4, unclassifiable
    # AND unclosed) must both be absent.
    check(("ref:R1", "ref:T1") in queued, "R1->T1 (born-false, closed target) missing from impeachment_queue")
    check(("ref:R3", "ref:T3") in queued, "R3->T3 (born-false via monotone promotion, closed target) missing from impeachment_queue")
    check(("ref:R5", "ref:T5") in queued, "R5->T5 (born-false, vouched/closed target) missing from impeachment_queue")
    check(("ref:R2", "ref:T2") not in queued, "R2->T2 (became-false) wrongly queued for impeachment")
    check(("ref:R4", "ref:T4") not in queued, "R4->T4 (unclassifiable, unclosed target) wrongly queued for impeachment")
    check(len(queued) == 3, f"expected exactly 3 impeachment rows, got {len(queued)}: {sorted(queued)}")

if fails:
    for f in fails:
        print(f"FAIL  {f}")
    sys.exit(1)
print("PASS  (0) all refutations/impeachment_queue cases match: born-false, became-false, monotone promotion, unclassifiable, witness-anchored")
PYEOF
python_rc=$?
[ "$python_rc" -eq 0 ] || fails=$((fails + 1))

echo
if [ "$fails" -eq 0 ]; then echo "test_refutations_query: ALL PASS"; exit 0; fi
echo "test_refutations_query: $fails FAILURE(S)"; exit 1
