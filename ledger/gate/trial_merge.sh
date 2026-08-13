#!/usr/bin/env bash
# Merge-gate: trial-merges a branch into a base ref inside a THROWAWAY clone
# and runs the FULL test_*.sh battery on the merged result — not on the
# branch alone, not on the base alone.
#
# The hole this closes (.ledger/log/2026-08-11-deferred-queue.md [D79]-[D81];
# deposits/provenance-gate/lead-maintainer-seat/gate.md [P5]-[P7]): every gate
# this project runs is scoped to one branch's own tree. Two branches can each
# be green and produce a red master when merged, with nothing predicting it —
# measured once: a branch removed a binding a DIFFERENT, already-merged branch
# called at two live sites. The branches touched disjoint files, so git merged
# them with no conflict, and open-surface's suite fell from 26 pass to 5 pass.
# Neither branch's own suite could see it. A trial merge with the full battery
# run ON THE RESULT would have caught it at zero cost — this script is that
# trial merge, meant to run BEFORE the real `git merge`, from wherever the
# composer or orchestrator already sits (its own clone step never touches the
# repo it is invoked from).
#
# Usage:
#   trial_merge.sh <branch-ref> [--against <base-ref>] [--repo <path>]
#                   [--timeout <seconds>] [--mem-limit-kb <kb>]
#
#   <branch-ref>     ref to trial-merge — a branch name or a SHA reachable
#                     from some ref in the target repo. Resolved in the clone
#                     via `origin/<ref>` first, then as a raw object.
#   --against REF    base to merge into (default: master)
#   --repo PATH      the repo to clone from (default: `git rev-parse
#                     --show-toplevel` of the invoking cwd — run this from
#                     inside the repo being gated unless you pass --repo)
#   --timeout N      per-test wall-clock bound in seconds (default: 180)
#   --mem-limit-kb N per-test `ulimit -v` bound in KB (default: 4194304 = 4GiB)
#
# Exit codes:
#   0  clean merge; the merged-tree battery has no cross-branch regression
#      (a test may still be failing if it already failed on the branch alone
#      — that is pre-existing, reported, and not what this gate blocks on)
#   1  clean merge, but at least one test the branch alone did NOT fail
#      (passed, or did not exist there) now fails on the merged tree — named
#   2  usage or environment error (bad ref, git failure with no conflict)
#   3  CONFLICT — <branch-ref> does not merge cleanly into <base-ref>. Kept
#      distinct from 1: nothing ran, there is no merged tree to test, and
#      collapsing this into "failure" would hide the more dangerous case (a
#      SILENT, conflict-free break) that this gate exists to catch.
#
# Repository safety: every git operation after the initial clone runs INSIDE
# a throwaway `git clone --no-hardlinks` copy in a private tmp dir, removed
# unconditionally on exit. Nothing here ever runs `git merge`, `git checkout`,
# or `git config` against the repo this script was invoked from — the clone
# step (a read) is the only contact with the real repository.
set -uo pipefail

branch_ref=""
base_ref="master"
repo=""
timeout_s=180
mem_limit_kb=4194304

usage() {
  echo "usage: trial_merge.sh <branch-ref> [--against <base-ref>] [--repo <path>] [--timeout <seconds>] [--mem-limit-kb <kb>]" >&2
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --against)      shift; base_ref="${1:-}" ;;
    --repo)         shift; repo="${1:-}" ;;
    --timeout)      shift; timeout_s="${1:-}" ;;
    --mem-limit-kb) shift; mem_limit_kb="${1:-}" ;;
    -h|--help)      usage; exit 2 ;;
    -*)             echo "trial_merge: unknown flag: $1" >&2; usage; exit 2 ;;
    *)
      if [ -n "$branch_ref" ]; then
        echo "trial_merge: unexpected extra argument: $1" >&2; usage; exit 2
      fi
      branch_ref="$1"
      ;;
  esac
  shift || true
done

