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
#   2. INIT WIRING — self-host-vs-consumer split:
#
#      Consumer project (project ≠ plugin_src):
#        (A)  init installs NO predicate-specific gates — a downstream project
#             with a legitimate state_machine.ncl must not false-fire.
#        (A2) Corollary: a consumer project with a state_machine.ncl in its own
#             ledger/contracts/ does not trigger any predicate-gate (gate absent).
#
#      Self-host (project == plugin_src — predicate gating itself):
#        (B1) init installs the colocation gate, present and executable.
#        (B2) Installed gate fires on re-centralization (end-to-end assertion).
#        (B3) Idempotent: re-init skips-if-exists, never clobbers the gate.
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
git_id=(-c user.name=test-colocation-gate -c user.email=test@colocation-gate -c commit.gpgsign=false)

# Track the original state of $root/.ledger/ so we can restore it on exit.
# The self-host init test runs `init --project "$root"`, which calls both
# init_ledger (creates log/, state/, config.sh.example) and install_selfhost_gates
# (creates .ledger/gates/). We must undo all of that on exit.
selfhost_ledger_dir="$root/.ledger"
selfhost_gates_dir="$selfhost_ledger_dir/gates"
selfhost_gate="$selfhost_gates_dir/10-skill-contract-colocation.sh"
selfhost_ledger_existed=0
selfhost_gates_dir_existed=0
selfhost_gate_existed=0
selfhost_gate_content=""
[ -d "$selfhost_ledger_dir" ] && selfhost_ledger_existed=1
if [ -d "$selfhost_gates_dir" ]; then
  selfhost_gates_dir_existed=1
  if [ -f "$selfhost_gate" ]; then
    selfhost_gate_existed=1
    selfhost_gate_content="$(cat "$selfhost_gate")"
  fi
fi

cleanup() {
  rm -rf "$scratch"
  # Restore the original state of $root/.ledger/:
  #   - .ledger/ did not exist before → remove it entirely (init created it).
  #   - .ledger/ existed, .ledger/gates/ did not → remove gates dir + gate file.
  #   - .ledger/gates/ existed, gate file did not → remove only the gate file.
  #   - Gate file existed → restore its original content in place.
  if [ "$selfhost_ledger_existed" -eq 0 ]; then
    rm -rf "$selfhost_ledger_dir"
  elif [ "$selfhost_gates_dir_existed" -eq 0 ]; then
    rm -rf "$selfhost_gates_dir"
  elif [ "$selfhost_gate_existed" -eq 0 ]; then
    rm -f "$selfhost_gate"
  else
    printf '%s' "$selfhost_gate_content" > "$selfhost_gate"
    chmod +x "$selfhost_gate"
  fi
}
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

# ─── LEVEL 2: INIT WIRING — SELF-HOST VS CONSUMER ───────────────────────────
#
# The colocation gate is PREDICATE's own project-local gate. It checks
# predicate-internal invariants (skill-contract colocation) that are
# meaningless — and would false-fire — in any downstream project.
#
# Correct wiring:
#   consumer init (project ≠ plugin_src)  → NO predicate-specific gates
#   self-host init (project == plugin_src) → colocation gate installed

echo "== init wiring: consumer init installs NO predicate-specific gates =="

# (A) Consumer project: init → NO colocation gate installed.
#     A downstream project with its own state_machine.ncl must not false-fire.
consumer_dir="$scratch/consumer_project"
mkdir -p "$consumer_dir"
git "${git_id[@]}" -C "$consumer_dir" init -q

PREDICATE_PLUGIN_SRC="$root" \
PREDICATE_LEDGER_REMOTE="git@example.invalid:fixture/ledger.git" \
  bash "$install_sh" init --project "$consumer_dir" >/dev/null 2>&1

consumer_gate="$consumer_dir/.ledger/gates/10-skill-contract-colocation.sh"

if [ ! -f "$consumer_gate" ]; then
  echo "PASS  (A) consumer init: no predicate-specific gate installed in consumer project"
