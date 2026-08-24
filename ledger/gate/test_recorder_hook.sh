#!/usr/bin/env bash
# test_recorder_hook.sh — TDD for the recorder's own commit-time gate.
#
# The hole this closes: .ledger/ is its own git repository (never part of the
# project repo — ledger/README.md), so the project's hooks/pre-commit never
# sees a commit made INSIDE it. Every record class (tech-debt, process-
# feedback) ships a Nickel contract, but until recorder-pre-commit.sh existed
# nothing invoked those contracts at commit time — an invalid record could
# land in .ledger cleanly.
#
# Coverage (two levels):
#
#   1. GATE UNIT (ledger/gate/recorder-pre-commit.sh) — installed into a
#      throwaway .ledger-shaped repo via ledger/gate/install-recorder-hook.sh,
#      then exercised with real `git commit`:
#      (a) An invalid tech-debt record (missing a required field) is BLOCKED.
#      (b) An invalid process-feedback record (bad `kind`) is BLOCKED.
#      (c) Conformant tech-debt + process-feedback records PASS.
#      (d) A commit touching no record files PASSES (true no-op; nickel never
#          invoked — verified by a PATH with every nickel directory stripped).
#      (e) A record staged while `nickel` is NOT on PATH FAILS LOUDLY (does
#          not silently pass) — a gate that no-ops when its tool is missing
#          is not a gate.
#
#   1b. WHOLE-CORPUS log/ VALIDATION — log/ carries graded prose, not
#      pure-data YAML, so it cannot be validated per-record like tech-debt/
#      and process-feedback/ above: entry ids are document-qualified and
#      refs cross namespaces, so only the WHOLE .ledger corpus is a sound
#      validation scope (a staged file, or even log/ alone, produces
#      spurious dangling-edge findings for refs that resolve fine against
#      the full corpus). Wired via ledger/gate/entries_integrity.sh, already
#      built and tested for exactly this. Fixtures below reproduce the two
#      real defect classes that landed through this hole on 2026-08-24
#      (.ledger/log/2026-08-24-the-recorder-gate-skips-log.md [RG4],
#      corrected in .ledger commit 1cfeb5f) rather than inventing cases:
#      (L1) A bare `[ID]` in one document citing a marker declared in
#          ANOTHER document resolves against the CURRENT document (where it
#          does not exist) and dangles — BLOCKED.
#      (L2) The same citation, qualified with its document's stem
#          (`[stem:ID]`), resolves correctly — PASSES.
#      (L3) KNOWN GAP, not closed by this task: `derives-from:: K1, K2`
#          (unbracketed, comma-separated) parses as ONE external citation
#          literally named "K1, K2" — extract_entries.py's own documented
#          design treats un-bracketed residue text as external prose
#          ALWAYS, and nothing in entry.ncl validates an external ref's
#          name shape. This case is PINNED as currently-accepted (exit 0),
#          not asserted as caught — a green result here means the gap still
#          exists, not that it is fixed.
#      (L4) A commit BLOCKED by this validation unstages exactly the log/
#          file(s) it examined, leaving the working-tree copy untouched —
#          closing the trap named in
#          .ledger/process-feedback/pc-blocked-commit-leaves-index.yaml
#          (a refused commit does not refuse the `git add` that preceded
#          it, so an unstaged-on-block index cannot be swept into a later,
#          unrelated commit).
#
#   2. INIT/DEINIT WIRING (bootstrap/install.sh) — against a throwaway project:
#      (f) `init` installs the recorder hook as an untracked symlink resolving
#          to this plugin's recorder-pre-commit.sh.
#      (g) Re-running `init` twice leaves EXACTLY ONE pre-commit hook file
#          (idempotent — no duplicate hooks).
#      (h) `deinit` removes the recorder hook symlink and PRESERVES every byte
#          of .ledger's data and git history.
#      (i) A real (non-predicate) pre-existing recorder hook is never clobbered
#          by `deinit`.
#
# All git identity/signing config is set ONLY inside throwaway repos created by
# this script — never in this checkout, and never in a linked worktree of it.
#
# Usage: test_recorder_hook.sh
# Exit:  0 = all cases matched, 1 = a case mismatched, 2 = environment error.
set -u

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
recorder_gate="$here/recorder-pre-commit.sh"
recorder_installer="$here/install-recorder-hook.sh"
install_sh="$root/bootstrap/install.sh"

