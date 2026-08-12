#!/usr/bin/env bash
# Suite for ledger/derive/convergence.py -- the discharge-rate instrument over
# each direction's terminal questions.
#
# WHY THIS SUITE EXISTS, ON THE GROUND THAT SURVIVED
# ---------------------------------------------------
# convergence.py is one of three derive/ artifacts and the only uncovered one
# whose OUTPUT IS QUOTED IN DECISIONS -- it has already been quoted to a seat,
# and quoted stale (deposits/directions-convergence/lead-maintainer-seat/gate.md
# [C2]/[C4]). That is a different risk from an unverified helper nothing else
# consumes, and it is the ground this suite pins.
#
# The decisive case is the UNDEFINED rate: a direction with a directive node
# and zero terminal questions reports `rate: null`, never `0.0` -- an
# undrafted denominator and stalled work demand opposite responses, and
# collapsing them would read finished work as absent or absent work as
# finished. The LIVE corpus no longer exercises that path (every drafted
# direction has since gained a question), so this suite's fixture is the only
# thing that still demonstrates the design call at all ([C2]).
#
# Fixtures are hand-built JSON in the shape ledger/derive/extract_entries.py
# emits (ledger/fixtures/convergence/*.json), never the live record: the live
# corpus moves under concurrent work, and a suite pinned to it would fail for
# reasons unrelated to this code.
#
# Every assertion reads the `--json` output as structured values and never
# regexes the human-readable rendering -- a suite elsewhere in this repository
# was found reading a numeric value by its position in rendered prose, and the
# defect it produced was "fixed" by reordering the output. stdout and stderr
# are captured to separate files so a finding's stderr line can never land
# inside the JSON stream being parsed.
#
# Usage: test_convergence.sh
# Exit:  0 = every case matched, 1 = a case mismatched, 2 = environment error.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
tool="$root/ledger/derive/convergence.py"
fix="$root/ledger/fixtures/convergence"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

command -v python3 >/dev/null 2>&1 || { echo "ENV: python3 not found on PATH"; exit 2; }
[ -f "$tool" ] || { echo "ENV: convergence.py missing: $tool"; exit 2; }
[ -d "$fix" ]  || { echo "ENV: fixtures dir missing: $fix"; exit 2; }
for f in basic malformed-marker renamed-register; do
  [ -f "$fix/$f.json" ] || { echo "ENV: fixture missing: $fix/$f.json"; exit 2; }
done

fails=0
expect() {
  local desc="$1" exp="$2" kw="$3"; shift 3
  [ "$1" = "--" ] && shift
  local out rc ok=1
  out="$( "$@" 2>&1 )"; rc=$?
  [ "$rc" -eq "$exp" ] || ok=0
  if [ -n "$kw" ]; then printf '%s' "$out" | grep -q -- "$kw" || ok=0; fi
  if [ "$ok" -eq 1 ]; then
    echo "PASS  ($rc) $desc"
  else
    echo "FAIL  (got rc=$rc want $exp; want-kw='$kw') $desc"
    printf '%s\n' "$out" | tail -5
    fails=$((fails + 1))
  fi
}

# run_json DESC EXPECTED-RC FIXTURE -- runs convergence.py --json against the
# named fixture, stdout to $tmp/<fixture>.json and stderr to $tmp/<fixture>.err,
# and asserts the exit code. The JSON stream is never touched by stderr.
run_json() {
  local desc="$1" exp="$2" fixture="$3"
  local out="$tmp/$fixture.json" err="$tmp/$fixture.err" rc
  python3 "$tool" "$fix/$fixture.json" --json >"$out" 2>"$err"
  rc=$?
  if [ "$rc" -eq "$exp" ]; then
    echo "PASS  ($rc) $desc"
  else
    echo "FAIL  (got rc=$rc want $exp) $desc"
    tail -5 "$err"
    fails=$((fails + 1))
  fi
}

# assert_py DESC -- feeds a python assertion script stdin, given the paths to
# the fixture's captured stdout/stderr as argv. A failed assertion is a FAIL,
# never a silent pass.
assert_py() {
  local desc="$1"; shift
  local out
  if out="$(python3 - "$@" 2>&1)"; then
    echo "PASS  $desc"
  else
    echo "FAIL  $desc"
    printf '%s\n' "$out" | tail -10
    fails=$((fails + 1))
  fi
}

# --- basic.json: cases 1-5, all against one small corpus -------------------
run_json "basic: clean measurement, no findings" 0 basic

assert_py "case 1 UNDEFINED: D3 has a directive and zero terminal questions -> rate is null, never 0.0" \
  "$tmp/basic.json" <<'EOF'
import json, sys
data = json.load(open(sys.argv[1]))
d3 = next(r for r in data["directions"] if r["direction"] == "D3")
assert d3["total"] == 0, d3
assert d3["discharged"] == 0, d3
assert d3["rate"] is None, d3          # not 0.0 -- an undrafted denominator, not stalled work
assert d3["open"] == [], d3
EOF

