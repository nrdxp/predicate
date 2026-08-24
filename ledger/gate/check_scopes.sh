#!/usr/bin/env bash
# Gate-scope completeness checker (K10: thin bash entrypoint).
#
# Enumerates the ACTUAL gate surface — ledger/gate/*.sh, ledger/gate/*.py,
# gates/*.sh, the two named hooks, the nine named hook tiers, and the skill
# scripts invoked from hooks — then verifies that every gate is declared in
# ledger/gate/scopes.ncl.  Fails (rc 1) if any gate is absent; passes (rc 0)
# if every gate is declared.
#
# Usage:  check_scopes.sh [--self-test]
#
#   (no args)    normal mode: enumerate gates and check against scopes.ncl
#   --self-test  inject a synthetic undeclared gate and assert rc 1; then
#                run the normal check and assert rc 0.  Exit 0 iff both
#                assertions hold (the negative then positive control).
#
# Exit codes:
#   0 = every gate declared in scopes.ncl
#   1 = one or more undeclared gates (names printed to stderr)
#   2 = environment error (nickel/nix unavailable, scopes.ncl unreadable)
set -u

here="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" && pwd)"
root="$(cd "$here/../.." && pwd)"
scopes="$here/scopes.ncl"

# --- require nickel and git on PATH -----------------------------------------
command -v nickel >/dev/null 2>&1 || {
  echo "check_scopes: nickel not on PATH — install it or enter the project shell (nix-shell / nix develop)" >&2
  exit 2
}
command -v git >/dev/null 2>&1 || {
  echo "check_scopes: git not on PATH — the gate surface enumerates via git ls-files" >&2
  exit 2
}

# --- extract declared gate names from scopes.ncl via nickel export ----------
declared_gates() {
  if [[ ! -f "$scopes" ]]; then
    echo "check_scopes: scopes.ncl not found at $scopes" >&2
    exit 2
  fi
  nickel export "$scopes" 2>/dev/null \
    | python3 -c '
import json, sys
data = json.load(sys.stdin)
for entry in data.get("gates", []):
    print(entry["gate"])
' | LC_ALL=C sort
}

# --- enumerate the actual gate surface --------------------------------------
# The gate surface is:
#   1. All *.sh and *.py files in ledger/gate/  (excl. gate-sets/ subdir)
#   2. All *.sh files in gates/
#   3. The two hook scripts (hooks/commit-msg, hooks/pre-commit)
#   4. The named hook tiers (logical identifiers, not file paths):
#        hook/commit-msg:hygiene
#        hook/commit-msg:selfcontained
#        hook/pre-commit:orphans
#        hook/pre-commit:doc-links
#        hook/pre-commit:ledger-structure
#        hook/pre-commit:authority
#        hook/pre-commit:process
#        hook/pre-commit:project-local
#   5. All *.sh and *.py files under skills/*/scripts/ (enumerated
#      dynamically so new skill scripts are automatically surfaced by the
#      completeness check; extension-filtered like sections 1-2 so a build
#      artifact is never counted as a gate)
#
# Sections 1, 2, and 5 enumerate via `git ls-files`, not a filesystem walk
# (ledger note .ledger/log/2026-08-11-deferred-queue.md [D22]): walking the
# working tree makes the count depend on what happens to sit on disk in this
# checkout — a git-ignored __pycache__/*.pyc left by running a Python gate
# once raised the undeclared count by one, so CI's colour depended on whether
# anyone had run a gate in that checkout. `git ls-files` is this project's own
# establish-universe mechanism (the always-on law names it for exactly this
# reason), so the gate surface tracks what the repository actually contains,
# not what a given working tree happens to have accumulated. This also closes
# an untracked *.sh/*.py dropped into any of the three directories — not just
# a non-script build artifact, which an extension filter alone does not.
#
# File-based entries use their repo-root-relative path (git ls-files' native
# output, run from $root) so they match the identifiers in scopes.ncl exactly.
actual_gates() {
  {
    # 1. ledger/gate/ scripts (git pathspec glob `*` does not cross `/`, so
    #    this excludes the gate-sets/ subdirectory the same way -maxdepth 1 did)
    git -C "$root" ls-files -- 'ledger/gate/*.sh' 'ledger/gate/*.py'

    # 2. gates/ scripts
    git -C "$root" ls-files -- 'gates/*.sh'

    # 3. Hook tiers — logical identifiers declared in scopes.ncl
    printf '%s\n' \
      "hook/commit-msg:hygiene" \
      "hook/commit-msg:selfcontained" \
      "hook/pre-commit:orphans" \
      "hook/pre-commit:doc-links" \
      "hook/pre-commit:ledger-structure" \
      "hook/pre-commit:authority" \
      "hook/pre-commit:process" \
      "hook/pre-commit:project-local"

    # 4. Skill scripts (*.sh and *.py files under skills/*/scripts/, any depth
    #    via glob pathspec magic — same reach as the prior `-path "*/scripts/*"`)
    git -C "$root" ls-files -- ':(glob)skills/*/scripts/**/*.sh' ':(glob)skills/*/scripts/**/*.py'

  } | LC_ALL=C sort -u
}

