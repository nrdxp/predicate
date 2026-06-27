#!/usr/bin/env bash
# conditioning/test_conditioning.sh
#
# Hermetic e2e test for the conditioning harness re-architecture.
#
# Invariants under test:
#   1. A temp-HOME install produces a Claude output style whose frontmatter
#      contains `keep-coding-instructions: false` and whose body contains
#      HasCore (verbatim core law) — REPLACES the default behavioral block.
#   2. All 6 worker permutations are materialized in <claude-dir>/agents/;
#      each carries name + description frontmatter and HasCore in its body.
#   3. The agy path: GEMINI.md is written with HasCore inside a managed block.
#   4. No @import managed block is written to any Claude surface (CLAUDE.md
#      is not created; the always-on surface is the output style alone).
#   5. Real ~/.claude and the worktree AGENTS.md are untouched.
#
# Every assertion fails loudly on a broken or empty install (ΔE₀ ≠ 0).
# Section 1 proves baseline failure before the install runs.
#
# Usage: bash conditioning/test_conditioning.sh
# Exit:  0 = all assertions green; non-zero = at least one failure.

set -uo pipefail

# ── locate artifacts ──────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_SH="$SCRIPT_DIR/install.sh"
PROBE_NO_CORE="$SCRIPT_DIR/probe_no_core.ncl"
PROBE_NO_MODULE="$SCRIPT_DIR/probe_no_module.ncl"
WORKTREE_ROOT="$(dirname "$SCRIPT_DIR")"

# HasCore: a stable, distinctive substring present in every generated prompt.
# Chosen from the opening sentence of core.ncl — unique within the project.
readonly HACORE_SNIPPET="Autoregressive Stochastic Walk"

# Module sentinel: the verbatim text the HasModule sibling contract guards.
# Inert N1 placeholder — the real producer module is N2's deliverable. Must
# match probe_no_module.ncl exactly so both controls exercise one marker.
readonly MODULE_SENTINEL="Predicate module segment: N1 inert example"

# Managed-block sentinels — must mirror install.sh exactly.
readonly BEGIN_MARK='# >>> predicate conditioning block >>>'
readonly END_MARK='# <<< predicate conditioning block <<<'

# Worker roles: exactly the six persisted agents.
readonly WORKER_ROLES=(core-worker refine-worker doc-worker form-worker spec-worker boundary-worker)

# ── hermetic temp environment ─────────────────────────────────────────────────
REAL_HOME="$HOME"
TEMP_HOME="$(mktemp -d)"
CLAUDE_DIR="$TEMP_HOME/.claude"
GEMINI_DIR="$TEMP_HOME/.gemini"

cleanup() { rm -rf "$TEMP_HOME"; }
trap cleanup EXIT

# ── assertion helpers ─────────────────────────────────────────────────────────
PASS_COUNT=0
FAIL_COUNT=0
FAIL_MSGS=()

# assert DESC expected_outcome CMD [ARGS...]
# expected_outcome: "pass" (cmd must exit 0) or "fail" (cmd must exit non-zero)
assert() {
  local desc="$1" expected="$2"
  shift 2
  local rc=0
  "$@" >/dev/null 2>&1 || rc=$?

  local passed=false
  case "$expected" in
    pass) [ "$rc" -eq  0 ] && passed=true ;;
    fail) [ "$rc" -ne  0 ] && passed=true ;;
  esac

  if $passed; then
    echo "  PASS: $desc"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    if [ "$expected" = "fail" ]; then
      echo "  FAIL (expected cmd to fail, but it succeeded): $desc"
    else
      echo "  FAIL: $desc"
    fi
    FAIL_COUNT=$((FAIL_COUNT + 1))
    FAIL_MSGS+=("$desc")
  fi
}

assert_pass() { assert "$1" "pass" "${@:2}"; }
assert_fail() { assert "$1" "fail" "${@:2}"; }

file_exists()       { [ -f "$1" ]; }
dir_exists()        { [ -d "$1" ]; }
file_contains()     { grep -qF "$1" "$2"; }
file_not_contains() { ! grep -qF "$1" "$2"; }
no_file()           { [ ! -f "$1" ]; }

# ── PRE-TEST: snapshot real-home predicate surfaces ───────────────────────────
# Captures what (if anything) predicate has already put in the real ~/.claude
# before this test runs, so we can prove the test does not add to it.
REAL_PREDICATE_BEFORE=$(
  find "$REAL_HOME/.claude" -name "predicate-*.md" 2>/dev/null | sort
)