expect "case 1 UNDEFINED: the human rendering says UNDEFINED for D3" 0 \
  "D3: UNDEFINED (no terminal questions drafted)" \
  -- python3 "$tool" "$fix/basic.json"

assert_py "case 2 partial: D1 is 1/2 discharged, the open question is listed with its grade" \
  "$tmp/basic.json" <<'EOF'
import json, sys
data = json.load(open(sys.argv[1]))
d1 = next(r for r in data["directions"] if r["direction"] == "D1")
assert d1["total"] == 2, d1
assert d1["discharged"] == 1, d1
assert d1["rate"] == 0.5, d1
assert d1["open"] == [{"id": "reg:D1-T1", "grade": "dispatchable"}], d1
EOF

assert_py "case 3 + case 4 full discharge: D2 closes 2/2 via discharges AND supersedes" \
  "$tmp/basic.json" <<'EOF'
import json, sys
data = json.load(open(sys.argv[1]))
d2 = next(r for r in data["directions"] if r["direction"] == "D2")
# reg:D2-T1 closes via a `discharges` edge, reg:D2-T2 via `supersedes` -- both
# closure edges must retire a question, or this would read 1/2 instead of 2/2.
assert d2["total"] == 2, d2
assert d2["discharged"] == 2, d2
assert d2["rate"] == 1.0, d2
assert d2["open"] == [], d2
EOF

assert_py "case 5 corpus-wide: the count is independent of any direction" \
  "$tmp/basic.json" <<'EOF'
import json, sys
data = json.load(open(sys.argv[1]))
# reg:Q1 is a question with no direction-shaped marker: it counts toward the
# corpus total and toward NO direction, so the corpus total exceeds the sum of
# every direction's total -- proof the corpus figure is not merely their sum.
assert data["corpus"]["questions"] == 5, data["corpus"]
assert data["corpus"]["discharged"] == 3, data["corpus"]
assert data["corpus"]["rate"] == 0.6, data["corpus"]
per_direction_total = sum(r["total"] for r in data["directions"])
assert per_direction_total == 4, per_direction_total
assert data["corpus"]["questions"] != per_direction_total, (
    data["corpus"]["questions"], per_direction_total)
EOF

# --- defect (a): a marker the parser mishandles -----------------------------
# D1_T5 is shaped like a terminal question for D1 but joined with '_' instead
# of '-'. The old behaviour silently dropped it from every count with no
# diagnostic -- a flattering-direction silent failure, since an open question
# vanishing from the denominator only ever makes the rate look better. The fix
# must be LOUD: the marker is reported as a finding and the run exits non-zero,
# while the count assertions confirm reporting did not change what gets
# guessed at (D1's denominator still excludes the marker it cannot parse).
run_json "malformed-marker: findings present -> non-zero exit" 3 malformed-marker

assert_py "malformed-marker: exactly one finding, naming the offending id" \
  "$tmp/malformed-marker.json" <<'EOF'
import json, sys
data = json.load(open(sys.argv[1]))
assert len(data["findings"]) == 1, data["findings"]
finding = data["findings"][0]
assert finding["kind"] == "malformed-marker", finding
assert finding["id"] == "reg:D1_T5", finding
d1 = next(r for r in data["directions"] if r["direction"] == "D1")
assert d1["total"] == 1, d1     # D1-T1 only -- the malformed marker is excluded
EOF

expect "malformed-marker: the finding reaches stderr in human mode too" 3 "malformed-marker" \
  -- python3 "$tool" "$fix/malformed-marker.json"

# --- defect (b): the directive lookup requires the stem 'directions' -------
# A directive that lives under any other document stem (the register renamed,
# or never named "directions" in the first place) must not produce a silent,
# empty, exit-0 report -- that is indistinguishable from a corpus that
# genuinely has no directions yet. The chosen fix: fail loudly (a finding +
# non-zero exit) whenever the direction set comes up empty, rather than
# widening "direction" to mean any directive anywhere in the corpus.
run_json "renamed-register: no directions found -> non-zero exit" 3 renamed-register

assert_py "renamed-register: the no-directions finding is reported, not silent" \
  "$tmp/renamed-register.json" <<'EOF'
import json, sys
data = json.load(open(sys.argv[1]))
assert data["directions"] == [], data["directions"]
assert len(data["findings"]) == 1, data["findings"]
assert data["findings"][0]["kind"] == "no-directions", data["findings"]
EOF

# --- defect (c): no-args CLI convention -------------------------------------
# The house pattern (check_scopes.sh, anchored_surface.sh) rejects a usage
# error by name at exit 2; convergence.py previously printed its docstring
# and returned 0, indistinguishable from a clean, empty measurement.
expect "no-args: usage error, exit 2, named by tool" 2 "convergence: missing corpus argument" \
  -- python3 "$tool"

expect "unreadable corpus: exit 2, not a traceback" 2 "cannot read corpus" \
  -- python3 "$tool" "$tmp/does-not-exist.json"

echo
if [ "$fails" -eq 0 ]; then echo "test_convergence: ALL PASS"; exit 0; fi
echo "test_convergence: $fails FAILURE(S)"; exit 1
