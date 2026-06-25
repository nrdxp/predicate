#!/usr/bin/env bash
# Test harness for the project-local gate mechanism.
#
# Coverage (two levels):
#
#   1. RUNNER (project-gates.sh) — direct invocation, no git state required:
#      (a) No .ledger/gates/ directory → rc 0 (no-op).
#      (b) .ledger/gates/ is empty (no executables) → rc 0 (no-op).
#      (c) .ledger/gates/ with one passing gate → rc 0.
#      (d) .ledger/gates/ with one failing gate → rc 1.
#      (e) .ledger/gates/ with a passing gate AND a failing gate → rc 1.
#      (f) Non-executable files in .ledger/gates/ are silently skipped.
#      (g) Gates run in sorted order (numeric prefix respected).
#
#   2. HOOK INTEGRATION (hooks/pre-commit tier 6) — full commit-hook path,
#      using a standalone throwaway git repo as the "consuming project":
#      (A) No .ledger/gates/ → hook passes (rc 0).
#      (B) .ledger/gates/ with a passing gate → hook passes (rc 0).
#      (C) .ledger/gates/ with a failing gate → hook blocked (rc 1).
#
# All scratch state is torn down via EXIT trap. The throwaway project repo is
# entirely isolated from the predicate repo — no worktree, no pointer leak.
#
# Usage: test_project_gates.sh
# Exit:  0 = all cases matched, 1 = a case mismatched, 2 = environment error.
set -u

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
runner="$here/project-gates.sh"
# The hook under test is the WORKTREE hook (which carries tier 6).  When this
# script runs from the worktree itself, $root == the worktree root and
# hooks/pre-commit is the version with the project-local tier implemented.
wt_hook="$root/hooks/pre-commit"

fails=0
expect() { # description expected-rc -- command...
  local desc="$1" exp="$2"; shift 2
  "$@" >/dev/null 2>&1; local rc=$?
  if [ "$rc" -eq "$exp" ]; then
    echo "PASS  ($rc) $desc"
  else
    echo "FAIL  (got $rc, want $exp) $desc"; fails=$((fails + 1))
  fi
}

# Scratch state: temp dir that holds all fixture repos.
scratch="$(mktemp -d)"
proj_dir="$scratch/consuming_project"
git_id=(-c user.name=test-project-gates -c user.email=test@project-gates -c commit.gpgsign=false)

cleanup() {
  rm -rf "$scratch"
}
trap cleanup EXIT

# ─── LEVEL 1: RUNNER (project-gates.sh) ─────────────────────────────────────

echo "== project-gates.sh: no-op cases =="

# (a) No .ledger/gates/ directory at all → rc 0.
no_gates_dir="$scratch/no_gates"
mkdir -p "$no_gates_dir"
expect "no .ledger/gates/ dir → rc 0 (no-op)" 0 \
  bash "$runner" "$no_gates_dir"

# (b) .ledger/gates/ exists but is empty → rc 0.
empty_gates_dir="$scratch/empty_gates"
mkdir -p "$empty_gates_dir/.ledger/gates"
expect ".ledger/gates/ empty → rc 0 (no-op)" 0 \
  bash "$runner" "$empty_gates_dir"

echo "== project-gates.sh: pass/fail execution =="

# (c) .ledger/gates/ with one passing gate → rc 0.
pass_dir="$scratch/pass_dir"
mkdir -p "$pass_dir/.ledger/gates"
cat > "$pass_dir/.ledger/gates/01-pass.sh" <<'SH'
#!/usr/bin/env bash
exit 0
SH
chmod +x "$pass_dir/.ledger/gates/01-pass.sh"
expect "one passing gate → rc 0" 0 \
  bash "$runner" "$pass_dir"

# (d) .ledger/gates/ with one failing gate → rc 1.
fail_dir="$scratch/fail_dir"
mkdir -p "$fail_dir/.ledger/gates"
cat > "$fail_dir/.ledger/gates/01-fail.sh" <<'SH'
#!/usr/bin/env bash
echo "intentional failure" >&2
exit 1
SH
chmod +x "$fail_dir/.ledger/gates/01-fail.sh"
expect "one failing gate → rc 1" 1 \
  bash "$runner" "$fail_dir"

# (e) Passing gate AND failing gate → rc 1 (runner fails on any failure).
mixed_dir="$scratch/mixed_dir"
mkdir -p "$mixed_dir/.ledger/gates"
cat > "$mixed_dir/.ledger/gates/01-pass.sh" <<'SH'
#!/usr/bin/env bash
exit 0
SH
chmod +x "$mixed_dir/.ledger/gates/01-pass.sh"
cat > "$mixed_dir/.ledger/gates/02-fail.sh" <<'SH'
#!/usr/bin/env bash
echo "intentional failure" >&2
exit 1
SH
chmod +x "$mixed_dir/.ledger/gates/02-fail.sh"
expect "passing + failing gate → rc 1" 1 \
  bash "$runner" "$mixed_dir"

