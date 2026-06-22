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
check_docs="$root/skills/doc-audit/scripts/check_docs.py"
recorder_close_check="$here/recorder_close_check.sh"
adherence_audit="$here/adherence_audit.sh"
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

# adherence_audit.sh fixtures (Deliverable A1, the isolation gate). The gate reads
# the CURRENT-DIRECTORY repo's history (it calls git with no -C), so each case cd's
# into the throwaway repo before invoking. Check 1 of the gate also requires the
# integration branch to be named campaign/*, so both repos use that name and only
# the MERGE DISCIPLINE differs between them — isolating the core check.
#   adh_merge:  baseline -> node/x branch -> --no-ff merge into campaign/demo
#               => merges>0, direct==0 => rc 0 (isolation maintained).
#   adh_direct: baseline -> DIRECT commits on campaign/demo (no merges)
#               => merges==0 => rc 1 (the flat-campaign bypass the gate catches).
adh_merge="$fixdir/adh_merge"
adh_direct="$fixdir/adh_direct"
mkdir -p "$adh_merge" "$adh_direct"
git "${git_id[@]}" -C "$adh_merge" init -q -b master
: > "$adh_merge/f"; git "${git_id[@]}" -C "$adh_merge" add f
git "${git_id[@]}" -C "$adh_merge" commit -q -m "feat: baseline"
adh_merge_base="$(git -C "$adh_merge" rev-parse HEAD)"
git "${git_id[@]}" -C "$adh_merge" checkout -q -b campaign/demo
git "${git_id[@]}" -C "$adh_merge" checkout -q -b node/x
: > "$adh_merge/g"; git "${git_id[@]}" -C "$adh_merge" add g
git "${git_id[@]}" -C "$adh_merge" commit -q -m "feat: node x work"
git "${git_id[@]}" -C "$adh_merge" checkout -q campaign/demo
git "${git_id[@]}" -C "$adh_merge" merge --no-ff -q node/x -m "merge: land node/x"
git "${git_id[@]}" -C "$adh_direct" init -q -b master
: > "$adh_direct/f"; git "${git_id[@]}" -C "$adh_direct" add f
git "${git_id[@]}" -C "$adh_direct" commit -q -m "feat: baseline"
adh_direct_base="$(git -C "$adh_direct" rev-parse HEAD)"
git "${git_id[@]}" -C "$adh_direct" checkout -q -b campaign/demo
: > "$adh_direct/g"; git "${git_id[@]}" -C "$adh_direct" add g
git "${git_id[@]}" -C "$adh_direct" commit -q -m "feat: direct mainline work"

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
xr_wt="$main/.scratch/worktrees/test-gates-xr-$$"   # cross-root artifact worktree
auth_wt="$main/.scratch/worktrees/test-gates-auth-$$" # authority-from-worktree

# Was a pointer already present before we started? If so a real campaign may own
# it; we must NOT remove it on teardown. (Defensive: we also refuse to run.)
pointer_preexisting=0
[ -e "$pointer" ] && pointer_preexisting=1

cleanup() {
  # Pointer teardown FIRST and unconditional — the highest-risk leak. Only remove
  # what we created: leave a pre-existing pointer untouched.
  if [ "$pointer_preexisting" -eq 0 ]; then
    rm -f "$pointer"
  fi
  for w in "$xr_wt" "$auth_wt"; do
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

echo "== adherence_audit.sh: isolation via merge-history (the isolation gate) =="
# The gate reads the CURRENT-DIRECTORY repo's history, so each case cd's into the
# throwaway repo first. MERGE-based campaign history -> isolation OK (rc 0).
expect "merge-history campaign -> isolation OK (rc 0)" 0 \
  bash -c 'cd "$1" && bash "$2" "$3" "$4"' _ \
    "$adh_merge" "$adherence_audit" "$adh_merge_base" campaign/demo
# DIRECT commits on the campaign branch -> isolation bypass detected (rc 1).
expect "direct-history campaign -> bypass detected (rc 1)" 1 \
  bash -c 'cd "$1" && bash "$2" "$3" "$4"' _ \
    "$adh_direct" "$adherence_audit" "$adh_direct_base" campaign/demo

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
