#!/usr/bin/env bash
# Gate-test harness with a CONTEXT axis. The gates enforce everything but were
# only ever exercised from the main tree; five real bugs hid in ONE blind spot —
# a gate that works from the main tree breaks when invoked from a linked git
# worktree, where the hook's $plugin resolves to the main repo but the artifact
# and $root are the worktree. This harness makes that blind spot a standing
# guard: every relevant gate is exercised from BOTH (a) the main tree and (b) a
# linked worktree, and each case asserts an exit code (the baseline-failure
# discipline — a wrong verdict changes the code).
#
# Coverage:
#   ledger-validate.sh structure  positive (contract typecheck, instance export),
#                                  negative (malformed contract, unmarked cycle),
#                                  polarity (# EXPECT: fail cycle), and the
#                                  CROSS-ROOT regression (validate an artifact in
#                                  a DIFFERENT worktree).
#   AUTHORITY overlay from a worktree  the #1 regression: with an active-dag
#                                  pointer in the MAIN tree, the pre-commit hook
#                                  run from a linked worktree blocks an
#                                  unauthorized staged path and passes an
#                                  authorized one.
#
#   check_docs.py anchor validation  a link file.md#fragment whose fragment names
#                                  no heading is broken; a good fragment is valid.
#
# All scratch state (temp worktrees, the active-dag pointer, temp fixtures) is
# set up AND torn down by this script — including on failure, via traps — so the
# tree is clean afterward. CRITICAL: the active-dag pointer lives in the MAIN
# tree; a leaked pointer gates every later commit, so its teardown is
# unconditional.
#
# Usage: test_gates.sh
# Exit:  0 = every case matched, 1 = a case mismatched, 2 = environment error.
set -u

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
validate="$here/ledger-validate.sh"
process_gate="$here/process-gate.sh"
check_docs="$root/skills/doc-audit/scripts/check_docs.py"
recorder_close_check="$here/recorder_close_check.sh"
check_orphans="$root/gates/check_orphans.sh"
check_selfcontained="$root/gates/check_selfcontained.sh"
sync_sketch="$root/skills/refine/scripts/sync_sketch.py"
check_commit_msg="$root/skills/commit-hygiene/scripts/check_commit_msg.py"

# The MAIN tree: where the hook machinery and the active-dag pointer live. When
# this harness runs from a linked worktree, the main tree is the parent of the
# common git dir; in the self-host case it is $root itself.
main="$(cd "$(dirname "$(git -C "$root" rev-parse --git-common-dir)")" 2>/dev/null && pwd || echo "$root")"
hook="$main/hooks/pre-commit"

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

# expect_structure runs the harness-repo validate against an artifact and asserts
# the exit code. The artifact path is passed straight through so the CROSS-ROOT
# case (artifact in a different worktree) shares one code path with the local one.
expect_structure() { # description expected-rc artifact
  expect "$1" "$2" bash "$validate" structure "$3"
}

# ---------------------------------------------------------------------------
# Scratch-fixture construction. The classifier in ledger-validate.sh keys on the
# ARTIFACT path: */ledger/contracts/*.ncl -> typecheck, else export. So temp
# fixtures must sit under a ledger/contracts/ or ledger/fixtures/ subtree, and an
# instance must be able to `import "../contracts/dag.ncl"`. We mirror that layout
# in a temp dir and copy the real contract in so the relative import resolves.
# ---------------------------------------------------------------------------
fixdir="$(mktemp -d)"
mkdir -p "$fixdir/ledger/contracts" "$fixdir/ledger/fixtures"
cp "$root/ledger/contracts/dag.ncl" "$fixdir/ledger/contracts/dag.ncl"

