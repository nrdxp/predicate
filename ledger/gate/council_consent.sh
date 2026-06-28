#!/usr/bin/env bash
# Merge-consent gate — deterministic precondition for the orchestration MERGE state.
#
# Green deterministic gates are NECESSARY but never SUFFICIENT to land a node: the
# lead maintainer must affirmatively consent to the merge. This gate machine-enforces
# that floor over a decision-ledger YAML instance — a `'merge decision whose recorded
# `assent` omits the maintainer FAILS; a consented one PASSES.
#
# Degrade-to-primitive: the verdict is NOT re-derived here. council.ncl already encodes
# the law (`must_assent = ["maintainer"]` on the merge DelegationRule, named by the
# `merge-consent:` reason); this gate REDUCES to it by exporting the ledger through the
# shape-dispatching apply-file —
#   nickel export <ledger>.yaml --apply-contract ledger/contracts/council_apply.ncl
# — and reading that export's exit code. There is no hand-rolled assent-membership check
# standing in for the contract; a second source of the law would be a defeater against
# council.ncl being THE law.
#
# A non-zero export is only treated as a consent failure when the error specifically
# names the `merge-consent:` guard. An export that fails for any OTHER reason (a shape
# error, a different invariant, an env fault) is NOT a consent verdict and is surfaced
# as an environment error (rc 2), so an incidental failure cannot masquerade as a
# maintainer-consent verdict.
#
# Usage:
#   council_consent.sh <decision-ledger.yaml>
#
#   <decision-ledger.yaml>  a pure-data decisions-ledger YAML instance (the apply-file
#                           threads the canonical constitution).
#
# Exit codes: 0 (PASS — every merge decision carries the maintainer's assent)
#             1 (FAIL — a 'merge decision lacks the maintainer's recorded assent)
#             2 (usage or environment error — missing arg/file, nickel absent, or an
#                export failure that does NOT name the merge-consent guard)
set -uo pipefail

# ---------------------------------------------------------------------------
# Arguments + environment
# ---------------------------------------------------------------------------
ledger="${1:-}"

if [[ -z "$ledger" ]]; then
  echo "usage: council_consent.sh <decision-ledger.yaml>" >&2
  echo "council_consent: no ledger given — cannot check merge consent without an instance" >&2
  exit 2
fi

if [[ ! -f "$ledger" ]]; then
  echo "council_consent: ledger file not found: $ledger" >&2
  exit 2
fi

# The apply-file lives beside this gate's repo root; resolve it from the script's own
# location so the gate is runnable from any cwd (mirrors test_council.sh).
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
apply="$root/ledger/contracts/council_apply.ncl"

command -v nickel >/dev/null 2>&1 || {
  echo "council_consent: nickel not found on PATH — the gate reduces to council.ncl and cannot run without it" >&2
  exit 2
}
if [[ ! -f "$apply" ]]; then
  echo "council_consent: apply-file missing: $apply" >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# Reduce to the law: export the ledger through the apply-contract. Capture the exit
# code IMMEDIATELY after the export — no intervening command may run between the
# `nickel export` and its `$?` read, or the code is clobbered.
# ---------------------------------------------------------------------------
out="$(nickel export "$ledger" --apply-contract "$apply" 2>&1)"
rc=$?

if [[ "$rc" -eq 0 ]]; then
  echo "PASS  merge-consent: '$ledger' — every 'merge decision carries the maintainer's recorded assent"
  exit 0
fi

# Non-zero export. Only a failure that NAMES the merge-consent guard is a consent
# verdict; anything else is an incidental error that must not pose as one.
if printf '%s\n' "$out" | grep -q -- 'merge-consent'; then
  echo "FAIL  merge-consent: '$ledger' has a 'merge decision lacking the maintainer's recorded assent —" >&2
  echo "      green gates are necessary but never sufficient; a merge requires the lead" >&2
  echo "      maintainer's affirmative consent (assent must include 'maintainer'). Record" >&2
  echo "      the maintainer's assent on the merge decision, then re-run." >&2
  echo "      ---- council.ncl verdict ----" >&2
  printf '%s\n' "$out" | sed 's/^/      /' >&2
  exit 1
fi

echo "council_consent: export of '$ledger' failed for a reason OTHER than merge-consent —" >&2
echo "      this is not a consent verdict (a shape error, a different invariant, or an env" >&2
echo "      fault). Resolve the underlying export error before reading a consent result." >&2
echo "      ---- nickel export output ----" >&2
printf '%s\n' "$out" | sed 's/^/      /' >&2
exit 2
