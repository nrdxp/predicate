#!/usr/bin/env bash
# Process-adherence gate — deterministic audit of whether the campaign execution
# protocol was actually followed, from git history alone.
#
# This gate exists because the Verification Dual's "externalize the check" principle
# applies to the PROCESS, not just the output: a rationalizing agent cannot be stopped
# by self-imposed rules — only by a machine check it does not control. A campaign that
# ran flat on the integration branch (direct commits, no worktree isolation) is
# indistinguishable by its CONTENT from a correctly-isolated one; it is distinguishable
# by its HISTORY. This gate reads the history.
#
# Usage:
#   adherence_audit.sh <baseline-ref> [<integration-ref=HEAD>]
#
#   <baseline-ref>    the commit the campaign branched FROM (e.g. the pre-campaign tip)
#   <integration-ref> the campaign branch to audit (default: HEAD)
#
# Checks (machine-verifiable from git history):
#
#   (1) INTEGRATION BRANCH — <integration-ref> must resolve to a ref whose symbolic
#       name is a campaign/* branch, not master/main. Campaign work committed directly
#       to master means the integration-branch invariant was violated.
#
#   (2) MERGE DISCIPLINE (the core check) — node work must arrive via --no-ff merges
#       from node/<id> branches, NOT as direct commits on the integration mainline.
#       Heuristic: count the merge commits (--merges) in the range and the direct
#       mainline commits (--no-merges --first-parent). The invariant is:
#
#         merges > 0  AND  direct_mainline == 0
#
#       Why this pair, not just "merges > 0"?
#         - "merges > 0" alone would pass a history with both node merges AND direct
#           mainline commits — mixed isolation (some nodes isolated, some not).
#         - "--first-parent --no-merges" counts commits whose first parent is on the
#           integration mainline itself — the structural signature of a direct-push
#           bypass. A properly isolated campaign has ZERO such commits; all node work
#           enters via merge commits whose second parent is the node branch tip.
#         - Together they express: "isolation was the exclusive mechanism" rather than
#           "isolation was used at least once."
#
#       The check is robust to large campaigns: it is O(n) over commit count, uses
#       only portable git-log flags (--merges, --no-merges, --first-parent, --count),
#       and makes no assumptions about branch names surviving in the remote.
#
# Exit codes: 0 (PASS) / 1 (FAIL with diagnostic)

set -uo pipefail

# Resolve THIS script's own real directory (symlink-safe) so any future sibling
# machinery is located relative to where the PLUGIN lives — the P21 self-location
# pattern used by ledger-validate.sh and coherence_impact.sh.
here="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" && pwd)"
# (here is available for future sibling invocations; unused by this pure-git gate)
readonly here

# ---------------------------------------------------------------------------
# Arguments
# ---------------------------------------------------------------------------
baseline="${1:-}"
integration="${2:-HEAD}"

if [[ -z "$baseline" ]]; then
  echo "usage: adherence_audit.sh <baseline-ref> [<integration-ref=HEAD>]" >&2
  exit 2
fi

# Verify both refs resolve
if ! git rev-parse --verify "$baseline" >/dev/null 2>&1; then
  echo "adherence_audit: cannot resolve baseline ref: $baseline" >&2
  exit 2
fi
if ! git rev-parse --verify "$integration" >/dev/null 2>&1; then
  echo "adherence_audit: cannot resolve integration ref: $integration" >&2
  exit 2
fi

fails=0

# ---------------------------------------------------------------------------
# Check 1: INTEGRATION BRANCH
# <integration-ref> must be a campaign/* branch, not master/main.
# ---------------------------------------------------------------------------
echo "--- CHECK 1: Integration-branch identity ---"

# Resolve the ref to a branch name (works whether integration is a branch name
# already or a symbolic ref). Falls back to empty if it is a detached commit.
branch_name=""
if [[ "$integration" == "HEAD" ]]; then
  branch_name="$(git symbolic-ref --short HEAD 2>/dev/null || true)"
else
  # If the caller passed a branch name directly, use it; otherwise try to map
  # the commit to a branch (best-effort via name-rev).
  branch_name="$(git rev-parse --abbrev-ref "$integration" 2>/dev/null || true)"
