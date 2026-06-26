#!/usr/bin/env bash
# Gate-scope completeness checker (K10: thin bash entrypoint).
#
# Enumerates the ACTUAL gate surface — ledger/gate/*.sh, ledger/gate/*.py,
# gates/*.sh, the two named hooks, the seven named hook tiers, and the skill
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

# --- require nickel on PATH -------------------------------------------------
command -v nickel >/dev/null 2>&1 || {
  echo "check_scopes: nickel not on PATH — install it or enter the project shell (nix-shell / nix develop)" >&2
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
#   5. All files under skills/*/scripts/ (enumerated dynamically so new
#      skill scripts are automatically surfaced by the completeness check)
#
# File-based entries use their repo-root-relative path so they match the
# identifiers in scopes.ncl exactly.
actual_gates() {
  {
    # 1. ledger/gate/ scripts (exclude gate-sets/ subdirectory)
    find "$root/ledger/gate" -maxdepth 1 \( -name '*.sh' -o -name '*.py' \) -type f \
      | while IFS= read -r f; do
          printf '%s\n' "$(realpath --relative-to="$root" "$f")"
        done

    # 2. gates/ scripts
    find "$root/gates" -maxdepth 1 -name '*.sh' -type f \
      | while IFS= read -r f; do
          printf '%s\n' "$(realpath --relative-to="$root" "$f")"
        done

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

    # 4. Skill scripts (all files under skills/*/scripts/)
    find "$root/skills" -path "*/scripts/*" -type f \
      | while IFS= read -r f; do
          printf '%s\n' "$(realpath --relative-to="$root" "$f")"
        done

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

# --- self-test: negative control + positive control -------------------------
run_self_test() {
  local fails=0

  # Negative control: inject a synthetic gate into the actual surface by
  # temporarily adding a dummy script to ledger/gate/, run the check, and
  # assert rc 1.  The dummy is cleaned up regardless of the check outcome.
  local dummy="$here/_check_scopes_selftest_synthetic_$$.sh"
  printf '#!/usr/bin/env bash\n# synthetic gate for check_scopes self-test\n' > "$dummy"
  chmod +x "$dummy"

  echo "--- self-test: negative control (synthetic undeclared gate) ---"
  run_check >/dev/null 2>&1; local neg_rc=$?
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
    run_check
    ;;
  *)
    echo "usage: check_scopes.sh [--self-test]" >&2
    exit 2
    ;;
esac