for f in "$recorder_gate" "$recorder_installer" "$install_sh"; do
  if [ ! -f "$f" ]; then
    echo "test_recorder_hook: ENVIRONMENT ERROR — missing $f" >&2
    exit 2
  fi
done

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

git_id=(-c user.name=test-recorder-hook -c user.email=test@recorder-hook -c commit.gpgsign=false)

# A throwaway .ledger-SHAPED repo: not created via bootstrap/install.sh, so
# the gate-unit level tests the gate script directly, independent of the
# init-wiring level below.
make_recorder_fixture() {
  local r; r="$(mktemp -d)"
  git "${git_id[@]}" -C "$r" init -q
  mkdir -p "$r/tech-debt" "$r/process-feedback" "$r/log"
  ( cd "$r" && bash "$recorder_installer" ) >/dev/null 2>&1
  printf '%s' "$r"
}

# PATH with every directory containing a `nickel` executable stripped —
# simulates nickel genuinely being absent, without touching the real PATH.
path_without_nickel() {
  local clean="" d
  local IFS=":"
  for d in $PATH; do
    [ -x "$d/nickel" ] && continue
    clean="$clean:$d"
  done
  printf '%s' "${clean#:}"
}

# ─── LEVEL 1: GATE UNIT ─────────────────────────────────────────────────────

echo "== recorder gate: invalid records are blocked =="

fx="$(make_recorder_fixture)"
cat > "$fx/tech-debt/bad.yaml" <<'EOF'
items:
  - id: bad-debt
    claim: "missing required fields on purpose"
    location: nowhere
    severity: low
    why_deferred: "testing the hole"
    signer: { kind: agent, name: test-recorder-hook }
    at: "deadbeef"
EOF
git "${git_id[@]}" -C "$fx" add tech-debt/bad.yaml
expect "(a) invalid tech-debt record (missing 'discharge') is BLOCKED" 1 \
  git "${git_id[@]}" -C "$fx" commit -m "feat: stage an invalid tech-debt record"
git "${git_id[@]}" -C "$fx" reset -q -- tech-debt/bad.yaml
rm -rf "$fx"

fx="$(make_recorder_fixture)"
cat > "$fx/process-feedback/bad.yaml" <<'EOF'
items:
  - id: bad-feedback
    kind: nonsense-kind
    context: "bad kind value on purpose"
    outcome: "should fail the Kind contract"
    signer: { kind: agent, name: test-recorder-hook }
    at: "deadbeef"
EOF
git "${git_id[@]}" -C "$fx" add process-feedback/bad.yaml
expect "(b) invalid process-feedback record (bad 'kind') is BLOCKED" 1 \
  git "${git_id[@]}" -C "$fx" commit -m "feat: stage an invalid process-feedback record"
rm -rf "$fx"

echo "== recorder gate: conformant records and no-op commits pass =="

fx="$(make_recorder_fixture)"
cat > "$fx/tech-debt/good.yaml" <<'EOF'
items:
  - id: good-debt
    claim: "a genuine, well-formed limitation"
    location: somewhere:1
    severity: low
    why_deferred: "deferred for a good reason"
    discharge: "resolved when the good reason no longer applies"
    signer: { kind: agent, name: test-recorder-hook }
    at: "deadbeef"
EOF
cat > "$fx/process-feedback/good.yaml" <<'EOF'
items:
  - id: good-feedback
    kind: improvement
    context: "a genuine improvement context"
    outcome: "a genuine improvement outcome"
    signer: { kind: agent, name: test-recorder-hook }
    at: "deadbeef"
EOF
git "${git_id[@]}" -C "$fx" add tech-debt/good.yaml process-feedback/good.yaml
expect "(c) conformant tech-debt + process-feedback records PASS" 0 \
  git "${git_id[@]}" -C "$fx" commit -m "feat: add conformant records"

printf 'a flight-log note\n' > "$fx/log/note.md"
git "${git_id[@]}" -C "$fx" add log/note.md
expect "(d) a commit touching no record files PASSES" 0 \
  git "${git_id[@]}" -C "$fx" commit -m "docs: add a flight-log note"
rm -rf "$fx"

echo "== recorder gate: nickel absent fails LOUDLY, never silently passes =="

