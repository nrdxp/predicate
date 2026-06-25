#!/usr/bin/env bash
# process-gate.sh — the PROCESS-gate tier (rules.md §3, third layer).
#
# This gate validates a staged procedure deposit (a /boundary or /refine
# YAML/NCL instance) against its upstream-pinned Nickel contract, enforcing
# spine ∘ discovery ∘ output. It is WALK-ACTIVATED: it fires only when the
# `.ledger/active-walk` pointer is present (written by the agent walk that
# declared its run-state). A human commit — which never writes the pointer —
# meets only the hygiene + structural layers; the process layer is invisible
# to them (K7).
#
# The gate-locus principle (architecture.md): pure validation logic is Nickel;
# this is the THIN SHELL SHIM that collects the effectful input (which files
# are staged, where is the pointer) and hands them to the Nickel contract for
# the decision. The contract is the authority; the shell only routes.
#
# Usage
# ─────
#   process-gate.sh validate <instance.yaml> <contract: boundary|refine>
#       Export-validate the deposit (YAML or bare NCL) against the named
#       contract via `nickel export --apply-contract`.
#       Exit 0 = pass; 1 = fail (skip/shrink/bad shape); 2 = env/usage error.
#
#   process-gate.sh register <contract: boundary|refine> <deposit-path> [pointer-path]
#       Write the active-walk pointer and print a teardown trap command to
#       STDOUT that the calling shell MUST eval:
#           eval "$(bash process-gate.sh register boundary .scratch/topic/deposit.ncl)"
#       The deposit-path (relative to the repo root) is REQUIRED and pinned at
#       register time — the gate validates ONLY that path, so a walk cannot later
#       dodge by renaming its deposit. The printed trap expression removes the
#       pointer on EXIT, HUP, INT, and TERM — ensuring abnormal-exit cannot leak
#       the pointer (A8/F3). The pointer path defaults to .ledger/active-walk in
#       the main git tree; an explicit path is used for testing.
#
#   process-gate.sh deregister [pointer-path]
#       Remove the active-walk pointer unconditionally (CLOSE teardown). Safe
#       to call even if the pointer was already removed.
#
# Pointer format
# ──────────────
# The pointer file is a TWO-LINE text file:
#   line 1: the contract class (boundary|refine)
#   line 2: the deposit-path (repo-root-relative path to the procedure deposit)
# Example:
#   boundary
#   .scratch/topic/boundary_deposit.ncl
#
# Walk wiring
# ───────────
# A walk that authors procedure deposits:
#   1. Calls `eval "$(bash process-gate.sh register <class> <deposit-path>)"` at
#      startup. This writes the two-line pointer (class + deposit-path) and
#      installs a teardown trap in the caller's shell. If the caller's shell exits
#      for any reason (including SIGKILL's parent reaping, ^C, or a crash), the
#      trap fires and removes the pointer.
#   2. Authors and stages the procedure deposit at the declared deposit-path.
#   3. The pre-commit hook sees the pointer, reads class and deposit-path, and
#      validates ONLY that deposit-path (iff it is staged) against the class
#      contract via `process-gate.sh validate`. Non-deposit .ncl files (contracts,
#      DAGs, fixtures) are never validated by the process gate.
#   4. At CLOSE, calls `bash process-gate.sh deregister` explicitly, then
#      removes the eval'd trap with `trap - EXIT HUP INT TERM`.
#
# Portability
# ───────────
# Nickel must be on PATH (provided by the project shell.nix, v1.14.0). The
# runner resolves `nickel` directly; no `nix run` fallback. If `nickel` is
# absent the gate exits 2 rather than silently passing (a gate that cannot run
# is not a gate that passes).
# Contract resolution: the apply-contract shims (*_apply.ncl) live under
# $plugin/ledger/contracts/ and import sibling contract files using relative
# imports.  Nickel resolves these relative to the shim file's directory, so no
# -I flag is needed — and NEVER pass a project-relative path, as downstream
# users have predicate installed elsewhere.
set -u

# Resolve the PLUGIN root from this script's own real path (symlink-safe).
# All sibling machinery is located relative to $plugin.
here="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" && pwd)"
plugin="$(cd "$here/../.." && pwd)"

# --- nickel runner -----------------------------------------------------------
# nickel must be on PATH (project shell.nix).  No nix-run fallback.
NICKEL=()
resolve_nickel() {
  if [ ${#NICKEL[@]} -gt 0 ]; then return 0; fi
  if command -v nickel >/dev/null 2>&1; then
    NICKEL=(nickel)
  else
    echo "process-gate: 'nickel' not found on PATH; cannot run gate" >&2
    exit 2
  fi
}

# --- contract class → apply-contract shim file --------------------------------
# Map a short contract class name to the ledger/contracts/*_apply.ncl shim that
# evaluates to the procedure contract.  These shim files are what Nickel receives
# as `--apply-contract`: they import the real contract file and project the single
# exported contract symbol, so the result is a contract value (not a record).
#
# Using absolute paths (resolved via $plugin) means Nickel resolves sibling
# imports from the shim file's own directory — no -I flag is required.
apply_contract_file_for() {
  local class="$1"
  case "$class" in
    boundary) echo "$plugin/ledger/contracts/boundary_apply.ncl" ;;
    refine)   echo "$plugin/ledger/contracts/refine_apply.ncl" ;;
    *)
      echo "process-gate: unknown contract class '$class' (must be 'boundary' or 'refine')" >&2
      return 2
      ;;
  esac
}