if [ -z "$branch_ref" ]; then
  usage
  exit 2
fi

if [ -z "$repo" ]; then
  repo="$(git rev-parse --show-toplevel 2>/dev/null || true)"
fi
if [ -z "$repo" ] || { [ ! -d "$repo/.git" ] && [ ! -f "$repo/.git" ]; }; then
  echo "trial_merge: cannot resolve a repo (pass --repo, or run from inside one)" >&2
  exit 2
fi

command -v git >/dev/null 2>&1 || { echo "trial_merge: git not on PATH" >&2; exit 2; }
command -v timeout >/dev/null 2>&1 || { echo "trial_merge: timeout(1) not on PATH" >&2; exit 2; }

work_dir="$(mktemp -d)"
cleanup() { rm -rf "$work_dir"; }
trap cleanup EXIT

clone="$work_dir/clone"
# --no-hardlinks: a fully independent object store, not shared inodes with
# the real repo — belt-and-braces alongside "never git-mutate the real repo"
# above, since a hardlinked clone would still be a distinct working tree/index
# even without --no-hardlinks, but sharing objects on disk is not what
# "throwaway" is meant to promise a reader auditing this script.
if ! git clone --quiet --no-hardlinks "$repo" "$clone" >/dev/null 2>&1; then
  echo "trial_merge: failed to clone $repo into a throwaway dir" >&2
  exit 2
fi

resolve() {
  local ref="$1" sha
  sha="$(git -C "$clone" rev-parse --verify "refs/remotes/origin/$ref" 2>/dev/null)" && { echo "$sha"; return 0; }
  sha="$(git -C "$clone" rev-parse --verify "${ref}^{commit}" 2>/dev/null)" && { echo "$sha"; return 0; }
  return 1
}

branch_sha="$(resolve "$branch_ref")" || {
  echo "trial_merge: cannot resolve branch-ref '$branch_ref' in $repo" >&2
  exit 2
}
base_sha="$(resolve "$base_ref")" || {
  echo "trial_merge: cannot resolve base-ref '$base_ref' in $repo" >&2
  exit 2
}

echo "trial_merge: branch $branch_ref -> $branch_sha"
echo "trial_merge: base   $base_ref -> $base_sha"

# --- bounded test runner -----------------------------------------------------
# ulimit -v (virtual memory) + timeout -k (guaranteed kill) so one runaway
# suite cannot hang or OOM the invoking session — this project's own query
# layer OOM-killed sessions until recently. A bound hit is reported as its own
# class (TIMEOUT/KILLED), never silently folded into an ordinary FAIL, let
# alone treated as a pass.
run_test() {
  local script_rel="$1" dir="$2" log="$3" rc
  (
    cd "$dir" || exit 125
    ulimit -v "$mem_limit_kb" 2>/dev/null || true
    exec timeout -k 5 "$timeout_s" bash "$script_rel"
  ) >"$log" 2>&1
  rc=$?
  if [ "$rc" -eq 124 ]; then
    echo "TIMEOUT"
  elif [ "$rc" -eq 137 ]; then
    echo "KILLED(timeout-forced)"
  elif [ "$rc" -ge 128 ]; then
    echo "KILLED(rc=$rc, possible resource bound)"
  elif [ "$rc" -eq 0 ]; then
    echo "PASS"
  else
    echo "FAIL(rc=$rc)"
  fi
}

battery_in_tree() {
  git -C "$clone" ls-files -- 'ledger/gate/test_*.sh'
}

log_dir="$work_dir/logs"
mkdir -p "$log_dir"

# --- baseline: the branch alone, unmerged ------------------------------------
git -C "$clone" checkout --quiet -B trial-branch-alone "$branch_sha" || {
  echo "trial_merge: cannot check out branch-ref alone" >&2
  exit 2
}

declare -A alone_result=()
echo "--- battery on branch alone ($branch_ref) ---"
while IFS= read -r t; do
  [ -n "$t" ] || continue
  r="$(run_test "$t" "$clone" "$log_dir/alone-$(basename "$t").log")"
  alone_result["$t"]="$r"
  echo "  $r  $t"
