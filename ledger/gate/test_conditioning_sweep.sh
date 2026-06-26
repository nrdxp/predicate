#!/usr/bin/env bash
# Conditioning-layer sweep — asserts every conditioning/*.ncl behaves per its
# declared polarity, machine-guarding the HasCore injection-rule proof.
#
# Three files live in conditioning/:
#   core.ncl          — the invariant-core string; exports cleanly (positive).
#   compose.ncl       — generates all role prompts; exports cleanly (positive).
#   probe_no_core.ncl — negative control (# EXPECT: fail): a tampered persona
#                       stripped of core_text must fail export, proving the
#                       HasCore contract bites.
#
# The same polarity semantics as test_fixture_sweep.sh apply: if a file carries
# `# EXPECT: fail` (leading whitespace allowed) its export is expected to be
# non-zero; anything else must export cleanly.  ledger-validate.sh structure
# implements the inversion, so rc 0 from that command always means "behaved per
# declared polarity".
#
# Usage: test_conditioning_sweep.sh
# Exit:  0 = every file behaved per its declared polarity
#        1 = one or more polarities mismatched
#        2 = environment error (nickel / validate script not found)
set -u

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
validate="$here/ledger-validate.sh"

if [[ ! -x "$validate" ]]; then
  echo "FAIL (env): ledger-validate.sh not found at $validate" >&2
  exit 2
fi

fails=0
total=0

for f in "$root"/conditioning/*.ncl; do
  [[ -f "$f" ]] || continue
  name="$(basename "$f")"
  total=$((total + 1))

  result=$(bash "$validate" structure "$f" 2>&1)
  rc=$?

  if [[ "$rc" -eq 0 ]]; then
    echo "PASS  $name"
  else
    echo "FAIL  $name (ledger-validate rc=$rc)"
    if [[ -n "$result" ]]; then
      printf '%s\n' "$result" | sed 's/^/      /'
    fi
    fails=$((fails + 1))
  fi
done

echo ""
echo "Conditioning sweep: $((total - fails))/$total passed"
if [[ "$fails" -ne 0 ]]; then
  echo "FAIL: $fails file(s) did not behave per declared polarity"
  exit 1
fi
echo "PASS: all conditioning files behaved per declared polarity"
exit 0
