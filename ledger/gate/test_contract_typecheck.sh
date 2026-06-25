#!/usr/bin/env bash
# Contract typecheck sweep — asserts every ledger/contracts/*.ncl is well-typed.
#
# Contract files define Nickel types and functions; they are not directly
# serializable, so `nickel typecheck` is the correct gate (not `nickel export`).
# ledger-validate.sh structure auto-detects the contracts/ path and applies
# typecheck; this script drives it across the full set.
#
# A failing assertion means a contract is malformed — a prerequisite failure
# for every fixture that imports it.  Catching this here, independently of the
# fixture sweep, makes the failure site unambiguous: the contract itself is
# broken, not the fixture that uses it.
#
# Adding a new file to ledger/contracts/ automatically extends this sweep.
#
# Usage: test_contract_typecheck.sh
# Exit:  0 = every contract typechecks cleanly
#        1 = one or more contracts failed typecheck
#        2 = environment error (validate script not found)
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

# Run the structure check on one contract file; append to totals.
check_contract() {
  local contract="$1"
  [[ -f "$contract" ]] || return
  local name
  name="$(basename "$contract")"
  total=$((total + 1))

  local result
  result=$(bash "$validate" structure "$contract" 2>&1)
  local rc=$?

  if [[ "$rc" -eq 0 ]]; then
    echo "PASS  $name"
  else
    echo "FAIL  $name (typecheck rc=$rc)"
    if [[ -n "$result" ]]; then
      printf '%s\n' "$result" | sed 's/^/      /'
    fi
    fails=$((fails + 1))
  fi
}

# Central substrate contracts (ledger/contracts/).
echo "-- ledger/contracts/ --"
for contract in "$root"/ledger/contracts/*.ncl; do
  check_contract "$contract"
done

# Skill-owned contracts relocated from ledger/contracts/ (skill colocation).
# Each skill directory holds its own workflow contracts as first-class files.
echo "-- skill-owned contracts --"
for skill_dir in \
    "$root/skills/boundary" \
    "$root/skills/refine" \
    "$root/skills/orchestration" \
    "$root/skills/orient"; do
  for contract in "$skill_dir"/*.ncl; do
    check_contract "$contract"
  done
done

echo ""
echo "Contract typecheck: $((total - fails))/$total passed"
if [[ "$fails" -ne 0 ]]; then
  echo "FAIL: $fails contract(s) failed typecheck"
  exit 1
fi
echo "PASS: all contracts typecheck cleanly"
exit 0
