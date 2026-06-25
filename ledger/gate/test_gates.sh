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

# Recorder fixtures for recorder_close_check.sh (Deliverable B). Two THROWAWAY git
# repos, NEVER the real .ledger: one with a `log: close demo-topic …` commit
# (positive), one with no such commit (negative). They nest under $fixdir, so the
# existing `rm -rf "$fixdir"` in cleanup() tears them down. git is run with an
# isolated identity so the harness needs no global git config to commit.
rec_with="$fixdir/recorder_with"
rec_without="$fixdir/recorder_without"
git_id=(-c user.name=test-gates -c user.email=test@gates -c commit.gpgsign=false)
mkdir -p "$rec_with" "$rec_without"
git "${git_id[@]}" -C "$rec_with" init -q
: > "$rec_with/log.md"
git "${git_id[@]}" -C "$rec_with" add log.md
git "${git_id[@]}" -C "$rec_with" commit -q -m "log: close demo-topic retrospective"
git "${git_id[@]}" -C "$rec_without" init -q
: > "$rec_without/log.md"
git "${git_id[@]}" -C "$rec_without" add log.md
git "${git_id[@]}" -C "$rec_without" commit -q -m "log: open demo-topic"


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
  echo "FAIL: an active-dag pointer already exists at $pointer" >&2
  echo "  Refusing to run (a real campaign may own it; we will not clobber it)." >&2
  exit 2
fi
if [ "$walk_pointer_preexisting" -eq 1 ]; then
  echo "FAIL: an active-walk pointer already exists at $walk_pointer" >&2
  echo "  Refusing to run (a live walk may own it; we will not clobber it)." >&2
  exit 2
fi

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
# The authority overlay is campaign-dependent: it fires only when an active-dag
# pointer is present in the MAIN tree (resolved via the common git dir, NOT the
# worktree $root). We point it at dag_valid.ncl, whose node surfaces cover
# ledger/ skills/ gates/ but NOT README.md. Running the hook DIRECTLY (a pure
# check returning an exit code — no real `git commit`, so GPG is never touched)
# from a linked worktree must:
#   - BLOCK a staged README change (unauthorized path -> non-0), and
#   - PASS a staged ledger/ change (authorized path -> 0).
if git -C "$main" worktree add --detach "$auth_wt" HEAD >/dev/null 2>&1; then
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
# to export-validate the procedure instance against the boundary contract. An
# honest deposit (all required steps present) must exit 0; a deposit that omits
# a required step must exit 1.
expect "process-gate honest boundary deposit -> rc 0" 0 \
  bash "$process_gate" validate \
    "$root/ledger/fixtures/process_gate_honest.ncl" boundary
expect "process-gate skip boundary deposit -> rc 1" 1 \
  bash "$process_gate" validate \
    "$root/ledger/fixtures/process_gate_skip.ncl" boundary
# Usage error: no-active-walk commit is not blocked by the validate subcommand
# itself (it is blocked at the hook level only when the pointer is present).
expect "process-gate unknown contract class -> rc 2" 2 \
  bash "$process_gate" validate \
    "$root/ledger/fixtures/process_gate_honest.ncl" unknown-class

# A-B1 regression: the gate must apply the class contract EXTERNALLY — a deposit
# that does not self-bind its contract cannot bypass the footprint-presence check.
# Two dodge patterns must FAIL (rc 1):
#   dodge-bare: a bare { workflow, steps=[] } record with no contract import at all.
#   dodge-wrap: a file that imports the contract but puts the data in a wrapper
#               field with no contract annotation, so the binding is never applied.
# The gate must catch both — the external application closes the bypass.
cat > "$fixdir/process_gate_dodge_bare.ncl" <<'NCL'
# DODGE: bare record, no contract import or binding, steps=[].
# A-B1 regression: gate must reject this (rc 1) — steps=[] omits all required steps.
{
  workflow = "boundary-dodge",
  steps = [],
}
NCL
cat > "$fixdir/process_gate_dodge_wrap.ncl" <<'NCL'
# DODGE: file wraps data in a field with no contract annotation, steps=[].
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
expect "A-B1 dodge-wrap (wrapped, no annotation, steps=[]) -> rc 1" 1 \
  bash "$process_gate" validate \
    "$fixdir/process_gate_dodge_wrap.ncl" boundary