# --- validate <instance.yaml|ncl> <contract-class> ----------------------------
# Export-validate the procedure deposit against the named contract. The gate
# APPLIES the class contract externally via `--apply-contract` — the deposit
# cannot self-weaken by omitting a contract import or binding. Exit 0 = pass;
# 1 = fail (skip/shrink/bad shape); 2 = env/usage error.
#
# Validation strategy (gate-locus principle, D5): the deposit is pure-data
# (YAML or bare NCL record) with NO Nickel execution model embedded in it.
# `nickel export <deposit> --apply-contract <shim>` reads the deposit as Nickel
# values and then applies the class contract from the shim — entirely outside
# the deposit.  This closes two attack vectors by construction:
#   A-B1 (self-binding): a YAML deposit cannot import Nickel or apply contracts.
#   Import-DoS: a YAML deposit cannot execute arbitrary imports.
# A bare NCL dodge (steps=[]) is also caught: the contract is applied
# externally regardless of whether the deposit contains any binding.
#
# The apply-contract shim (*_apply.ncl) lives in ledger/contracts/ and imports
# its sibling contract file (boundary_procedure.ncl / refine_procedure.ncl)
# relative to its own directory, so no -I flag is needed when the shim is
# passed as an absolute path.
cmd_validate() {
  local instance="${1:-}" class="${2:-}"
  if [[ -z "$instance" || -z "$class" ]]; then
    echo "usage: process-gate.sh validate <instance.yaml> <contract: boundary|refine>" >&2
    exit 2
  fi
  if [[ ! -f "$instance" ]]; then
    echo "process-gate: no such instance: $instance" >&2
    exit 2
  fi

  # Resolve the apply-contract shim for the class; exit 2 on unknown class.
  local _apply_cf
  _apply_cf="$(apply_contract_file_for "$class")" || exit 2

  resolve_nickel

  # Resolve the deposit to an absolute path so nickel finds it regardless of
  # the caller's working directory.
  local abs_instance
  abs_instance="$(realpath "$instance")"

  local rc=0
  "${NICKEL[@]}" export "$abs_instance" \
    --apply-contract "$_apply_cf" >/dev/null || rc=$?
  return "$rc"
}

# --- register <contract-class> <deposit-path> [pointer-path] -----------------
# Write the active-walk pointer (two lines: class + deposit-path) and print a
# trap teardown expression to STDOUT. The caller MUST eval the output:
#   eval "$(bash process-gate.sh register boundary .scratch/topic/deposit.ncl)"
# This installs a trap in the caller's shell that removes the pointer on exit.
cmd_register() {
  local class="${1:-}" deposit_path="${2:-}" pointer="${3:-}"
  if [[ -z "$class" || -z "$deposit_path" ]]; then
    echo "usage: process-gate.sh register <contract: boundary|refine> <deposit-path> [pointer-path]" >&2
    exit 2
  fi

  # Validate the class name before writing anything.
  apply_contract_file_for "$class" >/dev/null || exit 2

  # Default pointer location: .ledger/active-walk in the MAIN git tree.
  # A linked worktree has no .ledger/ of its own — the pointer lives in the
  # main tree (mirrors the active-dag pointer placement in pre-commit).
  if [[ -z "$pointer" ]]; then
    local main_tree
    main_tree="$(cd "$(dirname "$(git rev-parse --git-common-dir 2>/dev/null)")" 2>/dev/null && pwd || echo ".")"
    pointer="$main_tree/.ledger/active-walk"
  fi

  # Create the .ledger directory if absent (a fresh checkout has none).
  local ledger_dir
  ledger_dir="$(dirname "$pointer")"
  mkdir -p "$ledger_dir"

  # Write the pointer: two lines — class (line 1) and deposit-path (line 2).
  # The deposit-path is pinned at register time so the gate validates exactly
  # the declared deposit; a walk cannot later dodge by renaming its deposit.
  printf '%s\n%s\n' "$class" "$deposit_path" > "$pointer"

  # Emit the teardown trap expression the caller eval's. The trap removes the
  # pointer on EXIT, HUP, INT, and TERM — covering normal exit, hangup,
  # Ctrl-C, and graceful kill. SIGKILL (9) is untrappable; the process
  # disappears, but the pointer remains. This is the documented residual risk
  # (F3/K7 from the campaign sketch): sequential-safe via teardown; SIGKILL is
  # named as a known surface, not a silent omission.
  #
  # The emitted expression uses single-quotes so the PATH variable ($pointer)
  # is expanded AT EVAL TIME (in the caller's shell, where $pointer is set),
  # not when the trap fires. We use a local var name to avoid collision.
  local escaped_pointer
  # shellcheck disable=SC2001
  escaped_pointer="$(printf '%s' "$pointer" | sed "s/'/'\\\\''/g")"
  printf "_pgate_walk_pointer='%s'\n" "$escaped_pointer"
  printf '_pgate_teardown() { rm -f "$_pgate_walk_pointer"; }\n'
  printf 'trap _pgate_teardown EXIT HUP INT TERM\n'
}

# --- deregister [pointer-path] -----------------------------------------------
# Remove the active-walk pointer unconditionally. Safe if already absent.
cmd_deregister() {
  local pointer="${1:-}"
  if [[ -z "$pointer" ]]; then
    local main_tree
    main_tree="$(cd "$(dirname "$(git rev-parse --git-common-dir 2>/dev/null)")" 2>/dev/null && pwd || echo ".")"
    pointer="$main_tree/.ledger/active-walk"
  fi
  rm -f "$pointer"
}

# --- main --------------------------------------------------------------------
main() {
  local sub="${1:-}"
  shift || true
  case "$sub" in
    validate)    cmd_validate "$@" ;;
    register)    cmd_register "$@" ;;
    deregister)  cmd_deregister "$@" ;;
    *)
      echo "usage: process-gate.sh {validate|register|deregister} ..." >&2
      exit 2
      ;;
  esac
}

main "$@"