fi

if [[ -z "$branch_name" ]]; then
  echo "FAIL  integration-branch: cannot resolve a branch name for '$integration'" \
    "(detached HEAD or unknown ref — campaign integration must be a named branch)" >&2
  fails=$((fails + 1))
elif [[ "$branch_name" == "master" || "$branch_name" == "main" ]]; then
  echo "FAIL  integration-branch: '$branch_name' is a mainline branch, not a campaign/* branch" >&2
  echo "      Campaign work committed directly to $branch_name violates the integration-branch invariant." >&2
  fails=$((fails + 1))
elif [[ "$branch_name" != campaign/* ]]; then
  echo "FAIL  integration-branch: '$branch_name' is not a campaign/* branch" >&2
  echo "      Expected a branch matching 'campaign/<topic>'; found '$branch_name'." >&2
  fails=$((fails + 1))
else
  echo "PASS  integration-branch: '$branch_name' is a campaign/* branch"
fi

# ---------------------------------------------------------------------------
# Check 2: MERGE DISCIPLINE (the core check — isolation via --no-ff)
# ---------------------------------------------------------------------------
echo "--- CHECK 2: Merge discipline (worktree isolation) ---"

range="${baseline}..${integration}"

# Count --no-ff merge commits in range (these are the node-branch landing merges)
merge_count="$(git rev-list --count --merges "$range" 2>/dev/null || echo 0)"

# Count direct commits on the integration mainline (first-parent, not from a merge).
# --first-parent --no-merges gives commits whose immediate parent IS the mainline
# tip — the structural fingerprint of a direct commit / direct push, not a merge.
direct_count="$(git rev-list --count --no-merges --first-parent "$range" 2>/dev/null || echo 0)"

echo "  Merge commits (node landings) in ${range}: ${merge_count}"
echo "  Direct mainline commits (isolation bypasses) in ${range}: ${direct_count}"

if [[ "$merge_count" -eq 0 && "$direct_count" -eq 0 ]]; then
  # Empty range — no work at all in the range is neither a pass nor a failure
  # of isolation; surface it explicitly so the caller can decide.
  echo "WARN  merge-discipline: range '${range}' is empty (no commits found)" >&2
  echo "      Nothing to audit — verify baseline and integration refs are correct." >&2
  # Not counted as a fail; an empty campaign is vacuously correct.
elif [[ "$merge_count" -eq 0 ]]; then
  # Work exists but arrived entirely as direct commits — isolation was never used.
  echo "FAIL  merge-discipline: ${direct_count} direct mainline commit(s) found," \
    "ZERO node/* merges" >&2
  echo "      Worktree isolation was bypassed: all node work was committed directly" >&2
  echo "      to the integration mainline instead of arriving via 'git merge --no-ff" >&2
  echo "      node/<id>'. The campaign ran FLAT — the protocol was not followed." >&2
  fails=$((fails + 1))
elif [[ "$direct_count" -gt 0 ]]; then
  # Mixed history: some nodes isolated, others direct-committed — partial bypass.
  echo "FAIL  merge-discipline: ${direct_count} direct mainline commit(s) found" \
    "alongside ${merge_count} node merge(s)" >&2
  echo "      Mixed isolation: some node work arrived via --no-ff merges but" >&2
  echo "      ${direct_count} commit(s) were pushed directly to the integration" >&2
  echo "      mainline, bypassing worktree isolation for those contributions." >&2
  fails=$((fails + 1))
else
  # merge_count > 0 AND direct_count == 0 — canonical isolated history
  echo "PASS  merge-discipline: ${merge_count} node merge(s), 0 direct mainline commits"
  echo "      All node work arrived via --no-ff merges; worktree isolation maintained."
fi

# ---------------------------------------------------------------------------
# Verdict
# ---------------------------------------------------------------------------
echo "---"
if [[ "$fails" -ne 0 ]]; then
  echo "FAIL  adherence_audit: ${fails} check(s) failed — execution protocol was not followed"
  exit 1
fi
echo "PASS  adherence_audit: execution protocol checks passed"
exit 0