# --- main check: every actual gate must appear in the declared set -----------
run_check() {
  local decl_file actual_file missing
  decl_file="$(mktemp)"
  actual_file="$(mktemp)"
  declared_gates > "$decl_file"
  actual_gates   > "$actual_file"

  # comm -23: lines in actual NOT in declared (the undeclared gates)
  missing="$(LC_ALL=C comm -23 "$actual_file" "$decl_file")"
  rm -f "$decl_file" "$actual_file"

  if [[ -n "$missing" ]]; then
    echo "check_scopes: FAIL — undeclared gate(s) found:" >&2
    printf '%s\n' "$missing" | sed 's/^/  missing: /' >&2
    echo "  Add a declaration to ledger/gate/scopes.ncl for each missing gate." >&2
    return 1
  fi
  echo "check_scopes: PASS — every gate is declared in scopes.ncl"
  return 0
}

# --- meta-check: every CI-declared gate must be wired in ci.yml -------------
# Gates in scopes.ncl whose fires_when STARTS WITH "CI" are declared as
# direct CI-step gates (the string "CI" as the leading token marks them as
# CI-primary, rather than gates that mention CI incidentally as a secondary
# context).  If such a gate's script name does not appear in
# .github/workflows/ci.yml, the "declared-but-unwired" class has silently
# accreted — this check closes it generally rather than chasing each instance.
run_ci_coverage_check() {
  local ci_yml="$root/.github/workflows/ci.yml"
  if [[ ! -f "$ci_yml" ]]; then
    echo "check_scopes: .github/workflows/ci.yml not found at $ci_yml — skipping CI coverage check" >&2
    return 0
  fi

  local missing=0
  while IFS=$'\t' read -r gate fires_when; do
    # Hook tiers (hook/commit-msg:* and hook/pre-commit:*) are logical
    # identifiers, not directly invocable scripts; skip them.
    case "$gate" in
      hook/*) continue ;;
    esac
    local bname="${gate##*/}"
    if ! grep -qF "$bname" "$ci_yml"; then
      echo "check_scopes: CI-UNWIRED: $gate" >&2
      printf '  fires_when: %s\n' "$fires_when" >&2
      printf "  '%s' is not referenced in .github/workflows/ci.yml\n" "$bname" >&2
      echo "  Add it to the relevant step in .github/workflows/ci.yml." >&2
      missing=$((missing + 1))
    fi
  done < <(
    nickel export "$scopes" 2>/dev/null \
      | python3 -c '
import json, sys
data = json.load(sys.stdin)
for entry in data.get("gates", []):
    fw = entry.get("fires_when", "")
    if fw.startswith("CI"):
        print(entry["gate"] + "\t" + fw)
'
  )

  if [[ "$missing" -gt 0 ]]; then
    printf 'check_scopes: CI-COVERAGE FAIL — %d gate(s) declared for CI but absent from ci.yml\n' \
      "$missing" >&2
    return 1
  fi
  echo "check_scopes: CI-COVERAGE PASS — every CI-declared gate is wired in ci.yml"
  return 0
}

# --- self-test: negative control + positive control -------------------------
run_self_test() {
  local fails=0

  # Negative control: inject a synthetic gate into the actual surface by
  # temporarily staging a dummy script under ledger/gate/, run the check, and
  # assert rc 1.  actual_gates() now enumerates via `git ls-files` (tracked
  # file list, not a filesystem walk — see the enumerator's own comment), so
  # the dummy must be STAGED, not merely written to disk, or the negative
  # control would exercise a code path the gate no longer takes. Staged is
  # sufficient — `git ls-files` reports the index, not only HEAD — so no
  # commit is made. Both the stage and the file are cleaned up regardless of
  # the check outcome.
  local dummy="$here/_check_scopes_selftest_synthetic_$$.sh"
  printf '#!/usr/bin/env bash\n# synthetic gate for check_scopes self-test\n' > "$dummy"
  chmod +x "$dummy"
  git -C "$root" add -- "$dummy"

  echo "--- self-test: negative control (synthetic undeclared gate) ---"
  run_check >/dev/null 2>&1; local neg_rc=$?
  git -C "$root" reset -q -- "$dummy" >/dev/null 2>&1
  rm -f "$dummy"

  if [[ "$neg_rc" -eq 1 ]]; then
    echo "PASS  negative control: check_scopes correctly detected undeclared gate (rc 1)"
  else
    echo "FAIL  negative control: check_scopes returned rc=$neg_rc (expected 1)" >&2
    fails=$((fails + 1))
  fi

  # Positive control: no dummy present, normal check must pass.
  echo "--- self-test: positive control (complete manifest) ---"
  run_check; local pos_rc=$?
  if [[ "$pos_rc" -eq 0 ]]; then
    echo "PASS  positive control: check_scopes passed with complete manifest (rc 0)"
  else
    echo "FAIL  positive control: check_scopes returned rc=$pos_rc (expected 0)" >&2
    fails=$((fails + 1))
  fi

  if [[ "$fails" -ne 0 ]]; then
    echo "FAIL: $fails self-test case(s) mismatched" >&2
    return 1
  fi
  echo "PASS: self-test complete — completeness checker behaves as specified"
  return 0
}

# --- dispatch ----------------------------------------------------------------
case "${1:-}" in
  --self-test)
    run_self_test
    ;;
  "")
    overall_rc=0
    run_check         || overall_rc=1
    run_ci_coverage_check || overall_rc=1
    exit "$overall_rc"
    ;;
  *)
    echo "usage: check_scopes.sh [--self-test]" >&2
    exit 2
    ;;
esac