# ── SECTION 1: ΔE₀ — baseline failure before install ─────────────────────────
echo ""
echo "════════════════════════════════════════════════════════════════════════"
echo "SECTION 1 — ΔE₀ baseline: assertions MUST FAIL before install"
echo "════════════════════════════════════════════════════════════════════════"

assert_fail "output style absent before install" \
  file_exists "$CLAUDE_DIR/output-styles/predicate-architect.md"

assert_fail "agents dir absent before install" \
  dir_exists "$CLAUDE_DIR/agents"

assert_fail "GEMINI.md absent before install" \
  file_exists "$GEMINI_DIR/GEMINI.md"

# ── SECTION 2: install --harness all ─────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════════════════════════════"
echo "SECTION 2 — Running: install.sh --harness all (temp HOME)"
echo "════════════════════════════════════════════════════════════════════════"

HOME="$TEMP_HOME" \
PREDICATE_CLAUDE_DIR="$CLAUDE_DIR" \
PREDICATE_GEMINI_DIR="$GEMINI_DIR" \
  bash "$INSTALL_SH" --harness all

echo ""
echo "install.sh exited $?"

# ── SECTION 3: post-install assertions ───────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════════════════════════════"
echo "SECTION 3 — Post-install assertions"
echo "════════════════════════════════════════════════════════════════════════"

OS_FILE="$CLAUDE_DIR/output-styles/predicate-architect.md"

# 3a. Output style
echo ""
echo "── 3a. Output style ─────────────────────────────────────────────────────"
assert_pass "output style file exists" \
  file_exists "$OS_FILE"
assert_pass "frontmatter: keep-coding-instructions: false present (REPLACES default block)" \
  file_contains "keep-coding-instructions: false" "$OS_FILE"
assert_pass "frontmatter: name is 'Predicate Architect'" \
  file_contains "name: Predicate Architect" "$OS_FILE"
assert_pass "body: HasCore present (verbatim core law)" \
  file_contains "$HACORE_SNIPPET" "$OS_FILE"

# 3b. Worker agents — 6 permutations
echo ""
echo "── 3b. Worker agents (6 roles) ──────────────────────────────────────────"
for role in "${WORKER_ROLES[@]}"; do
  agent_file="$CLAUDE_DIR/agents/predicate-$role.md"
  assert_pass "$role: file exists at agents/predicate-$role.md" \
    file_exists "$agent_file"
  assert_pass "$role: frontmatter name: predicate-$role" \
    file_contains "name: predicate-$role" "$agent_file"
  assert_pass "$role: frontmatter description: present" \
    file_contains "description:" "$agent_file"
  assert_pass "$role: HasCore present in body" \
    file_contains "$HACORE_SNIPPET" "$agent_file"
done

# 3c. agy / GEMINI.md
echo ""
echo "── 3c. agy / GEMINI.md ──────────────────────────────────────────────────"
GEMINI_FILE="$GEMINI_DIR/GEMINI.md"
assert_pass "GEMINI.md exists" \
  file_exists "$GEMINI_FILE"
assert_pass "GEMINI.md: managed block begin marker present" \
  file_contains "$BEGIN_MARK" "$GEMINI_FILE"
assert_pass "GEMINI.md: managed block end marker present" \
  file_contains "$END_MARK" "$GEMINI_FILE"
assert_pass "GEMINI.md: HasCore present" \
  file_contains "$HACORE_SNIPPET" "$GEMINI_FILE"

# 3d. No @import managed block — CLAUDE.md must NOT be created
echo ""
echo "── 3d. No @import block — always-on surface is output style alone ────────"
assert_pass "CLAUDE.md not created by install (no @import surface)" \
  no_file "$CLAUDE_DIR/CLAUDE.md"

# Confirm by checking no predicate conditioning block appears under claude dir.
# (Output-styles and agents are whole-file owned; they have no managed block.)
assert_pass "no predicate conditioning managed-block under claude dir" \
  bash -c "! grep -rqF '$BEGIN_MARK' '$CLAUDE_DIR/' 2>/dev/null"

# ── SECTION 4: negative control — HasCore contract fires on absent core ────────
echo ""
echo "════════════════════════════════════════════════════════════════════════"
echo "SECTION 4 — Negative control: HasCore contract rejects a core-absent prompt"
echo "════════════════════════════════════════════════════════════════════════"

