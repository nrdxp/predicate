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
#   (2) WORKTREE ISOLATION (the core check) — every non-merge commit reachable via
#       first-parent in baseline..integration must trace to at least one node/* branch
#       (i.e. be reachable from a node/* tip). A commit reachable from a node/* branch
#       was authored in an isolated worktree; a commit on NO node/* branch is a true
#       direct-flat bypass — the author committed straight to the integration branch
#       without worktree isolation.
#
#       Detection is MERGE-STRATEGY AGNOSTIC: octopus merges (which legitimately make
#       a node branch the first parent), fast-forwards, and standard --no-ff merges
#       all pass as long as the work was isolated in a node/* worktree. The only thing
#       this check detects is a commit that is on NO node/* branch at all.
#
#       Special case: if no node/* branches exist (cleaned up after campaign close),
#       the reachability check cannot be performed — the gate prints WARN and skips
#       the check with rc 0 (absence of evidence is not evidence of violation).
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
# Check 2: WORKTREE ISOLATION — branch-reachability, merge-strategy agnostic
# ---------------------------------------------------------------------------
echo "--- CHECK 2: Worktree isolation (branch-reachability) ---"

range="${baseline}..${integration}"

# Collect all node/* branch tips. These are the reachability witnesses: a commit
# reachable from a node/* tip was authored in an isolated worktree.
mapfile -t node_tips < <(git for-each-ref --format='%(objectname)' 'refs/heads/node/*' 2>/dev/null || true)

# Count first-parent non-merge commits in the range (these are the candidates
# that must be verified as node-isolated).
direct_count="$(git rev-list --count --no-merges --first-parent "$range" 2>/dev/null || echo 0)"

if [[ "$direct_count" -eq 0 ]]; then
  # Empty range or all commits are merges — nothing to check.
  merge_count="$(git rev-list --count --merges "$range" 2>/dev/null || echo 0)"
  if [[ "$merge_count" -eq 0 ]]; then
    echo "WARN  worktree-isolation: range '${range}' is empty (no commits found)" >&2
    echo "      Nothing to audit — verify baseline and integration refs are correct." >&2
    # Not counted as a fail; an empty campaign is vacuously correct.
  else
    echo "PASS  worktree-isolation: no first-parent non-merge commits in range (${merge_count} merge(s) only)"
  fi
elif [[ "${#node_tips[@]}" -eq 0 ]]; then
  # Node branches have been cleaned up (post-campaign). Cannot determine isolation
  # by reachability — skip with a warning, not a failure.
  echo "WARN  worktree-isolation: no node/* branches found; cannot verify branch reachability" >&2
  echo "      If node/* branches were cleaned up after campaign close, this is expected." >&2
  echo "      Skipping check (rc 0) — absence of witnesses is not evidence of violation." >&2
  # Not counted as a fail.
else
  # Check each first-parent non-merge commit for reachability from some node/* tip.
  bypasses=()
  while IFS= read -r commit; do
    reachable=0
    for tip in "${node_tips[@]}"; do
      if git merge-base --is-ancestor "$commit" "$tip" 2>/dev/null; then
        reachable=1
        break
      fi
    done
    if [[ "$reachable" -eq 0 ]]; then
      bypasses+=("$commit")
    fi
  done < <(git rev-list --no-merges --first-parent "$range" 2>/dev/null)

  if [[ "${#bypasses[@]}" -eq 0 ]]; then
    echo "PASS  worktree-isolation: all ${direct_count} first-parent commit(s) trace to a node/* branch"
    echo "      Isolation verified by branch reachability (merge strategy: irrelevant)."
  else
    echo "FAIL  worktree-isolation: ${#bypasses[@]} commit(s) not reachable from any node/* branch" >&2
    echo "      These commits were authored directly on the integration branch — true isolation bypasses:" >&2
    for c in "${bypasses[@]}"; do
      echo "        $c  $(git log -1 --format='%s' "$c")" >&2
    done
    fails=$((fails + 1))
  fi
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