echo "== process-gate.sh: walk-activation overlay from a worktree =="
# The process overlay fires in the pre-commit hook ONLY when .ledger/active-walk
# is present. The pointer is now TWO LINES: line 1 = class, line 2 = deposit-path
# (pinned at register time). The hook validates ONLY the declared deposit-path
# (if staged); other .ncl files are never process-validated.
#
# Cases (all run from a linked worktree to confirm main-tree pointer resolution):
#   (a) No pointer: staged honest .ncl passes (check 5 is skipped entirely).
#   (b) Pointer with deposit=pg_probe.ncl, stage HONEST deposit -> PASS (rc 0).
#   (c) Pointer with deposit=pg_probe.ncl, stage SKIP deposit -> FAIL (rc 1).
#   (d) THE FIX: pointer with deposit=pg_probe.ncl, stage a NON-DEPOSIT .ncl
#       (NOT pg_probe.ncl) -> PASS (rc 0): the gate ignores non-deposit .ncl.
#   (e) A-B1: pointer with deposit=pg_probe.ncl, stage steps=[] dodge AT deposit
#       path -> FAIL (rc 1): A-B1 still closed, external contract still applied.
#
# NOTE: all hook invocations use $root/hooks/pre-commit (the WORKTREE hook, which
# carries the tier-5 PROCESS implementation). The MAIN hook ($hook) is the old
# pre-tier-5 version; using it for these cases would silently skip check 5.
wt_hook="$root/hooks/pre-commit"
if git -C "$main" worktree add --detach "$proc_wt" HEAD >/dev/null 2>&1; then

  # (a) No pointer: stage a process_gate_honest.ncl in the worktree and confirm
  # the hook does NOT invoke the process gate (rc 0, clean pass via existing
  # checks only). We stage the honest fixture — if the process gate fired
  # without the pointer, it would still pass (honest = rc 0), so this case
  # does NOT distinguish walk vs no-walk by outcome. The meaningful guard here
  # is that the hook does not ERROR on an unknown class or a missing gate binary
  # when the pointer is absent (i.e., it genuinely skips check 5).
  ( cd "$proc_wt" \
      && cp "$root/ledger/fixtures/process_gate_honest.ncl" ledger/fixtures/pg_probe.ncl \
      && git add ledger/fixtures/pg_probe.ncl ) >/dev/null 2>&1
  expect "no active-walk pointer: hook passes honest .ncl -> rc 0" 0 \
    bash -c 'cd "$1" && bash "$2"' _ "$proc_wt" "$wt_hook"

  # Reset for next cases.
  ( cd "$proc_wt" && git reset -q HEAD . \
      && rm -f ledger/fixtures/pg_probe.ncl ) >/dev/null 2>&1

  # Write the active-walk pointer (class=boundary, deposit=ledger/fixtures/pg_probe.ncl).
  # Two-line format: line 1 = class, line 2 = deposit-path (repo-root-relative).
  printf 'boundary\nledger/fixtures/pg_probe.ncl\n' > "$walk_pointer"

  # (b) With pointer: stage the HONEST fixture at the declared deposit path
  # -> hook must pass (rc 0).
  ( cd "$proc_wt" \
      && cp "$root/ledger/fixtures/process_gate_honest.ncl" ledger/fixtures/pg_probe.ncl \
      && git add ledger/fixtures/pg_probe.ncl ) >/dev/null 2>&1
  expect "active-walk pointer present, honest deposit -> rc 0" 0 \
    bash -c 'cd "$1" && bash "$2"' _ "$proc_wt" "$wt_hook"

  # Reset, then stage SKIP fixture at the declared deposit path.
  ( cd "$proc_wt" && git reset -q HEAD . \
      && rm -f ledger/fixtures/pg_probe.ncl ) >/dev/null 2>&1

  # (c) With pointer: stage the SKIP fixture at the declared deposit path
  # (omits "attack") -> hook must fail (rc 1).
  ( cd "$proc_wt" \
      && cp "$root/ledger/fixtures/process_gate_skip.ncl" ledger/fixtures/pg_probe.ncl \
      && git add ledger/fixtures/pg_probe.ncl ) >/dev/null 2>&1
  expect "active-walk pointer present, skip deposit -> rc 1" 1 \
    bash -c 'cd "$1" && bash "$2"' _ "$proc_wt" "$wt_hook"

  # Reset.
  ( cd "$proc_wt" && git reset -q HEAD . \
      && rm -f ledger/fixtures/pg_probe.ncl ) >/dev/null 2>&1

  # (d) THE FIX — over-rejection regression. Pointer declares deposit=pg_probe.ncl
  # but we stage a DIFFERENT (non-deposit) .ncl (a valid config record). The hook
  # must NOT reject it: only the declared deposit is process-validated, never other
  # .ncl files. BEFORE the fix this would fail (the hook iterated ALL staged .ncl).
  ( cd "$proc_wt" \
      && printf '{ kind = "config", value = 42 }\n' > ledger/fixtures/pg_non_deposit.ncl \
      && git add ledger/fixtures/pg_non_deposit.ncl ) >/dev/null 2>&1
  expect "active-walk pointer, non-deposit .ncl staged (NOT deposit path) -> rc 0" 0 \
    bash -c 'cd "$1" && bash "$2"' _ "$proc_wt" "$wt_hook"

  # Reset.
  ( cd "$proc_wt" && git reset -q HEAD . \
      && rm -f ledger/fixtures/pg_non_deposit.ncl ) >/dev/null 2>&1

  # (e) A-B1 still closed. Pointer declares deposit=pg_probe.ncl; stage a steps=[]
  # dodge at that exact path -> hook must still FAIL (rc 1). The gate applies the
  # contract externally; the self-binding omission is not an escape hatch.
  ( cd "$proc_wt" \
      && printf '{ workflow = "boundary-dodge", steps = [] }\n' \
           > ledger/fixtures/pg_probe.ncl \
      && git add ledger/fixtures/pg_probe.ncl ) >/dev/null 2>&1
  expect "A-B1: steps=[] dodge at deposit path still rejected -> rc 1" 1 \
    bash -c 'cd "$1" && bash "$2"' _ "$proc_wt" "$wt_hook"

  # Teardown: remove the walk pointer and the worktree promptly.
  rm -f "$walk_pointer"
  ( cd "$proc_wt" && git reset -q HEAD . \
      && rm -f ledger/fixtures/pg_probe.ncl ) >/dev/null 2>&1
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
if git -C "$main" worktree add --detach "$b1_wt" HEAD >/dev/null 2>&1; then

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

echo "== check_docs.py: anchor (#fragment) validation =="
# A link target file exists but its #anchor names no heading -> broken (rc 1).
expect "dangling #anchor -> broken (non-0)" 1 \
  python3 "$check_docs" "$fixdir/bad_anchor.md"
# A link whose #anchor matches a heading slug -> valid (rc 0).
expect "good #anchor -> valid (0)" 0 \
  python3 "$check_docs" "$fixdir/good_anchor.md"

echo "== recorder_close_check.sh: CLOSE-retrospective recorded =="
# POSITIVE: recorder history has a `log: close demo-topic …` commit -> rc 0.
expect "recorder with close entry -> rc 0" 0 \
  bash "$recorder_close_check" demo-topic "$rec_with"
# NEGATIVE: recorder history has no such close commit -> rc 1 (the discipline
# the gate exists to catch: a CLOSE whose retrospective was never recorded).
expect "recorder without close entry -> rc 1" 1 \
  bash "$recorder_close_check" demo-topic "$rec_without"
# USAGE: empty topic -> rc 2.
expect "empty topic -> usage error rc 2" 2 \
  bash "$recorder_close_check" "" "$rec_with"


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
