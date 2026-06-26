#!/usr/bin/env bash
# test_colocation_gate.sh — TDD for the colocation gate template and init wiring.
#
# Coverage (two levels):
#
#   1. GATE UNIT (templates/project-gates/10-skill-contract-colocation.sh) —
#      direct invocation against fixture project trees, no git state required:
#      (a) No ledger/contracts/ directory → gate passes (rc 0).
#      (b) ledger/contracts/ exists but none of the 5 names present → rc 0.
#      (c) One skill-owned name present in ledger/contracts/ → rc 1 (FIRES).
#      (d) All five skill-owned names present → rc 1 (FIRES, all reported).
#      (e) A contract with a name that is NOT one of the five → rc 0 (not fired).
#
#   2. INIT WIRING (bootstrap/install.sh init) — demonstrates that a fresh
#      `init` against a real git repo installs the colocation gate into
#      .ledger/gates/ and that the installed gate is:
#      (A) Present and executable after init.
#      (B) Idempotent: a second init skips-if-exists without clobbering.
#      (C) Fires on re-centralization (end-to-end TDD assertion).
#      (D) Passes when no skill-owned contract is present.
#
# All scratch state is torn down via EXIT trap.
#
# Usage: test_colocation_gate.sh
# Exit:  0 = all cases matched, 1 = a case mismatched, 2 = environment error.
set -u

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
gate_template="$root/templates/project-gates/10-skill-contract-colocation.sh"
install_sh="$root/bootstrap/install.sh"

# --- sanity checks -----------------------------------------------------------
if [ ! -f "$gate_template" ]; then
  echo "test_colocation_gate: ENVIRONMENT ERROR — gate template not found: $gate_template" >&2
  exit 2
fi
if [ ! -f "$install_sh" ]; then
  echo "test_colocation_gate: ENVIRONMENT ERROR — install.sh not found: $install_sh" >&2
  exit 2
fi

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

# Scratch dir: all throwaway state lives here, torn down on exit.
scratch="$(mktemp -d)"
cleanup() { rm -rf "$scratch"; }
trap cleanup EXIT

# ─── LEVEL 1: GATE UNIT ─────────────────────────────────────────────────────

echo "== colocation gate: pass cases =="

# (a) No ledger/contracts/ directory → gate passes.
no_contracts_dir="$scratch/no_contracts"
mkdir -p "$no_contracts_dir"
expect "no ledger/contracts/ dir → rc 0 (pass)" 0 \
  bash "$gate_template" "$no_contracts_dir"

# (b) ledger/contracts/ exists but none of the 5 names present → rc 0.
unrelated_dir="$scratch/unrelated"
mkdir -p "$unrelated_dir/ledger/contracts"
printf '# unrelated contract\n{}' > "$unrelated_dir/ledger/contracts/dag.ncl"
expect "unrelated contract in ledger/contracts/ → rc 0 (pass)" 0 \
  bash "$gate_template" "$unrelated_dir"

# (e) A contract named similarly but not one of the five → rc 0.
lookalike_dir="$scratch/lookalike"
mkdir -p "$lookalike_dir/ledger/contracts"
printf '# lookalike — not one of the five\n{}' > "$lookalike_dir/ledger/contracts/refine_apply.ncl"
expect "lookalike name not in the five → rc 0 (pass)" 0 \
  bash "$gate_template" "$lookalike_dir"

echo "== colocation gate: fire cases =="

# The five skill-owned names that must NOT appear in ledger/contracts/.
skill_owned_names=(
  boundary_procedure.ncl
  refine_procedure.ncl
  refine_output.ncl
  state_machine.ncl
  tracker_freshness.ncl
)

# (c) One skill-owned name present → gate fires (rc 1).
for name in "${skill_owned_names[@]}"; do
  one_dir="$scratch/one_$name"
  mkdir -p "$one_dir/ledger/contracts"
  printf '# skill-owned contract re-centralized\n{}' > "$one_dir/ledger/contracts/$name"
  expect "$name in ledger/contracts/ → rc 1 (FIRES)" 1 \
    bash "$gate_template" "$one_dir"
done

# (d) All five present → gate fires.
all_dir="$scratch/all_five"
mkdir -p "$all_dir/ledger/contracts"
for name in "${skill_owned_names[@]}"; do
  printf '# skill-owned contract re-centralized\n{}' > "$all_dir/ledger/contracts/$name"
done
expect "all five skill-owned names in ledger/contracts/ → rc 1 (FIRES)" 1 \
  bash "$gate_template" "$all_dir"

# ─── LEVEL 2: INIT WIRING ───────────────────────────────────────────────────

echo "== init wiring: bootstrap/install.sh init installs the colocation gate =="

proj_dir="$scratch/init_project"
mkdir -p "$proj_dir"
git_id=(-c user.name=test-colocation-gate -c user.email=test@colocation-gate -c commit.gpgsign=false)
git "${git_id[@]}" -C "$proj_dir" init -q

# Run init against the throwaway project.
PREDICATE_PLUGIN_SRC="$root" \
PREDICATE_LEDGER_REMOTE="git@example.invalid:fixture/ledger.git" \
  bash "$install_sh" init --project "$proj_dir" >/dev/null 2>&1

installed_gate="$proj_dir/.ledger/gates/10-skill-contract-colocation.sh"

# (A) Gate present and executable after init.
if [ -f "$installed_gate" ] && [ -x "$installed_gate" ]; then
  echo "PASS  (A) gate present and executable after init"
else
  echo "FAIL  (A) gate not installed or not executable at $installed_gate"; fails=$((fails + 1))
fi

# (B) Idempotent: sentinel line in installed gate; overwrite it; re-run init;
#     verify the user's version is preserved (skip-if-exists in action).
if [ -f "$installed_gate" ]; then
  printf '# user-modified gate — must NOT be clobbered by re-init\n' > "$installed_gate"
  PREDICATE_PLUGIN_SRC="$root" \
  PREDICATE_LEDGER_REMOTE="git@example.invalid:fixture/ledger.git" \
    bash "$install_sh" init --project "$proj_dir" >/dev/null 2>&1
  if grep -qF 'user-modified gate' "$installed_gate"; then
    echo "PASS  (B) re-init skipped existing gate (idempotent, non-clobbering)"
  else
    echo "FAIL  (B) re-init overwrote the user's gate (must skip-if-exists)"; fails=$((fails + 1))
  fi
  # Restore the real gate for the firing tests.
  cp "$gate_template" "$installed_gate"
  chmod +x "$installed_gate"
fi

# (C) Installed gate fires when a skill-owned contract is re-centralized.
mkdir -p "$proj_dir/ledger/contracts"
printf '# re-centralized skill-owned contract\n{}' \
  > "$proj_dir/ledger/contracts/boundary_procedure.ncl"
expect "(C) installed gate fires on re-centralization → rc 1" 1 \
  bash "$installed_gate" "$proj_dir"

# (D) Installed gate passes when no skill-owned contracts are present.
rm -f "$proj_dir/ledger/contracts/boundary_procedure.ncl"
expect "(D) installed gate passes with no re-centralized contracts → rc 0" 0 \
  bash "$installed_gate" "$proj_dir"

# ─── Results ─────────────────────────────────────────────────────────────────
if [ "$fails" -ne 0 ]; then
  echo "FAIL: $fails colocation-gate case(s) mismatched"
  exit 1
fi
echo "PASS: all colocation-gate cases matched their expected exit codes"
exit 0
