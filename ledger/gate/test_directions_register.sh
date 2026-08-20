#!/usr/bin/env bash
# Suite for ledger/gate/directions_register.py -- closes the gate half of
# tech-debt/directions-half-conditioned.yaml under the head's ruling AI5
# (.ledger/state/decisions-architect-intake.yaml): a corpus holding graded
# claims with an absent or empty directions register is an error, and a
# direction carrying zero terminal questions is an error. Whole-corpus form,
# never per-claim attribution -- [DX1] stands.
#
# Fixtures are synthetic, standalone corpora under
# ledger/fixtures/directions_register/ (never the live .ledger/ -- gitignored,
# moves under concurrent work, and the live corpus is independently known to
# carry a pre-existing malformed node under a separate head ruling, AI12;
# pinning this suite to it would fail for reasons unrelated to this code, the
# same reasoning ledger/gate/test_terminal_freshness.sh gives for its own
# fixtures).
#
#   empty_register/             a graded claim, no directions register at
#                                all -- MUST be reported and MUST exit 1.
#   no_terminal_targets/        a populated register whose one direction
#                                carries zero terminal targets -- MUST be
#                                reported and MUST exit 1.
#   clean/                      a graded claim, a register with one
#                                direction carrying one terminal target --
#                                not a violation.
#   questions_only_no_register/ a graded QUESTION, no claim, no register --
#                                not a violation: AI5 gates the empty-register
#                                error on claims, not on any graded node.
#
# Usage: test_directions_register.sh
# Exit:  0 = every case matched, 1 = a case mismatched, 2 = environment error.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
tool="$root/ledger/gate/directions_register.py"
fix="$root/ledger/fixtures/directions_register"

command -v python3 >/dev/null 2>&1 || { echo "ENV: python3 not found on PATH"; exit 2; }
for f in empty_register no_terminal_targets clean questions_only_no_register; do
  [ -d "$fix/$f" ] || { echo "ENV: fixture dir missing: $fix/$f"; exit 2; }
done

fails=0
# expect DESC EXPECTED-RC KEYWORD -- COMMAND...
#   KEYWORD="" skips the message check.
expect() {
  local desc="$1" exp="$2" kw="$3"; shift 3
  [ "$1" = "--" ] && shift
  local out rc ok=1
  out="$("$@" 2>&1)"; rc=$?
  [ "$rc" -eq "$exp" ] || ok=0
  if [ -n "$kw" ]; then printf '%s' "$out" | grep -q -- "$kw" || ok=0; fi
  if [ "$ok" -eq 1 ]; then
    echo "PASS  ($rc) $desc"
  else
    echo "FAIL  (got rc=$rc want $exp; want-kw='$kw') $desc"
    printf '%s\n' "$out" | tail -8
    fails=$((fails + 1))
  fi
}

[ -f "$tool" ] || { echo "ENV: tool missing: $tool"; exit 2; }

expect "a nonexistent corpus path is an environment error" 2 "" \
  -- python3 "$tool" "$fix/does-not-exist"

expect "claims with no directions register at all: reported, exit 1" 1 \
  "empty-register" \
  -- python3 "$tool" "$fix/empty_register"

expect "a direction with zero terminal targets: reported, exit 1" 1 \
  "no-terminal-questions" \
  -- python3 "$tool" "$fix/no_terminal_targets"

expect "a direction with zero terminal targets: names the direction" 1 \
  "D1" \
  -- python3 "$tool" "$fix/no_terminal_targets"

expect "a populated register with a real target: clean, exit 0" 0 "" \
  -- python3 "$tool" "$fix/clean"

expect "questions with no register, no claims: not a violation, exit 0" 0 "" \
  -- python3 "$tool" "$fix/questions_only_no_register"

# --- mutation: the clean fixture, mechanically emptied ----------------------
#
# Proves the check is not decoration by construction: start from the SAME
# clean fixture that passes above, mechanically strip its one terminal
# target, and show the identical tool flips from PASS to FAIL.

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/mutated"
cp "$fix/clean/claim.md" "$tmp/mutated/claim.md"
# Drop the D1-T1 paragraph entirely -- D1 survives, its one target does not.
awk 'BEGIN{skip=0} /^`\[D1-T1\]/{skip=1} skip && /^$/{skip=0; next} !skip' \
  "$fix/clean/directions.md" > "$tmp/mutated/directions.md"
grep -q 'D1-T1' "$tmp/mutated/directions.md" \
  && { echo "ENV: mutation did not strip D1-T1 -- fixture drifted"; exit 2; }

expect "the clean fixture, mutated to strip its target, goes red" 1 \
  "no-terminal-questions" \
  -- python3 "$tool" "$tmp/mutated"

echo
if [ "$fails" -eq 0 ]; then echo "test_directions_register: ALL PASS"; exit 0; fi
echo "test_directions_register: $fails FAILURE(S)"; exit 1
