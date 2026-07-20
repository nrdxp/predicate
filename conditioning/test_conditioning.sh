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

# Producer sentinel: a verbatim phrase unique to modules/producer.ncl (drawn
# from its Trajectory-freeze bullet). Present in every code-writer render,
# absent from review-only renders — the per-role module-pull is what this pins.
readonly PRODUCER_SENTINEL="generating under unvalidated assumptions is forbidden"

# Reviewer sentinel: a verbatim phrase unique to modules/reviewer.ncl (the
# read-only adversarial-reviewer spine). Present in every reviewer render, absent
# from core/producer/workers — the reviewer module-pull is what this pins.
readonly REVIEWER_SENTINEL="You are a read-only adversarial reviewer"

# Council sentinel: a verbatim phrase unique to modules/council.ncl (the shared
# seat station). Present in every council-seat render, absent from
# core/producer/reviewer renders — the council module-pull is what this pins.
readonly COUNCIL_SENTINEL="You hold a SEAT on a bound council"

# Composer sentinel: a verbatim phrase unique to personas/composer.ncl. The single
# output style renders the COMPOSER after the swap — this pins that the output-style
# slot carries the conductor/moderator, not the old architect orchestrator.
readonly COMPOSER_SENTINEL="You are the COMPOSER — the live conductor"

# Constitution-render sentinels: the single-sourced conditioning constitution
# (conditioning/constitution.ncl) is RENDERED into the composer's prompt by compose.ncl.
# CONSTITUTION_SENTINEL pins the render block; DELEGATION_ROW_SENTINEL is one
# data-derived row (decision_type → owner → required_assent) generated FROM the value —
# proving the table is rendered, not hand-copied. Both present only in the composer slot.
readonly CONSTITUTION_SENTINEL="the council delegation table"
readonly DELEGATION_ROW_SENTINEL="merge → maintainer → single"

# Architect-orchestrator sentinel: the verbatim opening of the DELETED architect
# persona. After the swap it must appear in NO render — the output-style slot is
# the composer, and the architect role is now the architect-SEAT.
readonly ARCHITECT_ORCH_SENTINEL="You are the default interactive walker AND the campaign orchestrator"

# Reclassified-to-core sentinel: a verbatim phrase from the One-shot-skepticism
# principle, moved producer→core (with Root-cause folded into Action-caution) so
# it now binds EVERY walker, not just code-writers. Distinct from PRODUCER_SENTINEL
# precisely because it must appear in the review-only renders too — this pins the
# reclassification against a future re-slice that scopes a general principle to
# producer. HACORE_SNIPPET guards only core's opening line, not this bullet.
readonly CORE_GENERAL_SENTINEL="A first-pass success triggers an adversarial self-audit"

# Producer partition: the four code-writer workers pull it; doc/boundary omit it,
# and the composer output style omits it too (a moderator, not a code-writer — 3a).
readonly PRODUCER_PULL_WORKERS=(core-worker refine-worker form-worker spec-worker)
readonly PRODUCER_OMIT_WORKERS=(doc-worker boundary-worker survey-worker)

# Managed-block sentinels — must mirror install.sh exactly.
readonly BEGIN_MARK='# >>> predicate conditioning block >>>'
readonly END_MARK='# <<< predicate conditioning block <<<'

# Worker roles: exactly the six persisted agents.
readonly WORKER_ROLES=(core-worker refine-worker doc-worker form-worker spec-worker boundary-worker survey-worker test-worker)
# Reviewer roles — read-only adversarial lenses. Kept byte-identical to the
# declaration in install.sh (F6 lockstep): the two arrays MUST match exactly.
readonly REVIEWER_ROLES=(refuter-reviewer hickey-reviewer lowy-reviewer api-reviewer security-reviewer git-review-reviewer ai-slop-reviewer prior-art-reviewer vestigial-reviewer test-reviewer)
# Council roles — architect-tier SEATS. A third class: each composes the council
# module (NOT producer), so they form a sibling list like the reviewers. Kept
# byte-identical to the declaration in install.sh (F6 lockstep).
readonly COUNCIL_ROLES=(architect-seat lead-maintainer-seat process-auditor-seat hacker-seat)

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
file_contains_once() { [ "$(grep -cF "$1" "$2")" -eq 1 ]; }
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
  file_exists "$CLAUDE_DIR/output-styles/predicate-composer.md"

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

OS_FILE="$CLAUDE_DIR/output-styles/predicate-composer.md"

# 3a. Output style — the single slot renders the COMPOSER (the conductor/moderator).
# The architect orchestrator was demoted to the architect-SEAT, so the slot pulls
# NO producer (a moderator is not a code-writer) and the deleted architect sentinel
# appears nowhere.
echo ""
echo "── 3a. Output style ─────────────────────────────────────────────────────"
assert_pass "output style file exists" \
  file_exists "$OS_FILE"
assert_pass "frontmatter: keep-coding-instructions: false present (REPLACES default block)" \
  file_contains "keep-coding-instructions: false" "$OS_FILE"