fx="$(make_recorder_fixture)"
cat > "$fx/tech-debt/would-pass.yaml" <<'EOF'
items:
  - id: would-pass-debt
    claim: "conformant, but nickel will be unavailable"
    location: nowhere
    severity: low
    why_deferred: "testing the nickel-absent path"
    discharge: "n/a"
    signer: { kind: agent, name: test-recorder-hook }
    at: "deadbeef"
EOF
git "${git_id[@]}" -C "$fx" add tech-debt/would-pass.yaml
no_nickel_path="$(path_without_nickel)"
PATH="$no_nickel_path" git "${git_id[@]}" -C "$fx" commit -m "feat: stage a record while nickel is absent" \
  >/tmp/test_recorder_hook.nickel_absent_out.$$ 2>&1
nickel_absent_rc=$?
if [ "$nickel_absent_rc" -ne 0 ] \
   && grep -q "'nickel' not on PATH" /tmp/test_recorder_hook.nickel_absent_out.$$; then
  echo "PASS  ($nickel_absent_rc) (e) record staged with nickel absent FAILS LOUDLY (not silently)"
else
  echo "FAIL  (got rc=$nickel_absent_rc) (e) record staged with nickel absent must fail loudly, not silently pass"
  fails=$((fails + 1))
fi
rm -f /tmp/test_recorder_hook.nickel_absent_out.$$
rm -rf "$fx"

echo "== recorder gate: unattributed-designation ceiling =="
# The ceiling (recorder-pre-commit.sh: UNATTRIBUTED_CEILING, default 0,
# overridable via .ledger/config.sh) bounds SignerKind == 'unattributed'
# records across tech-debt/ + process-feedback/ COMBINED, counted over the
# whole recorder history — not just what a commit stages. A small ceiling (3)
# keeps these fixtures cheap; the mechanism is identical at any N, and the
# live recorder (ceiling 22) is checked separately below in the real repo.

# Writes N unattributed tech-debt items into $1, ids prefixed by $2.
write_unattributed_batch() {
  local file="$1" prefix="$2" n="$3" i
  { echo "items:"
    for ((i = 1; i <= n; i++)); do
      cat <<YAML
  - id: ${prefix}-${i}
    claim: "unattributed ceiling fixture record ${prefix}-${i}"
    location: nowhere:1
    severity: low
    why_deferred: "fixture"
    discharge: "fixture"
    signer:
      kind: unattributed
    at: "deadbeef"
YAML
    done
  } > "$file"
}

fx="$(make_recorder_fixture)"
echo "UNATTRIBUTED_CEILING=3" > "$fx/config.sh"
write_unattributed_batch "$fx/tech-debt/legacy-a.yaml" legacy-a 2
cat > "$fx/process-feedback/legacy-b.yaml" <<'EOF'
items:
  - id: legacy-b-1
    kind: improvement
    context: "unattributed ceiling fixture record legacy-b-1"
    outcome: "counts toward the ceiling from the process-feedback namespace"
    signer:
      kind: unattributed
    at: "deadbeef"
EOF
git "${git_id[@]}" -C "$fx" add tech-debt/legacy-a.yaml process-feedback/legacy-b.yaml
expect "(u1) unattributed total AT the ceiling (3, split across both namespaces) PASSES" 0 \
  git "${git_id[@]}" -C "$fx" commit -m "feat: seed unattributed records at the ceiling"

write_unattributed_batch "$fx/tech-debt/legacy-c.yaml" legacy-c 1
git "${git_id[@]}" -C "$fx" add tech-debt/legacy-c.yaml
expect "(u2) a record pushing the total OVER the ceiling (4 > 3) is BLOCKED" 1 \
  git "${git_id[@]}" -C "$fx" commit -m "feat: stage a record crossing the unattributed ceiling"
rm -rf "$fx"

fx="$(make_recorder_fixture)"
echo "UNATTRIBUTED_CEILING=3" > "$fx/config.sh"
write_unattributed_batch "$fx/tech-debt/few.yaml" few 1
git "${git_id[@]}" -C "$fx" add tech-debt/few.yaml
expect "(u3) fewer unattributed than the ceiling (1 < 3) PASSES" 0 \
  git "${git_id[@]}" -C "$fx" commit -m "feat: seed one unattributed record, below the ceiling"
rm -rf "$fx"

fx="$(make_recorder_fixture)"
# No config.sh — default ceiling (0) applies. Any number of REAL-signer
# records must still pass: the ceiling counts 'unattributed' only.
for n in 1 2 3 4 5; do
  cat >> "$fx/tech-debt/attributed-$n.yaml" <<EOF
