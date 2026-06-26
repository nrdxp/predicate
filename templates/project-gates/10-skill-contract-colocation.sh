#!/usr/bin/env bash
# 10-skill-contract-colocation.sh — project-local gate for predicate itself.
#
# Enforces the skill-contract colocation decision: five workflow-owned Nickel
# contracts were moved from ledger/contracts/ into their owning skill directory
# by the skill-contract-relocate campaign node. This gate fails if any of those
# five names reappears in ledger/contracts/, which would silently re-centralize
# a skill-owned contract and unravel the self-contained-skills invariant.
#
# Gate interface (project-gates.sh runner contract):
#   $1 = absolute path to the project root
#   exit 0 = gate passes (none of the five names are present in ledger/contracts/)
#   exit 1 = gate fails (one or more skill-owned contracts have been re-centralized)
#
# Template source: templates/project-gates/ (tracked; installed by bootstrap/install.sh init)
# Runtime location: <project>/.ledger/gates/ (per-project, gitignored)
set -euo pipefail

root="${1:?colocation-gate: usage: $0 <project-root>}"

contracts_dir="$root/ledger/contracts"

# The five skill-owned contracts that must NOT live in ledger/contracts/.
# Each was relocated to its owning skill directory; re-centralizing any one
# undoes the self-contained-skills invariant without the gate catching it.
#
#   skills/boundary/boundary_procedure.ncl
#   skills/refine/refine_procedure.ncl
#   skills/refine/refine_output.ncl
#   skills/orchestration/state_machine.ncl
#   skills/orient/tracker_freshness.ncl
skill_owned_names=(
  boundary_procedure.ncl
  refine_procedure.ncl
  refine_output.ncl
  state_machine.ncl
  tracker_freshness.ncl
)

found=()
for name in "${skill_owned_names[@]}"; do
  if [[ -f "$contracts_dir/$name" ]]; then
    found+=("$name")
  fi
done

if [[ "${#found[@]}" -gt 0 ]]; then
  echo "colocation-gate: FAIL — skill-owned contract(s) re-centralized in ledger/contracts/:" >&2
  for f in "${found[@]}"; do
    echo "  ledger/contracts/$f  (belongs in the owning skill's directory)" >&2
  done
  echo "colocation-gate: Move each contract back to its skill dir (e.g. skills/<skill>/<name>.ncl)." >&2
  exit 1
fi

exit 0