else
  echo "FAIL  (A) consumer init: predicate colocation gate was wrongly installed in consumer project"; fails=$((fails + 1))
fi

# (A2) Corollary: a consumer project with a legitimate state_machine.ncl in its
#      own ledger/contracts/ must not false-fire. Since the gate is absent,
#      no false-fire can occur. Demonstrate both absence and lack of fire.
mkdir -p "$consumer_dir/ledger/contracts"
printf '# consumer-owned state machine\n{}' \
  > "$consumer_dir/ledger/contracts/state_machine.ncl"

if [ ! -f "$consumer_gate" ]; then
  echo "PASS  (A2) consumer with state_machine.ncl: gate absent, no false-fire possible"
else
  # Gate is wrongly present — show that it WOULD false-fire (both are failures).
  bash "$consumer_gate" "$consumer_dir" >/dev/null 2>&1 \
    && note_rc=0 || note_rc=$?
  if [ "$note_rc" -ne 0 ]; then
    echo "FAIL  (A2) colocation gate wrongly installed in consumer AND fires on legitimate contract"; fails=$((fails + 1))
  else
    echo "FAIL  (A2) colocation gate wrongly installed in consumer (but happens not to fire)"; fails=$((fails + 1))
  fi
fi
rm -f "$consumer_dir/ledger/contracts/state_machine.ncl"

echo "== init wiring: self-host init (predicate itself) installs colocation gate =="

# Self-host: init where project == plugin_src (predicate gating itself).
# We run init --project "$root" with PREDICATE_PLUGIN_SRC="$root".
# The cleanup trap restores the gate to its original state after the test.
PREDICATE_PLUGIN_SRC="$root" \
PREDICATE_LEDGER_REMOTE="git@example.invalid:fixture/ledger.git" \
  bash "$install_sh" init --project "$root" >/dev/null 2>&1

# (B1) Gate present and executable after self-host init.
if [ -f "$selfhost_gate" ] && [ -x "$selfhost_gate" ]; then
  echo "PASS  (B1) self-host init: colocation gate installed and executable"
else
  echo "FAIL  (B1) self-host init: gate not installed or not executable at $selfhost_gate"; fails=$((fails + 1))
fi

# (B2) Installed gate fires on re-centralization (end-to-end TDD assertion).
# Use a throwaway tree that simulates a predicate checkout with a re-centralized contract.
recentral_dir="$scratch/recentralized"
mkdir -p "$recentral_dir/ledger/contracts"
printf '# re-centralized skill-owned contract\n{}' \
  > "$recentral_dir/ledger/contracts/boundary_procedure.ncl"
if [ -f "$selfhost_gate" ]; then
  expect "(B2) installed self-host gate fires on re-centralization → rc 1" 1 \
    bash "$selfhost_gate" "$recentral_dir"
fi

# (B3) Idempotent: re-init does not clobber the installed gate.
if [ -f "$selfhost_gate" ]; then
  printf '# user-modified self-host gate — must NOT be clobbered by re-init\n' > "$selfhost_gate"
  PREDICATE_PLUGIN_SRC="$root" \
  PREDICATE_LEDGER_REMOTE="git@example.invalid:fixture/ledger.git" \
    bash "$install_sh" init --project "$root" >/dev/null 2>&1
  if grep -qF 'user-modified self-host gate' "$selfhost_gate"; then
    echo "PASS  (B3) self-host re-init: skipped existing gate (idempotent, non-clobbering)"
  else
    echo "FAIL  (B3) self-host re-init: overwrote the existing gate (must skip-if-exists)"; fails=$((fails + 1))
  fi
  # Restore the real gate for any subsequent assertions.
  cp "$gate_template" "$selfhost_gate"
  chmod +x "$selfhost_gate"
fi

# ─── Results ─────────────────────────────────────────────────────────────────
if [ "$fails" -ne 0 ]; then
  echo "FAIL: $fails colocation-gate case(s) mismatched"
  exit 1
fi
echo "PASS: all colocation-gate cases matched their expected exit codes"
exit 0