items:
  - id: attributed-$n
    claim: "a real-signer record, ceiling-irrelevant"
    location: nowhere:1
    severity: low
    why_deferred: "fixture"
    discharge: "fixture"
    signer: { kind: agent, name: test-recorder-hook }
    at: "deadbeef"
EOF
  git "${git_id[@]}" -C "$fx" add "tech-debt/attributed-$n.yaml"
done
expect "(u4) any number of real-signer records PASSES under the default (0) ceiling" 0 \
  git "${git_id[@]}" -C "$fx" commit -m "feat: seed five attributed records"
rm -rf "$fx"

fx="$(make_recorder_fixture)"
echo "UNATTRIBUTED_CEILING=3" > "$fx/config.sh"
# README.md at the recorder root, NOT under any of the three routed
# namespaces (tech-debt/, process-feedback/, log/) — genuinely inert, unlike
# a log/ file, which is now itself a routed class (whole-corpus validation)
# and would require nickel+python3 regardless of the ceiling config.
printf '# fixture recorder\n' > "$fx/README.md"
git "${git_id[@]}" -C "$fx" add README.md
no_nickel_path="$(path_without_nickel)"
expect "(u5) a commit touching no records or log entries PASSES even with nickel absent (ceiling check never invoked)" 0 \
  env PATH="$no_nickel_path" git "${git_id[@]}" -C "$fx" commit -m "docs: a record-free commit under an active ceiling config"
rm -rf "$fx"

echo "== recorder gate: whole-corpus log/ validation (real 2026-08-24 specimens) =="

# (L1) A bare [Z1] cited from a SEPARATE document resolves against the
# CITING document's own namespace (where no Z1 exists) and dangles — the
# real defect class named in .ledger/log/2026-08-24-the-recorder-gate-
# skips-log.md [RG4]/[RG3] and fixed in .ledger commit 1cfeb5f.
fx="$(make_recorder_fixture)"
cat > "$fx/log/base.md" <<'EOF'
# base document

`signer:: agent/test-recorder-hook` · `at:: deadbeef`

`[Z1] grade::proved` **A base claim used by another document.** `check:: true`
EOF
cat > "$fx/log/citer.md" <<'EOF'
# citer document

`signer:: agent/test-recorder-hook` · `at:: deadbeef`

`[Z2] grade::synthesis` **Cites the base claim without qualifying the
document it lives in.** `derives-from:: [Z1]`
EOF
git "${git_id[@]}" -C "$fx" add log/base.md log/citer.md
expect "(L1) a bare cross-document [ID] ref dangles and is BLOCKED" 1 \
  git "${git_id[@]}" -C "$fx" commit -m "docs: stage a dangling cross-document reference"
git "${git_id[@]}" -C "$fx" reset -q -- log/base.md log/citer.md
rm -rf "$fx"

# (L2) The same citation, qualified with its document's stem, resolves and
# PASSES — the fix commit 1cfeb5f actually applied.
fx="$(make_recorder_fixture)"
cat > "$fx/log/base.md" <<'EOF'
# base document

`signer:: agent/test-recorder-hook` · `at:: deadbeef`

`[Z1] grade::proved` **A base claim used by another document.** `check:: true`
EOF
cat > "$fx/log/citer.md" <<'EOF'
# citer document

`signer:: agent/test-recorder-hook` · `at:: deadbeef`

`[Z2] grade::synthesis` **Cites the base claim, correctly qualified with the
document it lives in.** `derives-from:: [base:Z1]`
EOF
git "${git_id[@]}" -C "$fx" add log/base.md log/citer.md
expect "(L2) the same ref, qualified with its document stem, PASSES" 0 \
  git "${git_id[@]}" -C "$fx" commit -m "docs: stage a correctly qualified cross-document reference"
rm -rf "$fx"

# (L3) KNOWN GAP, not closed by this task — see the header comment above.
# `derives-from:: K1, K2` (no brackets) parses as ONE external citation
# literally named "K1, K2": extract_entries.py treats bracket-free residue
# text as external prose ALWAYS (its own documented design), and entry.ncl
# validates no external ref's name shape. This PINS current behavior
# (exit 0 — silently accepted) so a future fix flips this test, rather than
# claiming the gate catches a class it does not.
fx="$(make_recorder_fixture)"
cat > "$fx/log/comma.md" <<'EOF'
# comma document