assert_pass "frontmatter: name is 'Predicate Composer'" \
  file_contains "name: Predicate Composer" "$OS_FILE"
assert_pass "body: HasCore present (verbatim core law)" \
  file_contains "$HACORE_SNIPPET" "$OS_FILE"
assert_pass "body: composer sentinel present (slot renders the composer)" \
  file_contains "$COMPOSER_SENTINEL" "$OS_FILE"
assert_pass "body: constitution render present (composer conditioned with its own council law)" \
  file_contains "$CONSTITUTION_SENTINEL" "$OS_FILE"
assert_pass "body: a data-derived delegation row present (decision_type → owner → required_assent)" \
  file_contains "$DELEGATION_ROW_SENTINEL" "$OS_FILE"
assert_pass "body: producer absent (composer is a moderator, not a code-writer)" \
  file_not_contains "$PRODUCER_SENTINEL" "$OS_FILE"
assert_pass "body: deleted architect-orchestrator sentinel absent (demoted to seat)" \
  file_not_contains "$ARCHITECT_ORCH_SENTINEL" "$OS_FILE"

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

# 3e. Per-role producer presence/absence — the N2 module-pull partition
echo ""
echo "── 3e. Producer module pull (5 code-writers present, 2 review-only absent) ─"
for role in "${PRODUCER_PULL_WORKERS[@]}"; do
  assert_pass "$role: producer present (code-writer pulls producer)" \
    file_contains "$PRODUCER_SENTINEL" "$CLAUDE_DIR/agents/predicate-$role.md"
done
for role in "${PRODUCER_OMIT_WORKERS[@]}"; do
  assert_pass "$role: producer absent (review-only role omits producer)" \
    file_not_contains "$PRODUCER_SENTINEL" "$CLAUDE_DIR/agents/predicate-$role.md"
done
# core-worker carries the procedure exactly once (no self-restatement double-incl).
assert_pass "core-worker: producer procedure present exactly once (no double-inclusion)" \
  file_contains_once "$PRODUCER_SENTINEL" "$CLAUDE_DIR/agents/predicate-core-worker.md"

# 3f. Reviewer agents — 9 read-only lenses (refuter + 8). Each is materialized,
# carries HasCore + the reviewer-spine sentinel, and MUST NOT carry the producer
# sentinel — directly pinning "reviewers pull the reviewer module, not producer."
echo ""
echo "── 3f. Reviewer agents (9 read-only lenses) ─────────────────────────────"
for role in "${REVIEWER_ROLES[@]}"; do
  agent_file="$CLAUDE_DIR/agents/predicate-$role.md"
  assert_pass "$role: file exists at agents/predicate-$role.md" \
    file_exists "$agent_file"
  assert_pass "$role: frontmatter name: predicate-$role" \
    file_contains "name: predicate-$role" "$agent_file"
  assert_pass "$role: HasCore present in body" \
    file_contains "$HACORE_SNIPPET" "$agent_file"
  assert_pass "$role: reviewer-spine sentinel present (pulls reviewer module)" \
    file_contains "$REVIEWER_SENTINEL" "$agent_file"
  assert_pass "$role: producer sentinel absent (read-only; omits producer)" \
    file_not_contains "$PRODUCER_SENTINEL" "$agent_file"
done

# 3h. Council seat agents — 3 architect-tier seats. Each is materialized, carries
# HasCore + the council-station sentinel, and MUST NOT carry the producer sentinel
# — directly pinning "seats pull the council module, not producer."
echo ""
echo "── 3h. Council seat agents (3 architect-tier seats) ─────────────────────"
for role in "${COUNCIL_ROLES[@]}"; do
  agent_file="$CLAUDE_DIR/agents/predicate-$role.md"
  assert_pass "$role: file exists at agents/predicate-$role.md" \
    file_exists "$agent_file"
  assert_pass "$role: frontmatter name: predicate-$role" \
    file_contains "name: predicate-$role" "$agent_file"
  assert_pass "$role: HasCore present in body" \
    file_contains "$HACORE_SNIPPET" "$agent_file"
  assert_pass "$role: council-station sentinel present (pulls council module)" \
    file_contains "$COUNCIL_SENTINEL" "$agent_file"
  assert_pass "$role: producer sentinel absent (seat is not a code-writer)" \
    file_not_contains "$PRODUCER_SENTINEL" "$agent_file"
done

# 3g. Reclassified-to-core principle reaches review-only roles. One-shot
# skepticism moved producer→core, so unlike PRODUCER_SENTINEL it MUST render in
# the roles that pull no producer — doc/boundary and the 9 reviewers. This is the
# positive dual of the 3e/3f producer-absence checks and the regression lock for
# the reclassification itself.
echo ""
echo "── 3g. Reclassified-to-core principle in review-only renders ────────────"
for role in "${PRODUCER_OMIT_WORKERS[@]}" "${REVIEWER_ROLES[@]}"; do
  assert_pass "$role: One-shot-skepticism present (now core/general, not producer)" \
    file_contains "$CORE_GENERAL_SENTINEL" "$CLAUDE_DIR/agents/predicate-$role.md"
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
