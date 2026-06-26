#!/usr/bin/env bash
# Synthetic-history tests for adherence_audit.sh — four cases that prove the
# branch-reachability check is merge-strategy agnostic.
#
# Each case builds a minimal git repo in a temp directory, constructs a history
# that represents a specific scenario, and asserts the audit's exit code.
#
#   (a) Octopus merge with a node/* branch as first parent  -> PASS (rc 0)
#   (b) Fast-forward landing of a node/* branch              -> PASS (rc 0)
#   (c) Direct commit on the integration branch (no node/*)  -> FAIL (rc 1)
#   (d) No node/* branches exist (post-cleanup)              -> WARN/skip (rc 0)
#
# Usage: test_adherence.sh
# Exit:  0 = every case matched, 1 = a case mismatched, 2 = environment error.
set -u

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
audit="$here/adherence_audit.sh"

if [[ ! -x "$audit" ]]; then
  echo "ERROR: adherence_audit.sh not found or not executable at $audit" >&2
  exit 2
fi

fails=0

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
expect() { # description expected-rc -- command...
  local desc="$1" exp="$2"; shift 2
  "$@" >/dev/null 2>&1; local rc=$?
  if [[ "$rc" -eq "$exp" ]]; then
    echo "PASS  (rc=$rc) $desc"
  else
    echo "FAIL  (got rc=$rc, want rc=$exp) $desc"
    # Re-run with output visible for diagnosis
    "$@" >&2 || true
    fails=$((fails + 1))
  fi
}

# Build a minimal git repo with a fixed author identity and timestamp so
# hashes are deterministic (not actually required for correctness, but
# avoids wall-clock dependency).
make_repo() {
  local dir="$1"
  mkdir -p "$dir"
  git -C "$dir" init -q -b master
  git -C "$dir" config user.email "test@adherence.example"
  git -C "$dir" config user.name  "Adherence Test"
  # Simulate a campaign in flight: adherence_audit is active-campaign-gated (it
  # keys on .ledger/active-dag, like the commit-gate authority overlay), so the
  # check-bearing cases below must declare an active campaign to exercise it.
  # Case (e) removes this to test the no-campaign skip.
  mkdir -p "$dir/.ledger"; : > "$dir/.ledger/active-dag"
}

# Commit a file with a fixed timestamp so the test never depends on wall clock.
FIXED_DATE="2000-01-01T00:00:00+00:00"
commit_file() { # repo message [filename]
  local repo="$1" msg="$2" fname="${3:-file.txt}"
  echo "$msg" >> "$repo/$fname"
  git -C "$repo" add "$fname"
  GIT_AUTHOR_DATE="$FIXED_DATE" GIT_COMMITTER_DATE="$FIXED_DATE" \
    git -C "$repo" commit -q -m "$msg"
}

# ---------------------------------------------------------------------------
# Set up scratch space
# ---------------------------------------------------------------------------
scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT

# ---------------------------------------------------------------------------
# Case (a): Octopus merge — node/* branch is the first parent
#
# History shape:
#   master: B0 (baseline)
#   campaign/test: B0 -> Mc (octopus merge of node/alpha and node/beta;
#                            node/alpha is the first parent)
#   node/alpha: B0 -> Ca (the work commit)
#   node/beta:  B0 -> Cb
#
# git rev-list --no-merges --first-parent B0..campaign/test yields Ca
# (first parent of the octopus is node/alpha tip). Ca IS reachable from
# node/alpha — should PASS.
# ---------------------------------------------------------------------------
repo_a="$scratch/octopus"
make_repo "$repo_a"
commit_file "$repo_a" "baseline"                     # B0 on master

# Create node/alpha and node/beta from B0
git -C "$repo_a" checkout -q -b node/alpha
commit_file "$repo_a" "work-alpha" "alpha.txt"       # Ca

git -C "$repo_a" checkout -q master
git -C "$repo_a" checkout -q -b node/beta
commit_file "$repo_a" "work-beta" "beta.txt"         # Cb

# Create the integration branch and octopus-merge both node branches.
# The octopus merge: first parent = node/alpha (the branch we merge FROM),
# additional parents = node/beta. We achieve this by checking out node/alpha
# and merging node/beta into it as the campaign branch.
git -C "$repo_a" checkout -q node/alpha
git -C "$repo_a" checkout -q -b campaign/test
GIT_AUTHOR_DATE="$FIXED_DATE" GIT_COMMITTER_DATE="$FIXED_DATE" \
  git -C "$repo_a" merge -q --no-edit node/beta -m "octopus: land node/alpha + node/beta"

