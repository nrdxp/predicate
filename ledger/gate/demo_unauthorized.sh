#!/usr/bin/env bash
# Reproducible demonstration of the authority gate (C-P4.1 / AC-P4.1):
# a staged change with no authorizing DAG node makes the commit gate exit
# non-zero. This is the baseline dE0 != 0 the gate exists to produce.
#
# The demo stages a file under a path no node's file_surface covers
# (src/feature/<rand>.py), runs the gate, asserts a non-zero exit, then
# unstages and removes the file so the working tree is left clean. It also
# runs the positive control: the gate's own files (under ledger/, authorized
# by node P3) must pass.
#
# Run from the repo root. Exit 0 iff the gate behaved as specified
# (deny unauthorized, allow authorized); exit 1 if either assertion failed.
set -euo pipefail

root="$(git rev-parse --show-toplevel)"
cd "$root"
gate="ledger/gate/ledger-validate.sh"
dag="ledger/examples/dag.ncl"

fail=0

# --- negative case: unauthorized staged change must be denied --------------
rogue="src/feature/rogue_$$_$RANDOM.py"
mkdir -p "$(dirname "$rogue")"
echo "print('unauthorized work')" >"$rogue"
git add "$rogue"

rc=0
"$gate" commit-gate "$dag" || rc=$?
echo "unauthorized commit-gate rc=$rc (expect non-zero)"
if [[ "$rc" -eq 0 ]]; then
  echo "ASSERT FAIL: unauthorized change was allowed"
  fail=1
fi

# cleanup the negative fixture regardless of outcome
git restore --staged "$rogue" 2>/dev/null || git reset -q HEAD "$rogue" 2>/dev/null || true
rm -f "$rogue"
rmdir "$(dirname "$rogue")" 2>/dev/null || true

# --- positive control: an authorized path must pass -----------------------
rc=0
"$gate" authorize "$dag" ledger/gate/ledger-validate.sh || rc=$?
echo "authorized authorize rc=$rc (expect 0)"
if [[ "$rc" -ne 0 ]]; then
  echo "ASSERT FAIL: authorized path was denied"
  fail=1
fi

if [[ "$fail" -eq 0 ]]; then
  echo "DEMO PASS: gate denies unauthorized, allows authorized"
fi
exit "$fail"