`signer:: agent/test-recorder-hook` · `at:: deadbeef`

`[K1] grade::proved` **First claim.** `check:: true`

`[K2] grade::proved` **Second claim.** `check:: true`

`[K3] grade::synthesis` **Cites K1 and K2 but forgot the brackets.**
`derives-from:: K1, K2`
EOF
git "${git_id[@]}" -C "$fx" add log/comma.md
expect "(L3 — KNOWN GAP) unbracketed comma-separated derives-from is currently ACCEPTED, not rejected" 0 \
  git "${git_id[@]}" -C "$fx" commit -m "docs: stage an unbracketed comma-separated derives-from"
rm -rf "$fx"

# (L4) A commit BLOCKED by whole-corpus validation unstages exactly the
# log/ file(s) it examined — closing the trap named in
# .ledger/process-feedback/pc-blocked-commit-leaves-index.yaml (a refused
# commit does not refuse the `git add` that preceded it).
fx="$(make_recorder_fixture)"
cat > "$fx/log/citer.md" <<'EOF'
# citer document

`signer:: agent/test-recorder-hook` · `at:: deadbeef`

`[Z2] grade::synthesis` **Cites a marker that was never declared anywhere
in this corpus.** `derives-from:: [Z1]`
EOF
git "${git_id[@]}" -C "$fx" add log/citer.md
git "${git_id[@]}" -C "$fx" commit -m "docs: stage a dangling reference" >/dev/null 2>&1
commit_rc=$?
staged_after="$(git -C "$fx" diff --cached --name-only)"
if [ "$commit_rc" -ne 0 ]; then
  echo "PASS  ($commit_rc) (L4) the commit was actually blocked (precondition for the unstage check below)"
else
  echo "FAIL  (got 0, want non-zero) (L4) the commit was NOT blocked — the unstage check below would pass vacuously"
  fails=$((fails + 1))
fi
if [ -z "$staged_after" ]; then
  echo "PASS  (L4) a blocked commit unstages the refused log/ file"
else
  echo "FAIL  (L4) index still carries staged file(s) after a blocked commit: $staged_after"
  fails=$((fails + 1))
fi
if [ -f "$fx/log/citer.md" ] && grep -q "Cites a marker" "$fx/log/citer.md"; then
  echo "PASS  (L4) the working-tree copy of the refused file survives unstaging"
else
  echo "FAIL  (L4) the refused file's working-tree content was lost"
  fails=$((fails + 1))
fi
rm -rf "$fx"

# ─── LEVEL 2: INIT/DEINIT WIRING ─────────────────────────────────────────────

echo "== init: recorder hook wiring via bootstrap/install.sh =="

make_project() {
  local p; p="$(mktemp -d)"
  git "${git_id[@]}" -C "$p" init -q
  printf '%s' "$p"
}
run_init() {
  local proj="$1"
  PREDICATE_PLUGIN_SRC="$root" \
  PREDICATE_LEDGER_REMOTE="git@example.invalid:fixture/ledger.git" \
    bash "$install_sh" init --project "$proj"
}
run_deinit() {
  local proj="$1"
  PREDICATE_PLUGIN_SRC="$root" \
    bash "$install_sh" deinit --project "$proj"
}

proj="$(make_project)"
run_init "$proj" >/dev/null 2>&1