baseline_a="$(git -C "$repo_a" rev-parse master)"
expect "(a) octopus merge — node/* as first parent" 0 \
  bash -c "cd '$repo_a' && bash '$audit' '$baseline_a' campaign/test"

# ---------------------------------------------------------------------------
# Case (b): Fast-forward — node/* branch landing
#
# History shape:
#   master:       B0
#   node/work:    B0 -> Cw
#   campaign/ff:  B0 -> Cw (fast-forward; campaign/ff tip == node/work tip)
#
# git rev-list --no-merges --first-parent B0..campaign/ff yields Cw.
# Cw IS reachable from node/work — should PASS.
# ---------------------------------------------------------------------------
repo_b="$scratch/ff"
make_repo "$repo_b"
commit_file "$repo_b" "baseline"

git -C "$repo_b" checkout -q -b node/work
commit_file "$repo_b" "work" "work.txt"

# Fast-forward: campaign/ff is just node/work advanced to the same tip.
git -C "$repo_b" checkout -q master
git -C "$repo_b" checkout -q -b campaign/ff
git -C "$repo_b" merge -q --ff-only node/work

baseline_b="$(git -C "$repo_b" rev-parse master)"
expect "(b) fast-forward node/* landing" 0 \
  bash -c "cd '$repo_b' && bash '$audit' '$baseline_b' campaign/ff"

# ---------------------------------------------------------------------------
# Case (c): True direct bypass — commit authored straight on campaign branch
#
# History shape:
#   master:       B0
#   node/side:    B0 -> Cs  (isolated; not merged)
#   campaign/bad: B0 -> Cd  (direct commit — NOT on node/side)
#
# git rev-list --no-merges --first-parent B0..campaign/bad yields Cd.
# Cd is NOT reachable from node/side — should FAIL (rc 1).
# ---------------------------------------------------------------------------
repo_c="$scratch/direct"
make_repo "$repo_c"
commit_file "$repo_c" "baseline"

# A node branch exists but its work was never merged — direct commit instead.
git -C "$repo_c" checkout -q -b node/side
commit_file "$repo_c" "side-work" "side.txt"
git -C "$repo_c" checkout -q master

git -C "$repo_c" checkout -q -b campaign/bad
commit_file "$repo_c" "direct bypass" "bad.txt"     # Cd — not on any node/* branch

baseline_c="$(git -C "$repo_c" rev-parse master)"
expect "(c) direct bypass — commit on no node/* branch" 1 \
  bash -c "cd '$repo_c' && bash '$audit' '$baseline_c' campaign/bad"

# ---------------------------------------------------------------------------
# Case (d): No node/* branches — isolation cannot be verified, WARN+skip
#
# History shape:
#   master:        B0
#   campaign/gone: B0 -> Cx  (commit exists, but node/* branches all cleaned up)
#
# The audit has no reachability witnesses. It must WARN and return rc 0
# (not fail — absence of branches is not evidence of violation).
# ---------------------------------------------------------------------------
repo_d="$scratch/no-nodes"
make_repo "$repo_d"
commit_file "$repo_d" "baseline"

git -C "$repo_d" checkout -q -b campaign/gone
commit_file "$repo_d" "work on campaign" "work.txt"
# No node/* branches created at all.

baseline_d="$(git -C "$repo_d" rev-parse master)"
expect "(d) no node/* branches — WARN, skip, rc 0" 0 \
  bash -c "cd '$repo_d' && bash '$audit' '$baseline_d' campaign/gone"

# ---------------------------------------------------------------------------
# Case (e): No active campaign — audit is not applicable, skip (rc 0)
#
# Even on master with a direct commit (which CHECK 1 would reject DURING a
# campaign), the absence of a .ledger/active-dag pointer means no campaign is in
# flight — a human committing to master is not a protocol violation. The audit
# must SKIP (rc 0), not fail. This encodes the active-campaign conditioning.
# ---------------------------------------------------------------------------
repo_e="$scratch/no-campaign"
make_repo "$repo_e"
commit_file "$repo_e" "baseline"
commit_file "$repo_e" "direct work on master" "m.txt"   # direct commit on master
rm -f "$repo_e/.ledger/active-dag"                       # no campaign in flight
baseline_e="$(git -C "$repo_e" rev-parse HEAD~1)"
expect "(e) no active campaign — not applicable, skip rc 0" 0 \
  bash -c "cd '$repo_e' && bash '$audit' '$baseline_e' master"

# ---------------------------------------------------------------------------
# Results
# ---------------------------------------------------------------------------
if [[ "$fails" -ne 0 ]]; then
  echo "FAIL: $fails adherence case(s) mismatched"
  exit 1
fi
echo "PASS: all adherence cases matched their expected exit codes"
exit 0