done < <(battery_in_tree)

# --- the trial merge itself --------------------------------------------------
git -C "$clone" checkout --quiet -B trial-base "$base_sha" || {
  echo "trial_merge: cannot check out base-ref" >&2
  exit 2
}

merge_out="$(git -C "$clone" merge --no-commit --no-ff "$branch_sha" \
  -m "trial merge: $branch_ref into $base_ref (throwaway, never committed to the real repo)" 2>&1)"
merge_rc=$?

if [ "$merge_rc" -ne 0 ]; then
  conflicted="$(git -C "$clone" diff --name-only --diff-filter=U 2>/dev/null || true)"
  if [ -n "$conflicted" ]; then
    echo "--- CONFLICT: $branch_ref does not merge cleanly into $base_ref ---"
    echo "$conflicted" | sed 's/^/  conflict: /'
    git -C "$clone" merge --abort >/dev/null 2>&1 || true
    echo "VERDICT: CONFLICT (no merged tree produced — battery not run)"
    exit 3
  fi
  echo "--- merge failed with no conflicted paths (environment/git error) ---" >&2
  echo "$merge_out" >&2
  git -C "$clone" merge --abort >/dev/null 2>&1 || true
  exit 2
fi

echo "--- merge of $branch_ref into $base_ref: clean ---"

# --- battery on the merged result --------------------------------------------
# Enumerated from the MERGED tree, not the branch's or the base's alone — a
# battery member only the base carried is exactly the class of suite the
# incident this gate exists for went unrun by every per-branch gate.
declare -A merged_result=()
echo "--- battery on merged result ---"
regressions=()
preexisting=()
while IFS= read -r t; do
  [ -n "$t" ] || continue
  r="$(run_test "$t" "$clone" "$log_dir/merged-$(basename "$t").log")"
  merged_result["$t"]="$r"
  case "$r" in
    PASS)
      echo "  PASS  $t"
      ;;
    *)
      alone="${alone_result[$t]:-MISSING}"
      # Blocking iff the branch alone did NOT fail this: it either passed
      # there, or the test did not exist on the branch's own tree at all
      # (MISSING) — both cases are exactly "the branch alone did not fail
      # this." Anything else means the branch alone already failed/timed
      # out/was killed on it too — carried forward, not caused by the merge.
      if [ "$alone" = "MISSING" ] || [ "$alone" = "PASS" ]; then
        echo "  $r  $t  (REGRESSION: branch alone was '$alone' — merge broke this)"
        regressions+=("$t")
      else
        echo "  $r  $t  (pre-existing: branch alone also failed this — not a merge regression)"
        preexisting+=("$t")
      fi
      ;;
  esac
done < <(battery_in_tree)

echo "---"
echo "trial_merge: branch-alone battery: ${#alone_result[@]} test(s); merged battery: ${#merged_result[@]} test(s)"
if [ "${#preexisting[@]}" -gt 0 ]; then
  echo "trial_merge: ${#preexisting[@]} pre-existing failure(s) carried from the branch alone (not blocking):"
  printf '  - %s\n' "${preexisting[@]}"
fi

if [ "${#regressions[@]}" -gt 0 ]; then
  echo "VERDICT: FAIL — ${#regressions[@]} cross-branch regression(s) — the branch alone did not fail these:"
  printf '  - %s\n' "${regressions[@]}"
  echo "trial_merge: per-test logs were captured under a now-removed tmpdir;" >&2
  echo "trial_merge: re-run with the failing test's log printed below for diagnosis:" >&2
  for t in "${regressions[@]}"; do
    echo "===== $t (merged) =====" >&2
    cat "$log_dir/merged-$(basename "$t").log" >&2
  done
  exit 1
fi

echo "VERDICT: PASS — clean merge, no cross-branch regression in the merged-tree battery"
exit 0