ledger="$proj/.ledger"
recorder_common="$(git -C "$ledger" rev-parse --git-common-dir 2>/dev/null)"
case "$recorder_common" in
  /*) : ;;
  *)  recorder_common="$ledger/$recorder_common" ;;
esac
recorder_hook="$recorder_common/hooks/pre-commit"

# (f) init installs the recorder hook as a symlink resolving to this plugin.
if [ -L "$recorder_hook" ]; then
  resolved="$(realpath "$recorder_hook" 2>/dev/null || true)"
  if [ "$resolved" = "$recorder_gate" ]; then
    echo "PASS  (f) init: recorder pre-commit hook is a symlink resolving to $recorder_gate"
  else
    echo "FAIL  (f) init: recorder pre-commit resolves to '$resolved' (want '$recorder_gate')"; fails=$((fails + 1))
  fi
else
  echo "FAIL  (f) init: recorder pre-commit hook is not a symlink"; fails=$((fails + 1))
fi

# (g) re-running init twice leaves exactly one pre-commit hook file.
run_init "$proj" >/dev/null 2>&1
run_init "$proj" >/dev/null 2>&1
hook_count="$(find "$recorder_common/hooks" -maxdepth 1 -name 'pre-commit' | wc -l)"
if [ "$hook_count" -eq 1 ]; then
  echo "PASS  (g) re-running init twice leaves exactly one pre-commit hook"
else
  echo "FAIL  (g) $hook_count pre-commit hook(s) found after re-running init twice (want 1)"; fails=$((fails + 1))
fi

# End-to-end: the wired hook actually blocks an invalid record, through the
# real init path (not the direct-installer fixture used at Level 1).
# init_ledger() only seeds log/ and state/ — tech-debt/ is created here the
# same way a walker recording its first debt entry would.
mkdir -p "$ledger/tech-debt"
cat > "$ledger/tech-debt/bad.yaml" <<'EOF'
items:
  - id: bad-debt-e2e
    claim: "missing required fields on purpose"
    location: nowhere
    severity: low
    why_deferred: "end-to-end proof through the real init path"
    signer: { kind: agent, name: test-recorder-hook }
    at: "deadbeef"
EOF
git "${git_id[@]}" -C "$ledger" add tech-debt/bad.yaml
expect "(f2) end-to-end: init-installed hook blocks an invalid record" 1 \
  git "${git_id[@]}" -C "$ledger" commit -m "feat: stage an invalid record (e2e)"
git "${git_id[@]}" -C "$ledger" reset -q -- tech-debt/bad.yaml 2>/dev/null
rm -f "$ledger/tech-debt/bad.yaml"

# (h) deinit removes the recorder hook and preserves .ledger data + history.
printf 'a preserved note\n' > "$ledger/log/keep.md"
git "${git_id[@]}" -C "$ledger" add log/keep.md
git "${git_id[@]}" -C "$ledger" commit -q -m "docs: a record to preserve through deinit"
ledger_log_before="$(git -C "$ledger" log --oneline)"

run_deinit "$proj" >/dev/null 2>&1

if [ -e "$recorder_hook" ] || [ -L "$recorder_hook" ]; then
  echo "FAIL  (h) deinit: recorder pre-commit hook still present"; fails=$((fails + 1))
else
  echo "PASS  (h) deinit: recorder pre-commit hook removed"
fi
if [ ! -f "$ledger/log/keep.md" ]; then
  echo "FAIL  (h) deinit: .ledger data (log/keep.md) was lost"; fails=$((fails + 1))
else
  echo "PASS  (h) deinit: .ledger data survives"
fi
ledger_log_after="$(git -C "$ledger" log --oneline 2>/dev/null)"
if [ "$ledger_log_before" = "$ledger_log_after" ]; then
  echo "PASS  (h) deinit: .ledger git history unchanged"
else
  echo "FAIL  (h) deinit: .ledger git history changed"; fails=$((fails + 1))
fi

rm -rf "$proj"

# (i) a real (non-predicate) pre-existing recorder hook is never clobbered.
proj="$(make_project)"
run_init "$proj" >/dev/null 2>&1
ledger="$proj/.ledger"
recorder_common="$(git -C "$ledger" rev-parse --git-common-dir 2>/dev/null)"
case "$recorder_common" in
  /*) : ;;
  *)  recorder_common="$ledger/$recorder_common" ;;
esac
real_hook="$recorder_common/hooks/pre-commit"
rm -f "$real_hook"
printf '#!/bin/sh\n# a real user-owned recorder hook\nexit 0\n' > "$real_hook"
chmod +x "$real_hook"

run_deinit "$proj" >/dev/null 2>&1

if [ -f "$real_hook" ] && grep -q "a real user-owned recorder hook" "$real_hook"; then
  echo "PASS  (i) deinit: a real user-owned recorder hook is NOT removed"
else
  echo "FAIL  (i) deinit: user-owned recorder hook was removed or altered"; fails=$((fails + 1))
fi
rm -rf "$proj"

# ─── Results ─────────────────────────────────────────────────────────────────
if [ "$fails" -ne 0 ]; then
  echo "FAIL: $fails recorder-hook case(s) mismatched"
  exit 1
fi
echo "PASS: all recorder-hook cases matched their expected exit codes"
exit 0