assert_fail "nickel export of probe_no_core.ncl fails with contract violation" \
  nickel export --format text "$PROBE_NO_CORE"

# ── SECTION 4b: module contract — HasModule accepts present, rejects absent ────
echo ""
echo "════════════════════════════════════════════════════════════════════════"
echo "SECTION 4b — Module contract: HasModule sibling of HasCore"
echo "════════════════════════════════════════════════════════════════════════"

# The new artifact must exist (ΔE₀ baseline: red until N1 lands it).
assert_pass "probe_no_module.ncl exists" \
  file_exists "$PROBE_NO_MODULE"

# Positive: HasModule admits a prompt that carries the module verbatim.
module_present_passes() {
  nickel export --format text <<NICKEL
let HasModule = fun expected =>
  std.contract.from_predicate (fun s => std.string.contains expected (s | String))
in
({ ok | HasModule "$MODULE_SENTINEL" = "head\n\n$MODULE_SENTINEL\n\ntail" }).ok
NICKEL
}
assert_pass "HasModule admits a module-present prompt" \
  module_present_passes

# Negative control: a prompt that drops the module fails export (rule bites).
assert_fail "nickel export of probe_no_module.ncl fails with contract violation" \
  nickel export --format text "$PROBE_NO_MODULE"

# ── SECTION 5: real-tree cleanliness ─────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════════════════════════════"
echo "SECTION 5 — Real-tree cleanliness"
echo "════════════════════════════════════════════════════════════════════════"

# 5a. Real ~/.claude: no new predicate surfaces added by this test run.
echo ""
echo "── 5a. Real ~/.claude ───────────────────────────────────────────────────"
REAL_PREDICATE_AFTER=$(
  find "$REAL_HOME/.claude" -name "predicate-*.md" 2>/dev/null | sort
)
assert_pass "real ~/.claude: no new predicate-*.md files introduced by test" \
  test "$REAL_PREDICATE_BEFORE" = "$REAL_PREDICATE_AFTER"

echo "  INFO: real ~/.claude predicate files before: $(printf '%s\n' "$REAL_PREDICATE_BEFORE" | wc -l | tr -d ' ') found"
echo "  INFO: real ~/.claude predicate files after:  $(printf '%s\n' "$REAL_PREDICATE_AFTER"  | wc -l | tr -d ' ') found"
echo "  INFO: real ~/.claude install files written at: $CLAUDE_DIR (under TEMP_HOME)"

if [ -d "$REAL_HOME/.claude" ]; then
  echo "  real ~/.claude listing:"
  ls "$REAL_HOME/.claude" 2>/dev/null | sed 's/^/    /'
else
  echo "  INFO: $REAL_HOME/.claude does not exist — trivially untouched."
fi

# 5b. Worktree AGENTS.md: install.sh must not touch it.
echo ""
echo "── 5b. Worktree AGENTS.md ───────────────────────────────────────────────"
WORKTREE_AGENTS="$WORKTREE_ROOT/AGENTS.md"
if [ -f "$WORKTREE_AGENTS" ]; then
  assert_pass "worktree AGENTS.md: no predicate conditioning managed-block" \
    file_not_contains "$BEGIN_MARK" "$WORKTREE_AGENTS"
  echo "  INFO: AGENTS.md exists — no conditioning block found (correct)"
else
  echo "  INFO: AGENTS.md does not exist in worktree — not created by install (correct)"
  PASS_COUNT=$((PASS_COUNT + 1))
fi

# git status — show the worktree is clean w.r.t. test artifacts.
echo ""
echo "── 5c. Worktree git status (conditioning/ only) ─────────────────────────"
git -C "$WORKTREE_ROOT" status --short -- conditioning/ 2>/dev/null || true

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════════════════════════════"
echo "SUMMARY"
echo "════════════════════════════════════════════════════════════════════════"
echo "  PASS: $PASS_COUNT"
echo "  FAIL: $FAIL_COUNT"

if [ "${#FAIL_MSGS[@]}" -gt 0 ]; then
  echo ""
  echo "  Failed assertions:"
  for msg in "${FAIL_MSGS[@]}"; do
    echo "    ✗ $msg"
  done
fi

echo ""
if [ "$FAIL_COUNT" -gt 0 ]; then
  echo "RESULT: FAIL — $FAIL_COUNT assertion(s) failed."
  exit 1
else
  echo "RESULT: ALL PASS"
  exit 0
fi