# Negative control 1: a malformed contract def (syntax error). Classified as a
# contract by its path, so it is typechecked; the typecheck MUST fail (non-0).
cat > "$fixdir/ledger/contracts/malformed.ncl" <<'NCL'
# Malformed contract def: an unterminated custom-contract lambda. Typecheck MUST
# fail (non-0) — a malformed contract cannot pass the structure gate.
{ Broken = std.contract.custom (fun _label value =>
NCL

# Negative control 2: an UNMARKED cyclic instance (no `# EXPECT: fail` line). The
# raw cycle failure MUST surface as non-0 — polarity does not absorb it, because
# the fixture does not declare itself a negative control.
cat > "$fixdir/ledger/fixtures/dag_cycle_unmarked.ncl" <<'NCL'
# Unmarked cyclic instance: A<->B with NO polarity marker, so the gate surfaces
# the raw export failure (non-0) rather than absorbing it.
let c = import "../contracts/dag.ncl" in
{
  nodes = [
    { id = "A", depends_on = ["B"], file_surface = ["a/"], discipline = 'core, mitigates = [] },
    { id = "B", depends_on = ["A"], file_surface = ["b/"], discipline = 'core, mitigates = [] },
  ]
} | c.Dag
NCL

# Markdown fixtures for the anchor-validation case (Deliverable B). A target file
# with known headings, plus a referrer linking to a good and a bad anchor.
cat > "$fixdir/target.md" <<'MD'
# Title One

## A Second Heading

Body text.
MD
cat > "$fixdir/good_anchor.md" <<'MD'
# Referrer

See [section](target.md#a-second-heading) for details.
MD
cat > "$fixdir/bad_anchor.md" <<'MD'
# Referrer

See [section](target.md#no-such-anchor-zzz) for details.
MD

# Recorder fixtures for recorder_close_check.sh. Four THROWAWAY git repos, NEVER
# the real .ledger. They nest under $fixdir so the existing `rm -rf "$fixdir"` in
# cleanup() tears them down. git is run with an isolated identity so the harness
# needs no global git config to commit.
#
#   rec_with          PASS: close commit + non-empty Sufficiency Review section
#   rec_without       FAIL: no close commit at all (no `log: close …` subject)
#   rec_empty_section FAIL: close commit present but section heading has no content
#   rec_no_heading    FAIL: close commit present but no Sufficiency Review heading
#
# TDD polarity (recorder_close_check.sh Check 2 — structural floor):
#   empty heading → FAIL (rc 1)   heading + content → PASS (rc 0)   no heading → FAIL (rc 1)
rec_with="$fixdir/recorder_with"
rec_without="$fixdir/recorder_without"
rec_empty_section="$fixdir/recorder_empty_section"
rec_no_heading="$fixdir/recorder_no_heading"
git_id=(-c user.name=test-gates -c user.email=test@gates -c commit.gpgsign=false)
mkdir -p "$rec_with" "$rec_without" "$rec_empty_section" "$rec_no_heading"

# PASS fixture: heading present and non-empty content beneath it.
git "${git_id[@]}" -C "$rec_with" init -q
printf '## Sufficiency Review\n\nDecorrelated reviewers converged; machinery sufficient.\n' > "$rec_with/log.md"
git "${git_id[@]}" -C "$rec_with" add log.md
git "${git_id[@]}" -C "$rec_with" commit -q -m "log: close demo-topic retrospective"

# FAIL fixture: no close commit (subject is log: open, not log: close).
git "${git_id[@]}" -C "$rec_without" init -q
: > "$rec_without/log.md"
git "${git_id[@]}" -C "$rec_without" add log.md
git "${git_id[@]}" -C "$rec_without" commit -q -m "log: open demo-topic"

# FAIL fixture: close commit present but Sufficiency Review section is EMPTY
# (heading line present, nothing substantive underneath — blank lines only).
# The structural floor must reject a hollow heading.
git "${git_id[@]}" -C "$rec_empty_section" init -q
printf '## Sufficiency Review\n\n' > "$rec_empty_section/log.md"
git "${git_id[@]}" -C "$rec_empty_section" add log.md
git "${git_id[@]}" -C "$rec_empty_section" commit -q -m "log: close demo-topic retrospective"

# FAIL fixture: close commit present but NO Sufficiency Review heading in the file.
git "${git_id[@]}" -C "$rec_no_heading" init -q
printf '## Outcomes\n\nAll nodes accepted; campaign complete.\n' > "$rec_no_heading/log.md"
git "${git_id[@]}" -C "$rec_no_heading" add log.md
git "${git_id[@]}" -C "$rec_no_heading" commit -q -m "log: close demo-topic retrospective"


# check_orphans.sh fixtures (Deliverable A2). A throwaway doc tree with a
# .ledger/config.sh that scopes ORPHAN_TARGETS to the single fixture doc, so the
# gate greps only our content (its default targets — skills/ ambient.md … — do not
# exist here). Three docs share one root, swapped per case by overwriting doc.md.
orph_root="$fixdir/orph"
mkdir -p "$orph_root/.ledger"
printf 'ORPHAN_TARGETS=(doc.md)\n' > "$orph_root/.ledger/config.sh"
# Live reference to a removed workflow (the "/plan " invocation form).
printf 'Run the /plan workflow to begin.\n' > "$orph_root/doc_orphan.md"
# Clean doc — no removed-workflow names at all.
printf 'Prose with no removed workflow names whatsoever.\n' > "$orph_root/doc_clean.md"
# P30 regression: predicate's OWN namespace, exercised in every reference form the
# gate matches (/predicate, `predicate`, "the predicate workflow"). With the CURRENT
# removed set (which no longer contains "predicate") it must NOT flag — the bug
# P30 fixed was flagging the project's own namespace. The fixture is load-bearing:
# the same content WOULD flag if "predicate" were wrongly in the removed set.
printf 'Invoke /predicate-core, see the `predicate` plugin; the predicate workflow lives in skills/predicate/.\n' \
  > "$orph_root/doc_p30.md"

# sync_sketch.py fixture (Deliverable B). The script resolves its repo root by
# walking UP from its OWN script path (not cwd) for .git/.ledger, then operates on
# <root>/.ledger/log. To sandbox it we mirror its install path inside a throwaway
# tree and copy the real script in, so repo_root resolves to the throwaway and the
# only side effect — a commit — lands in the throwaway .ledger/log sub-repo.
sync_box="$fixdir/sync_box"
mkdir -p "$sync_box/.ledger/log" "$sync_box/skills/refine/scripts"
git "${git_id[@]}" -C "$sync_box" init -q                 # outer root marker (.git)
cp "$sync_sketch" "$sync_box/skills/refine/scripts/sync_sketch.py"
git "${git_id[@]}" -C "$sync_box/.ledger/log" init -q     # the recorder sub-repo
# sync_sketch.py commits with a BARE `git` (no -c identity flags), so it relies on
# the recorder repo resolving an identity itself. A fresh CI runner has no global
# git identity -> the script's commit exits 128. Pin a local identity on the
# sandbox recorder so the script under test commits without ambient config.
git -C "$sync_box/.ledger/log" config user.name  test-gates
git -C "$sync_box/.ledger/log" config user.email test@gates
git -C "$sync_box/.ledger/log" config commit.gpgsign false
: > "$sync_box/.ledger/log/.gitkeep"
git "${git_id[@]}" -C "$sync_box/.ledger/log" add .gitkeep
git "${git_id[@]}" -C "$sync_box/.ledger/log" commit -q -m "init: recorder"
# An untracked sketch with the frontmatter the script parses (TOPIC/STATUS/LOOP).
cat > "$sync_box/.ledger/log/2026-06-22-demo-topic.md" <<'MD'
```yaml
TOPIC: demo-topic
STATUS: ACTIVE
CURRENT_LOOP: 3
```

# Demo sketch
body
MD

# ---------------------------------------------------------------------------
# Worktree scratch. We create throwaway DETACHED worktrees off HEAD under the
# main tree's .scratch/worktrees/, and an active-dag pointer in the main tree.
# Teardown is unconditional (trap) so a failing assertion never leaks a pointer
# (which would gate every later commit) or a worktree.
# ---------------------------------------------------------------------------
pointer="$main/.ledger/active-dag"
walk_pointer="$main/.ledger/active-walk"
xr_wt="$main/.scratch/worktrees/test-gates-xr-$$"   # cross-root artifact worktree
auth_wt="$main/.scratch/worktrees/test-gates-auth-$$" # authority-from-worktree
proc_wt="$main/.scratch/worktrees/test-gates-proc-$$" # process-gate walk-activation worktree
b1_wt="$main/.scratch/worktrees/test-gates-b1-$$"   # B1 .ncl path-scoping regression

# Was a pointer already present before we started? If so a real campaign may own
# it; we must NOT remove it on teardown. (Defensive: we also refuse to run.)
pointer_preexisting=0
[ -e "$pointer" ] && pointer_preexisting=1

# Same guard for the active-walk pointer: if a walk already owns it, refuse.
walk_pointer_preexisting=0
[ -e "$walk_pointer" ] && walk_pointer_preexisting=1

# The .ledger/ parent is gitignored (the flight-recorder subrepo is not in this
# repo's tree), so a fresh checkout has no .ledger/ dir and the pointer write
# below fails. Create it if absent; track that WE created it so teardown removes
# only what we made, never a real local .ledger/.
ledger_dir="$(dirname "$pointer")"
ledger_dir_created=0
[ -d "$ledger_dir" ] || { mkdir -p "$ledger_dir" && ledger_dir_created=1; }

cleanup() {
  # Pointer teardown FIRST and unconditional — the highest-risk leak. Only remove
  # what we created: leave a pre-existing pointer untouched.
  if [ "$pointer_preexisting" -eq 0 ]; then
    rm -f "$pointer"
  fi
  if [ "$walk_pointer_preexisting" -eq 0 ]; then
    rm -f "$walk_pointer"
  fi
  # Remove the .ledger/ dir only if WE created it and it is now empty (rmdir is a
  # no-op on a non-empty dir, so a real .ledger/ is never clobbered).
  if [ "$ledger_dir_created" -eq 1 ]; then
    rmdir "$ledger_dir" 2>/dev/null || true
  fi
  for w in "$xr_wt" "$auth_wt" "$proc_wt" "$b1_wt"; do
    [ -e "$w" ] && { git -C "$main" worktree remove --force "$w" 2>/dev/null || rm -rf "$w"; }
  done
  git -C "$main" worktree prune 2>/dev/null || true
  rm -rf "$fixdir"
}
trap cleanup EXIT

if [ "$pointer_preexisting" -eq 1 ]; then
  echo "SKIP: an active-dag pointer already exists at $pointer" >&2
  echo "  Authority overlay tests will be skipped (a real campaign may own it)." >&2
fi
if [ "$walk_pointer_preexisting" -eq 1 ]; then
  echo "SKIP: an active-walk pointer already exists at $walk_pointer" >&2
  echo "  Walk-activation overlay tests will be skipped (a live walk may own it)." >&2
fi

# The worktree hook: $root/hooks/pre-commit. Used by B1, walk-activation, and
# rename-hole tests (sections that invoke the hook directly). Defined here at
# script level so it is available to all sections, not just the walk section.
wt_hook="$root/hooks/pre-commit"

echo "== ledger-validate structure: positive, negative, polarity =="
expect_structure "contract def -> typecheck (rc 0)" 0 \
  "$root/ledger/contracts/dag.ncl"
expect_structure "valid instance -> export (rc 0)" 0 \
  "$root/ledger/fixtures/dag_valid.ncl"
expect_structure "malformed contract -> non-0" 1 \
  "$fixdir/ledger/contracts/malformed.ncl"
expect_structure "# EXPECT:fail cycle -> polarity (rc 0)" 0 \
  "$root/ledger/fixtures/dag_cycle.ncl"
expect_structure "UNMARKED cyclic instance -> non-0" 1 \
  "$fixdir/ledger/fixtures/dag_cycle_unmarked.ncl"

echo "== ledger-validate structure: CROSS-ROOT (N0a/N0b regression) =="
# Invoke the HARNESS-repo's ledger-validate.sh against a contract artifact that
# lives in a DIFFERENT git worktree. The machinery resolves $plugin from its own
# real path (the harness repo), while the artifact and its sibling contracts live
# in the other worktree; classification keys on the ARTIFACT path, so the
# cross-tree contract must still typecheck (rc 0).
if git -C "$main" worktree add --detach "$xr_wt" HEAD >/dev/null 2>&1; then
  expect_structure "cross-root contract in another worktree -> rc 0" 0 \
    "$xr_wt/ledger/contracts/dag.ncl"
  git -C "$main" worktree remove --force "$xr_wt" 2>/dev/null || rm -rf "$xr_wt"
  git -C "$main" worktree prune 2>/dev/null || true
else
  echo "FAIL  (env) could not create cross-root worktree at $xr_wt"; fails=$((fails + 1))
fi

echo "== AUTHORITY overlay from a worktree (the #1 regression) =="
# Skipped when an active-dag pointer is pre-existing (a live campaign owns it).
# The authority tests write and remove this pointer; skipping prevents clobbering
# the campaign's state. The structural and rename-hole tests below are unaffected.
if [ "$pointer_preexisting" -eq 1 ]; then
  echo "SKIP  authority overlay tests (active-dag pointer owned by another campaign)"
elif git -C "$main" worktree add --detach "$auth_wt" HEAD >/dev/null 2>&1; then
  # The authority overlay is campaign-dependent: it fires only when an active-dag
  # pointer is present in the MAIN tree (resolved via the common git dir, NOT the
  # worktree $root). We point it at dag_valid.ncl, whose node surfaces cover
  # ledger/ skills/ gates/ but NOT README.md. Running the hook DIRECTLY (a pure
  # check returning an exit code — no real `git commit`, so GPG is never touched)
  # from a linked worktree must:
  #   - BLOCK a staged README change (unauthorized path -> non-0), and
  #   - PASS a staged ledger/ change (authorized path -> 0).
  printf '%s\n' "ledger/fixtures/dag_valid.ncl" > "$pointer"

  # Unauthorized: stage a README change in the worktree, run the hook from there.
  ( cd "$auth_wt" && printf '\n<!-- test-gates probe -->\n' >> README.md \
      && git add README.md ) >/dev/null 2>&1
  expect "hook from worktree blocks unauthorized README -> non-0" 1 \
    bash -c 'cd "$1" && bash "$2"' _ "$auth_wt" "$hook"

  # Reset and stage an authorized ledger/ change instead; the hook must pass.
  ( cd "$auth_wt" && git reset -q HEAD . && git checkout -q -- README.md 2>/dev/null \
      && printf '\n<!-- test-gates probe -->\n' >> ledger/README.md \
      && git add ledger/README.md ) >/dev/null 2>&1
  expect "hook from worktree passes authorized ledger/ path -> 0" 0 \
    bash -c 'cd "$1" && bash "$2"' _ "$auth_wt" "$hook"

  # Tear down this case's pointer and worktree promptly (defence in depth; the
  # EXIT trap repeats it).
  rm -f "$pointer"
  git -C "$main" worktree remove --force "$auth_wt" 2>/dev/null || rm -rf "$auth_wt"
  git -C "$main" worktree prune 2>/dev/null || true
else
  echo "FAIL  (env) could not create authority worktree at $auth_wt"; fails=$((fails + 1))
fi

echo "== process-gate.sh: validate subcommand (direct) =="
# Direct validate cases: no git state required. The gate shells out to nickel
# to export-validate the YAML procedure deposit against the boundary contract
# via `nickel export --apply-contract`.  An honest deposit (all required steps
# present) must exit 0; a deposit that omits a required step must exit 1.
# YAML deposits are pure data — no self-binding (A-B1) or import is possible.
expect "process-gate honest boundary deposit -> rc 0" 0 \
  bash "$process_gate" validate \
    "$root/ledger/fixtures/process_gate_honest.yaml" boundary
expect "process-gate skip boundary deposit -> rc 1" 1 \
  bash "$process_gate" validate \
    "$root/ledger/fixtures/process_gate_skip.yaml" boundary
# Usage error: no-active-walk commit is not blocked by the validate subcommand
# itself (it is blocked at the hook level only when the pointer is present).
expect "process-gate unknown contract class -> rc 2" 2 \
  bash "$process_gate" validate \
    "$root/ledger/fixtures/process_gate_honest.yaml" unknown-class

# A-B1 regression: the gate must apply the class contract EXTERNALLY via
# --apply-contract — a deposit that carries no contract binding cannot bypass
# the footprint-presence check.  YAML deposits cannot self-bind by construction
# (YAML has no execution model); these NCL dodge cases verify that the external
# application also closes the bypass for NCL-format inputs.
# Two dodge patterns must FAIL (rc 1):
#   dodge-bare: a bare { workflow, steps=[] } record with no contract binding.
#   dodge-wrap: data nested in a wrapper field so footprint-presence fires.
# The gate catches both — --apply-contract applies the contract outside the
# deposit regardless of what the deposit contains.
cat > "$fixdir/process_gate_dodge_bare.ncl" <<'NCL'
# DODGE: bare record, no contract binding, steps=[].
# A-B1 regression: gate must reject this (rc 1) — steps=[] omits all required steps.
{
  workflow = "boundary-dodge",
  steps = [],
}
NCL
cat > "$fixdir/process_gate_dodge_wrap.ncl" <<'NCL'
# DODGE: data in a wrapper field, steps=[].
# A-B1 regression: gate must reject this (rc 1) — no .steps at top level,
# so the contract fires "missing field steps" or footprint-presence fails.
{
  instance = {
    workflow = "boundary-dodge",
    steps = [],
  },
}
NCL
expect "A-B1 dodge-bare (steps=[], no binding) -> rc 1" 1 \
  bash "$process_gate" validate \
    "$fixdir/process_gate_dodge_bare.ncl" boundary
expect "A-B1 dodge-wrap (wrapped field, steps=[]) -> rc 1" 1 \
  bash "$process_gate" validate \
    "$fixdir/process_gate_dodge_wrap.ncl" boundary

echo "== process-gate.sh: walk-activation overlay from a worktree =="
# Skipped when either pointer is pre-existing:
#   active-walk: a live walk owns it; we must not clobber it.
#   active-dag:  a live campaign is in flight; the campaign's authority overlay
#                fires on any linked worktree's staged set and blocks test
#                fixtures that are not in the campaign's file_surfaces.
if [ "$walk_pointer_preexisting" -eq 1 ]; then
  echo "SKIP  walk-activation overlay tests (active-walk pointer owned by a live walk)"
elif [ "$pointer_preexisting" -eq 1 ]; then
  echo "SKIP  walk-activation overlay tests (active-dag campaign authority would block test fixtures)"
elif git -C "$main" worktree add --detach "$proc_wt" HEAD >/dev/null 2>&1; then
# The process overlay fires in the pre-commit hook ONLY when .ledger/active-walk
# is present. The pointer is TWO LINES: line 1 = class, line 2 = deposit-path
# (pinned at register time). The hook validates ONLY the declared deposit-path
# (if staged); other files are never process-validated.
#
# Worker deposits are pure-data YAML — validated externally via
# `nickel export <deposit>.yaml --apply-contract <shim>.ncl`.  A YAML deposit
# cannot self-bind (A-B1) or import Nickel code; the data/code split enforced
# by the file format closes those attack vectors by construction.
#
# Cases (all run from a linked worktree to confirm main-tree pointer resolution):
#   (a) No pointer: staged honest .yaml passes (check 5 is skipped entirely).
#   (b) Pointer with deposit=pg_probe.yaml, stage HONEST deposit -> PASS (rc 0).
#   (c) Pointer with deposit=pg_probe.yaml, stage SKIP deposit -> FAIL (rc 1).
#   (d) THE FIX: pointer with deposit=pg_probe.yaml, stage a NON-DEPOSIT .ncl
#       (NOT pg_probe.yaml) -> PASS (rc 0): the gate ignores non-deposit files.
#   (e) A-B1: pointer with deposit=pg_probe.yaml, stage steps:[] YAML dodge AT
#       deposit path -> FAIL (rc 1): external contract catches empty footprint.
#
# NOTE: all hook invocations use $wt_hook (= $root/hooks/pre-commit, defined
# above at script level). The MAIN hook ($hook) is the old pre-tier-5 version;
# using it for these cases would silently skip check 5.

  # (a) No pointer: stage a YAML honest deposit in the worktree and confirm
  # the hook does NOT invoke the process gate (rc 0, clean pass via existing
  # checks only). We stage the honest fixture — if the process gate fired
  # without the pointer, it would still pass (honest = rc 0), so this case
  # does NOT distinguish walk vs no-walk by outcome. The meaningful guard here
  # is that the hook does not ERROR on an unknown class or a missing gate binary
  # when the pointer is absent (i.e., it genuinely skips check 5). YAML files
  # also bypass the .ncl structural check (check 3), so this is a clean no-op.
  ( cd "$proc_wt" \
      && cp "$root/ledger/fixtures/process_gate_honest.yaml" ledger/fixtures/pg_probe.yaml \
      && git add ledger/fixtures/pg_probe.yaml ) >/dev/null 2>&1
  expect "no active-walk pointer: hook passes honest .yaml -> rc 0" 0 \
    bash -c 'cd "$1" && bash "$2"' _ "$proc_wt" "$wt_hook"

  # Reset for next cases.
  ( cd "$proc_wt" && git reset -q HEAD . \
      && rm -f ledger/fixtures/pg_probe.yaml ) >/dev/null 2>&1

  # Write the active-walk pointer (class=boundary, deposit=ledger/fixtures/pg_probe.yaml).
  # Two-line format: line 1 = class, line 2 = deposit-path (repo-root-relative).
  printf 'boundary\nledger/fixtures/pg_probe.yaml\n' > "$walk_pointer"

  # (b) With pointer: stage the HONEST fixture at the declared deposit path
  # -> hook must pass (rc 0).
  ( cd "$proc_wt" \
      && cp "$root/ledger/fixtures/process_gate_honest.yaml" ledger/fixtures/pg_probe.yaml \
      && git add ledger/fixtures/pg_probe.yaml ) >/dev/null 2>&1
  expect "active-walk pointer present, honest deposit -> rc 0" 0 \
    bash -c 'cd "$1" && bash "$2"' _ "$proc_wt" "$wt_hook"

  # Reset, then stage SKIP fixture at the declared deposit path.
  ( cd "$proc_wt" && git reset -q HEAD . \
      && rm -f ledger/fixtures/pg_probe.yaml ) >/dev/null 2>&1

  # (c) With pointer: stage the SKIP fixture at the declared deposit path
  # (omits "attack") -> hook must fail (rc 1).
  ( cd "$proc_wt" \
      && cp "$root/ledger/fixtures/process_gate_skip.yaml" ledger/fixtures/pg_probe.yaml \
      && git add ledger/fixtures/pg_probe.yaml ) >/dev/null 2>&1
  expect "active-walk pointer present, skip deposit -> rc 1" 1 \
    bash -c 'cd "$1" && bash "$2"' _ "$proc_wt" "$wt_hook"

  # Reset.
  ( cd "$proc_wt" && git reset -q HEAD . \
      && rm -f ledger/fixtures/pg_probe.yaml ) >/dev/null 2>&1

  # (d) B2 REPRODUCED — declared deposit not staged. Pointer declares
  # deposit=pg_probe.yaml but we stage a DIFFERENT .ncl (a valid config record).
  # The declared deposit is NOT staged → gate must FAIL CLOSED (rc 1). Before the
  # B2 fix, the hook treated a missing deposit as a no-op and silently passed (rc 0):
  # "declared-but-never-delivered" was not caught. The B2 fix requires the declared
  # deposit to actually be staged. (Non-deposit files are still NEVER process-
  # validated; only the declared deposit is checked — and now it must be present.)
  ( cd "$proc_wt" \
      && printf '{ kind = "config", value = 42 }\n' > ledger/fixtures/pg_non_deposit.ncl \
      && git add ledger/fixtures/pg_non_deposit.ncl ) >/dev/null 2>&1
  expect "B2: declared deposit not staged (non-deposit .ncl staged) -> rc 1" 1 \
    bash -c 'cd "$1" && bash "$2"' _ "$proc_wt" "$wt_hook"

  # Reset.
  ( cd "$proc_wt" && git reset -q HEAD . \
      && rm -f ledger/fixtures/pg_non_deposit.ncl ) >/dev/null 2>&1

  # (d') Non-deposit .ncl staged ALONGSIDE the declared deposit (both staged) ->
  # PASS (rc 0). Deposits a config record next to the honest deposit. The gate must
  # find the declared deposit (it IS staged), validate it, and pass — without
  # process-validating the non-deposit file. Confirms the "only declared deposit
  # validated" property holds after the B2 fix (deposit present → validates and
  # passes; non-deposit → not process-validated, no false-positive rejection).
  ( cd "$proc_wt" \
      && cp "$root/ledger/fixtures/process_gate_honest.yaml" ledger/fixtures/pg_probe.yaml \
      && printf '{ kind = "config", value = 42 }\n' > ledger/fixtures/pg_non_deposit.ncl \
      && git add ledger/fixtures/pg_probe.yaml ledger/fixtures/pg_non_deposit.ncl ) >/dev/null 2>&1
  expect "non-deposit .ncl alongside honest deposit (both staged) -> rc 0" 0 \
    bash -c 'cd "$1" && bash "$2"' _ "$proc_wt" "$wt_hook"

  # Reset.
  ( cd "$proc_wt" && git reset -q HEAD . \
      && rm -f ledger/fixtures/pg_probe.yaml ledger/fixtures/pg_non_deposit.ncl ) >/dev/null 2>&1

  # B2 explicit: walk declares deposit=pg_probe.yaml but stages a file at a
  # DIFFERENT path — ledger/fixtures/pg_probe_b2.ncl. The gate sees:
  #   - pg_probe_b2.ncl IS staged but is NOT the declared deposit → not process-validated
  #   - pg_probe.yaml is NOT staged → before B2 fix: no-op → silent pass (rc 0) [BUG]
  # After B2 fix: declared deposit not staged → FAIL CLOSED (rc 1).
  # pg_probe_b2.ncl uses valid NCL content so check 3 (structural) does not fail
  # for the wrong reason — only check 5 (process gate) fires here.
  ( cd "$proc_wt" \
      && printf '{ kind = "config", value = 42 }\n' > ledger/fixtures/pg_probe_b2.ncl \
      && git add ledger/fixtures/pg_probe_b2.ncl ) >/dev/null 2>&1
  expect "B2 explicit: skip deposit at wrong path, declared deposit absent -> rc 1" 1 \
    bash -c 'cd "$1" && bash "$2"' _ "$proc_wt" "$wt_hook"

  # Reset.
  ( cd "$proc_wt" && git reset -q HEAD . \
      && rm -f ledger/fixtures/pg_probe_b2.ncl ) >/dev/null 2>&1

  # (e) A-B1 still closed. Pointer declares deposit=pg_probe.yaml; stage a YAML
  # deposit with steps: [] at that exact path -> hook must still FAIL (rc 1).
  # YAML deposits cannot import Nickel or self-bind; the gate applies the contract
  # externally via --apply-contract, and steps: [] omits all required footprints.
  ( cd "$proc_wt" \
      && printf 'workflow: boundary-dodge\nsteps: []\n' \
           > ledger/fixtures/pg_probe.yaml \
      && git add ledger/fixtures/pg_probe.yaml ) >/dev/null 2>&1
  expect "A-B1: steps=[] YAML dodge at deposit path still rejected -> rc 1" 1 \
    bash -c 'cd "$1" && bash "$2"' _ "$proc_wt" "$wt_hook"

  # Reset.
  ( cd "$proc_wt" && git reset -q HEAD . \
      && rm -f ledger/fixtures/pg_probe.yaml ) >/dev/null 2>&1

  echo "== B3: deposit-path normalization (./prefix, //, absolute) =="
  # B3: the pointer carries the deposit path as a raw string; git diff --cached
  # --name-only always emits repo-root-relative paths without ./ prefix or //
  # sequences. If the pointer uses a non-canonical form, the staged-set comparison
  # never matches → deposit_staged=0 → gate no-ops → silent pass [BUG].
  # After the B3 fix: normalize before compare → match found → validate.
  # All B3 cases stage a SKIP deposit at the canonical path so a found+validated
  # deposit exits rc 1; before the fix the deposit is not found and the gate
  # no-ops (rc 0 — the wrong verdict for a skip deposit).

  # B3-dot: pointer has ./ledger/fixtures/pg_probe.yaml (leading ./). Without
  # normalization, ./X ≠ X → deposit_staged=0 → no-op → rc 0 [BUG].
  # After B3 fix: strip ./ → X, match found, validate skip → rc 1.
  printf 'boundary\n./ledger/fixtures/pg_probe.yaml\n' > "$walk_pointer"
  ( cd "$proc_wt" \
      && cp "$root/ledger/fixtures/process_gate_skip.yaml" ledger/fixtures/pg_probe.yaml \
      && git add ledger/fixtures/pg_probe.yaml ) >/dev/null 2>&1
  expect "B3-dot: ./path pointer, skip deposit at canonical path -> rc 1" 1 \
    bash -c 'cd "$1" && bash "$2"' _ "$proc_wt" "$wt_hook"

  ( cd "$proc_wt" && git reset -q HEAD . \
      && rm -f ledger/fixtures/pg_probe.yaml ) >/dev/null 2>&1

  # B3-dot-honest: ./path pointer, HONEST deposit at canonical path → PASS (rc 0).
  # Confirms normalization finds AND successfully validates (not just no-ops).
  ( cd "$proc_wt" \
      && cp "$root/ledger/fixtures/process_gate_honest.yaml" ledger/fixtures/pg_probe.yaml \
      && git add ledger/fixtures/pg_probe.yaml ) >/dev/null 2>&1
  expect "B3-dot-honest: ./path pointer, honest deposit at canonical path -> rc 0" 0 \
    bash -c 'cd "$1" && bash "$2"' _ "$proc_wt" "$wt_hook"

  ( cd "$proc_wt" && git reset -q HEAD . \
      && rm -f ledger/fixtures/pg_probe.yaml ) >/dev/null 2>&1

  # B3-slash: pointer has ledger//fixtures/pg_probe.yaml (doubled //). Without
  # normalization: ledger//... ≠ ledger/... → no-op → rc 0 [BUG].
  # After B3 fix: collapse // → single /, match found, validate skip → rc 1.
  printf 'boundary\nledger//fixtures/pg_probe.yaml\n' > "$walk_pointer"
  ( cd "$proc_wt" \
      && cp "$root/ledger/fixtures/process_gate_skip.yaml" ledger/fixtures/pg_probe.yaml \
      && git add ledger/fixtures/pg_probe.yaml ) >/dev/null 2>&1
  expect "B3-slash: //path pointer, skip deposit at canonical path -> rc 1" 1 \
    bash -c 'cd "$1" && bash "$2"' _ "$proc_wt" "$wt_hook"

  ( cd "$proc_wt" && git reset -q HEAD . \
      && rm -f ledger/fixtures/pg_probe.yaml ) >/dev/null 2>&1

  # B3-abs: pointer has absolute /abs/path/ledger/fixtures/pg_probe.yaml. Without
  # normalization: /abs/.../... ≠ ledger/... → no-op → rc 0 [BUG].
  # After B3 fix: strip $root/ prefix → repo-relative, match found, skip → rc 1.
  printf 'boundary\n%s/ledger/fixtures/pg_probe.yaml\n' "$proc_wt" > "$walk_pointer"
  ( cd "$proc_wt" \
      && cp "$root/ledger/fixtures/process_gate_skip.yaml" ledger/fixtures/pg_probe.yaml \
      && git add ledger/fixtures/pg_probe.yaml ) >/dev/null 2>&1
  expect "B3-abs: absolute-path pointer, skip deposit at canonical path -> rc 1" 1 \
    bash -c 'cd "$1" && bash "$2"' _ "$proc_wt" "$wt_hook"

  # Reset and restore standard pointer form for teardown.
  ( cd "$proc_wt" && git reset -q HEAD . \
      && rm -f ledger/fixtures/pg_probe.yaml ) >/dev/null 2>&1
  printf 'boundary\nledger/fixtures/pg_probe.yaml\n' > "$walk_pointer"

  # Teardown: remove the walk pointer and the worktree promptly.
  rm -f "$walk_pointer"
  ( cd "$proc_wt" && git reset -q HEAD . ) >/dev/null 2>&1
  git -C "$main" worktree remove --force "$proc_wt" 2>/dev/null || rm -rf "$proc_wt"
  git -C "$main" worktree prune 2>/dev/null || true
else
  echo "FAIL  (env) could not create process-gate worktree at $proc_wt"; fails=$((fails + 1))
fi

echo "== pre-commit check 3 (B1 regression): .ncl path scoping =="
# B1 regression: the structural .ncl check must be SCOPED to predicate-owned
# paths (ledger/, .ledger/, conditioning/). A downstream user's own .ncl file
# at the repo root (e.g. a function library) is not a predicate artifact; the
# hook must skip it silently. Conversely, a malformed .ncl under ledger/ must
# still be blocked (the predicate path scoping only skips non-predicate paths;
# it does not weaken validation of predicate's own artifacts).
#
# Both cases run from a linked worktree via the WORKTREE hook directly (same
# pattern as the authority and process-gate regressions). The B1 path-scoping
# fix lives in the worktree hook; the main hook ($hook) lacks it, so using $hook
# here would silently miss the regression. No active-dag or active-walk pointer
# is written, so only the structural layer fires.
#
# Skipped when an active-dag campaign is in flight: the campaign's authority
# overlay fires on the linked worktree's staged set and would block test fixtures
# that are not in the campaign's file_surfaces (same reason as walk-activation).
if [ "$pointer_preexisting" -eq 1 ]; then
  echo "SKIP  B1 worktree tests (active-dag campaign authority would block test fixtures)"
elif git -C "$main" worktree add --detach "$b1_wt" HEAD >/dev/null 2>&1; then

  # (a) Root-level lib.ncl (non-predicate path): hook must PASS (rc 0).
  # A function library that exports a non-serializable value (fun ...) is valid
  # Nickel but would fail ledger-validate.sh structure ("non serializable term").
  # After the B1 fix, the hook skips it — no misleading error, rc 0.
  printf '{ add = fun x y => x + y }\n' > "$b1_wt/lib.ncl"
  ( cd "$b1_wt" && git add lib.ncl ) >/dev/null 2>&1
  expect "B1: root lib.ncl (non-predicate) skipped by hook -> rc 0" 0 \
    bash -c 'cd "$1" && bash "$2"' _ "$b1_wt" "$wt_hook"

  # Reset, then write a malformed ledger/fixtures/ .ncl to confirm predicate paths
  # are still validated (B1 fix must not weaken ledger validation).
  ( cd "$b1_wt" && git reset -q HEAD . && rm -f lib.ncl ) >/dev/null 2>&1
  # (b) Malformed ledger/ .ncl: hook must BLOCK (rc 1).
  # A ledger/ .ncl that is a function library (non-serializable) is not a valid
  # ledger artifact — the structural check must block it.
  printf '{ add = fun x y => x + y }\n' > "$b1_wt/ledger/fixtures/b1_malformed_probe.ncl"
  ( cd "$b1_wt" && git add ledger/fixtures/b1_malformed_probe.ncl ) >/dev/null 2>&1
  expect "B1: malformed ledger/ .ncl still blocked by hook -> rc 1" 1 \
    bash -c 'cd "$1" && bash "$2"' _ "$b1_wt" "$wt_hook"

  # Teardown.
  ( cd "$b1_wt" && git reset -q HEAD . \
      && rm -f ledger/fixtures/b1_malformed_probe.ncl ) >/dev/null 2>&1
  git -C "$main" worktree remove --force "$b1_wt" 2>/dev/null || rm -rf "$b1_wt"
  git -C "$main" worktree prune 2>/dev/null || true
else
  echo "FAIL  (env) could not create B1 worktree at $b1_wt"; fails=$((fails + 1))
fi

echo "== rename-hole: structural check fires on renamed+corrupted .ncl (ACMR fix) =="
# The pre-commit hook's staged set was built with --diff-filter=ACM, which
# EXCLUDES renames (type R). A `git mv X Y` where content similarity is >= 50%
# makes git classify the change as R-not-A; with ACM the new path Y is absent
# from the staged set, so NO structural validation runs on it — a corrupted
# .ncl lands undetected (skill-contract-relocate's 5 renames were never
# structure-checked at commit; only a later test suite caught them).
#
# After the fix (--diff-filter=ACMR), Y is in the staged set and structural
# validation blocks the commit (rc 1).
#
# Precondition assertion: we confirm git classifies the staged change as type R
# (rename). If it doesn't (e.g. git version without rename detection), the case
# is skipped with a diagnostic rather than a false FAIL.
#
# Isolation: git clone --no-local gives the probe repo its own .git, own staging
# area, and NO connection to the main tree's .ledger/ pointers (so the
# authority and process overlays never fire — only the structural tier runs).
rn_repo="$fixdir/rn_repo"
git clone --no-local -q "$main" "$rn_repo" 2>/dev/null
git -C "$rn_repo" config user.name test-gates
git -C "$rn_repo" config user.email test@gates
git -C "$rn_repo" config commit.gpgsign false

# Commit a VALID fixture with enough content for git to detect a rename after
# the corruption (content similarity well above the default 50% threshold).
cat > "$rn_repo/ledger/fixtures/rn_probe.ncl" <<'NCL'
# rename-hole probe fixture — must remain exportable at commit time.
# Content bulk ensures git rename-detection fires (similarity > 50%)
# after the subtle corruption appended below the mv.
let base = {
  id = "probe",
  source = "original",
  tags = ["a", "b", "c", "d", "e"],
  count = 10,
  active = true,
  nested = { x = 1, y = 2, z = 3, w = 4, v = 5 },
} in
base
NCL
git -C "$rn_repo" add ledger/fixtures/rn_probe.ncl
git -C "$rn_repo" commit -q -m "test: add rename-hole probe fixture"

# git mv to a new name, then append an unterminated expression — this:
#   (a) keeps content similarity > 50% so git detects a rename (type R), and
#   (b) causes `nickel export` to fail with a parse error (structural gate).
git -C "$rn_repo" mv ledger/fixtures/rn_probe.ncl ledger/fixtures/rn_probe_moved.ncl
printf '\n| (let broken_syntax = \n' >> "$rn_repo/ledger/fixtures/rn_probe_moved.ncl"
git -C "$rn_repo" add ledger/fixtures/rn_probe_moved.ncl

# Assert precondition: git must classify this as a rename (type R), not an Add.
# Without type-R detection the test does not exercise the rename-hole (the Add
# path A is already captured by ACM, so no gate bypass exists to close).
rn_status="$(git -C "$rn_repo" diff --cached --name-status)"
if ! printf '%s\n' "$rn_status" | grep -q '^R'; then
  echo "SKIP  rename-hole precondition: git did not detect rename (type R) — skipping"
  echo "      name-status: $rn_status"
else
  # After the fix (--diff-filter=ACMR) the hook must block a renamed+corrupted
  # predicate .ncl (rc 1). Before the fix (ACM) the hook exits rc 0 — the
  # rename slips through the empty staged set entirely.
  expect "rename-hole: git mv + corrupt ledger/ .ncl blocked by hook -> rc 1" 1 \
    bash -c 'cd "$1" && bash "$2"' _ "$rn_repo" "$wt_hook"
fi
( cd "$rn_repo" && git reset -q HEAD . ) >/dev/null 2>&1

echo "== check_docs.py: anchor (#fragment) validation =="
# A link target file exists but its #anchor names no heading -> broken (rc 1).
expect "dangling #anchor -> broken (non-0)" 1 \
  python3 "$check_docs" "$fixdir/bad_anchor.md"
# A link whose #anchor matches a heading slug -> valid (rc 0).
expect "good #anchor -> valid (0)" 0 \
  python3 "$check_docs" "$fixdir/good_anchor.md"

echo "== recorder_close_check.sh: CLOSE-retrospective recorded =="
# POSITIVE: recorder history has a `log: close demo-topic …` commit with a
# non-empty Sufficiency Review section -> rc 0.
expect "recorder with close entry + non-empty sufficiency section -> rc 0" 0 \
  bash "$recorder_close_check" demo-topic "$rec_with"
# NEGATIVE: recorder history has no close commit at all -> rc 1.
expect "recorder without close entry -> rc 1" 1 \
  bash "$recorder_close_check" demo-topic "$rec_without"
# USAGE: empty topic -> rc 2.
expect "empty topic -> usage error rc 2" 2 \
  bash "$recorder_close_check" "" "$rec_with"
# TDD polarity — structural floor (Check 2):
# empty heading → FAIL (hollow section must not pass the structural floor)
expect "close entry with empty Sufficiency Review section -> rc 1" 1 \
  bash "$recorder_close_check" demo-topic "$rec_empty_section"
# no heading → FAIL (close commit exists but retrospective has no section at all)
expect "close entry with no Sufficiency Review heading -> rc 1" 1 \
  bash "$recorder_close_check" demo-topic "$rec_no_heading"


echo "== check_orphans.sh: live refs to removed workflows =="
# Live "/plan " reference with plan in the removed list -> flagged (rc 1).
cp "$orph_root/doc_orphan.md" "$orph_root/doc.md"
expect "live ref to removed 'plan' -> flagged (rc 1)" 1 \
  bash "$check_orphans" "$orph_root" plan
# Clean doc -> no orphans (rc 0).
cp "$orph_root/doc_clean.md" "$orph_root/doc.md"
expect "clean doc -> no orphans (rc 0)" 0 \
  bash "$check_orphans" "$orph_root" plan
# P30 regression: predicate's own namespace, current removed set (no 'predicate')
# -> NOT flagged (rc 0). Guards against re-flagging the project's own namespace.
cp "$orph_root/doc_p30.md" "$orph_root/doc.md"
expect "predicate: namespace, current removed set -> not flagged (rc 0)" 0 \
  bash "$check_orphans" "$orph_root" core sketch dialectic

echo "== check_selfcontained.sh: commit-message self-containment =="
# An internal node-ID reference (P30) is unresolvable from the repo alone -> fail.
expect "message with internal ref (P30) -> violation (rc 1)" 1 \
  bash "$check_selfcontained" "fix: address the P30 finding"
# A self-contained message naming only repo-visible concepts -> pass.
expect "self-contained message -> clean (rc 0)" 0 \
  bash "$check_selfcontained" "fix: correct the merge-discipline diagnostic"

echo "== sync_sketch.py: auto-commit a modified sketch to the recorder =="
# Run the sandboxed copy; it must stage+commit the untracked frontmatter sketch
# into the throwaway .ledger/log with a docs(sketch): sync … message, leaving the
# sub-repo clean. We assert the script's rc 0 AND that the commit actually landed.
expect "sync commits the modified sketch -> rc 0" 0 \
  python3 "$sync_box/skills/refine/scripts/sync_sketch.py"
# Post-condition: the recorder sub-repo is clean (the sketch was committed, not
# left dangling) and the head subject is the generated sync message.
sync_clean="$(git -C "$sync_box/.ledger/log" status --porcelain)"
sync_subj="$(git -C "$sync_box/.ledger/log" log -1 --format='%s')"
if [ -z "$sync_clean" ] && printf '%s' "$sync_subj" | grep -q '^docs(sketch): sync demo-topic'; then
  echo "PASS  (0) sync left recorder clean with a docs(sketch) commit"
else
  echo "FAIL  sync post-condition: status='$sync_clean' subject='$sync_subj'"
  fails=$((fails + 1))
fi

echo "== check_commit_msg.py: conventional-commit gate + merge exemption =="
# Git's auto-generated merge subjects are exempt — else every real merge fails
# the gate and pushes people toward --no-verify; a non-merge bad header still
# fails, so the exemption is not an escape hatch.
expect "merge subject -> exempt (rc 0)" 0 \
  python3 "$check_commit_msg" --message "Merge branch 'x' into y"
expect "merge PR subject -> exempt (rc 0)" 0 \
  python3 "$check_commit_msg" --message "Merge pull request #1 from a/b"
expect "bad non-merge header -> violation (rc 1)" 1 \
  python3 "$check_commit_msg" --message "garbage header with no type"
expect "good conventional header -> clean (rc 0)" 0 \
  python3 "$check_commit_msg" --message "feat: add a thing"

if [ "$fails" -ne 0 ]; then
  echo "FAIL: $fails gate case(s) mismatched"; exit 1
fi
echo "PASS: all gate cases matched their expected exit codes (main + worktree)"
exit 0