echo "== project-gates.sh: non-executable files skipped =="

# (f) Non-executable file in .ledger/gates/ is silently skipped.
skip_dir="$scratch/skip_dir"
mkdir -p "$skip_dir/.ledger/gates"
# A script that would fail if executed — but it is NOT marked executable.
cat > "$skip_dir/.ledger/gates/not-a-gate.sh" <<'SH'
#!/usr/bin/env bash
echo "I must not be executed" >&2
exit 1
SH
# Deliberately no chmod +x.
expect "non-executable file skipped → rc 0" 0 \
  bash "$runner" "$skip_dir"

echo "== project-gates.sh: sorted execution order =="

# (g) Gates run in sorted name order.  We use an order-file to verify:
#     01-first records "A", 02-second records "B"; the file must end up as "AB".
order_dir="$scratch/order_dir"
order_file="$scratch/order.txt"
mkdir -p "$order_dir/.ledger/gates"
cat > "$order_dir/.ledger/gates/01-first.sh" <<SH
#!/usr/bin/env bash
printf 'A' >> "$order_file"
exit 0
SH
chmod +x "$order_dir/.ledger/gates/01-first.sh"
cat > "$order_dir/.ledger/gates/02-second.sh" <<SH
#!/usr/bin/env bash
printf 'B' >> "$order_file"
exit 0
SH
chmod +x "$order_dir/.ledger/gates/02-second.sh"
: > "$order_file"
bash "$runner" "$order_dir" >/dev/null 2>&1
order_result="$(cat "$order_file")"
if [[ "$order_result" == "AB" ]]; then
  echo "PASS  (order) gates ran in sorted order (A then B)"
else
  echo "FAIL  (order) expected 'AB', got '$order_result'"; fails=$((fails + 1))
fi

# ─── LEVEL 2: HOOK INTEGRATION ───────────────────────────────────────────────

echo "== hook integration: project-local tier (tier 6) =="

# Set up a standalone throwaway "consuming project" git repo.
# It must be a real git repo so that hooks/pre-commit can run
# `git rev-parse --show-toplevel` and `git diff --cached --name-only`.
mkdir -p "$proj_dir"
git "${git_id[@]}" -C "$proj_dir" init -q -b main
# Stage a neutral file (not .ncl, not .md, no orphan references, no .yaml
# deposit) so that tiers 1-5 pass cleanly, leaving tier 6 as the only
# variable across the three integration cases below.
printf 'neutral content\n' > "$proj_dir/probe.txt"
git -C "$proj_dir" add probe.txt
# Install the hook: a direct invocation of the worktree hook.  In real
# installations this would be a symlink via install-hooks.sh; for the test
# we invoke the hook directly with `bash "$wt_hook"` from inside $proj_dir,
# which exercises the same realpath-based $plugin resolution (the hook's
# BASH_SOURCE[0] is $wt_hook, so $plugin resolves to $root — the worktree).

# (A) No .ledger/gates/ directory → tier 6 is a no-op → hook passes (rc 0).
expect "hook: no .ledger/gates/ → no-op (rc 0)" 0 \
  bash -c 'cd "$1" && bash "$2"' _ "$proj_dir" "$wt_hook"

# (B) .ledger/gates/ with an always-pass gate → hook passes (rc 0).
mkdir -p "$proj_dir/.ledger/gates"
cat > "$proj_dir/.ledger/gates/01-pass.sh" <<'SH'
#!/usr/bin/env bash
# Trivial passing project-local gate.
exit 0
SH
chmod +x "$proj_dir/.ledger/gates/01-pass.sh"
expect "hook: passing project-local gate → rc 0" 0 \
  bash -c 'cd "$1" && bash "$2"' _ "$proj_dir" "$wt_hook"

# (C) Add an always-fail gate → commit blocked (rc 1).
cat > "$proj_dir/.ledger/gates/02-fail.sh" <<'SH'
#!/usr/bin/env bash
# Trivial failing project-local gate — simulates a failing project check.
echo "local-gate: intentional failure" >&2
exit 1
SH
chmod +x "$proj_dir/.ledger/gates/02-fail.sh"
expect "hook: failing project-local gate → commit blocked (rc 1)" 1 \
  bash -c 'cd "$1" && bash "$2"' _ "$proj_dir" "$wt_hook"

# ─── Results ─────────────────────────────────────────────────────────────────
if [ "$fails" -ne 0 ]; then
  echo "FAIL: $fails project-gate case(s) mismatched"
  exit 1
fi
echo "PASS: all project-gate cases matched their expected exit codes"
exit 0
