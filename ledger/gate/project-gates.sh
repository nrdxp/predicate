#!/usr/bin/env bash
# Project-local gate runner — discovers and runs gates declared in the
# consuming project's .ledger/gates/ directory.
#
# A project with no .ledger/gates/ directory (or no executable files
# therein) is a clean NO-OP — the mechanism is opt-in and unaffected
# projects incur zero overhead.
#
# Gate script interface contract
# ───────────────────────────────
#   Location:    <project-root>/.ledger/gates/<name>   (executable file)
#   Argument:    $1 = absolute path to the gated project root
#   Exit code:   0 = gate passes; non-0 = gate fails
#   Diagnostics: to stderr, naming the failing condition
#
# Discovery: all executable files in .ledger/gates/ (maxdepth 1), executed
# in sorted name order.  Authors control sequence with a numeric prefix
# (e.g. 01-lint.sh, 02-validate.sh) — no manifest needed.  Non-executable
# files are silently skipped, so README.md or a config file can live in the
# same directory without triggering a gate run.
#
# Zero predicate-idiosyncrasy: this runner ships as general infrastructure.
# It knows nothing about any specific project's rules; those live entirely
# in the gate scripts the project deposits in .ledger/gates/.
#
# Usage:
#   project-gates.sh <repo-root>
#
# Exit: 0 = all local gates passed (or none declared),
#       1 = one or more local gates failed,
#       2 = usage error.
set -u

root="${1:-}"
if [[ -z "$root" ]]; then
  echo "project-gates: usage: project-gates.sh <repo-root>" >&2
  exit 2
fi
if [[ ! -d "$root" ]]; then
  echo "project-gates: repo root not found: $root" >&2
  exit 2
fi

gates_dir="$root/.ledger/gates"

# No .ledger/gates/ directory → clean no-op (the opt-in invariant).
[[ -d "$gates_dir" ]] || exit 0

rc=0
# Collect all executable files directly under .ledger/gates/ (maxdepth 1)
# and execute them in sorted name order.  Each gate receives $root as $1.
while IFS= read -r gate; do
  gate_name="$(basename "$gate")"
  "$gate" "$root"
  gate_rc=$?
  if [[ "$gate_rc" -ne 0 ]]; then
    echo "project-gate: FAILED: $gate_name (exit $gate_rc)" >&2
    rc=1
  fi
done < <(find "$gates_dir" -maxdepth 1 -type f -executable | LC_ALL=C sort)

exit "$rc"
