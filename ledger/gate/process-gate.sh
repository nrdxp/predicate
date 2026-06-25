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
#   process-gate.sh validate <instance.ncl> <contract: boundary|refine>
#       Export-validate the instance against the named contract.
#       Exit 0 = pass; 1 = fail (skip/shrink/bad shape); 2 = env/usage error.
#
#   process-gate.sh register <contract: boundary|refine> [pointer-path]
#       Write the active-walk pointer and print a teardown trap command to
#       STDOUT that the calling shell MUST eval:
#           eval "$(bash process-gate.sh register boundary)"
#       The printed trap expression removes the pointer on EXIT, HUP, INT, and
#       TERM — ensuring abnormal-exit cannot leak the pointer (A8/F3). The
#       pointer path defaults to .ledger/active-walk in the main git tree; an
#       explicit path is used for testing.
#
#   process-gate.sh deregister [pointer-path]
#       Remove the active-walk pointer unconditionally (CLOSE teardown). Safe
#       to call even if the pointer was already removed.
#
# Pointer format
# ──────────────
# The pointer file is a one-line text file whose content is the contract class:
#   boundary   → validate against ledger/contracts/boundary_procedure.ncl
#   refine     → validate against ledger/contracts/refine_procedure.ncl
#
# Walk wiring
# ───────────
# A walk that authors procedure deposits:
#   1. Calls `eval "$(bash process-gate.sh register <class>)"` at startup.
#      This writes the pointer and installs a teardown trap in the caller's
#      shell. If the caller's shell exits for any reason (including SIGKILL's
#      parent reaping, ^C, or a crash), the trap fires and removes the pointer.
#   2. Authors and stages procedure instance .ncl files during the run.
#   3. The pre-commit hook sees the pointer, finds staged .ncl files, calls
#      `process-gate.sh validate <instance> <class>` for each.
#   4. At CLOSE, calls `bash process-gate.sh deregister` explicitly, then
#      removes the eval'd trap with `trap - EXIT HUP INT TERM`.
#
# Portability
# ───────────
# Nickel resolution mirrors ledger-validate.sh (AC7): direct `nickel` XOR
# `nix run nixpkgs#nickel --`. Neither available → gate halts non-zero rather
# than silently passing (a gate that cannot run is not a gate that passes).
# Import-path seam: contracts are located via -I <plugin>/ledger/contracts,
# NEVER project-relative — downstream users have predicate installed elsewhere.
set -u

# Resolve the PLUGIN root from this script's own real path (symlink-safe).
# All sibling machinery is located relative to $plugin.
here="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" && pwd)"
plugin="$(cd "$here/../.." && pwd)"
NICKEL_IMPORT_FLAGS=(-I "$plugin/ledger/contracts")

# --- portable nickel runner (mirrors ledger-validate.sh AC7) -----------------
NICKEL=()
resolve_nickel() {
  if [ ${#NICKEL[@]} -gt 0 ]; then return 0; fi
  if command -v nickel >/dev/null 2>&1; then
    NICKEL=(nickel)
  elif command -v nix >/dev/null 2>&1; then
    NICKEL=(nix run nixpkgs#nickel --)
  else
    echo "process-gate: neither 'nickel' nor 'nix' on PATH; cannot run gate" >&2
    exit 2
  fi
}

# --- contract name → contract file -------------------------------------------
# Map a short contract class name to the Nickel contract file that validates a
# procedure instance.
contract_file_for() {
  local class="$1"
  case "$class" in
    boundary) echo "$plugin/ledger/contracts/boundary_procedure.ncl" ;;
    refine)   echo "$plugin/ledger/contracts/refine_procedure.ncl" ;;
    *)
      echo "process-gate: unknown contract class '$class' (must be 'boundary' or 'refine')" >&2
      return 2
      ;;
  esac
}

# --- contract name → contract symbol -----------------------------------------
# Map a short contract class name to the exported Nickel symbol (field name)
# that is the procedure contract inside the contract file.
contract_symbol_for() {
  local class="$1"
  case "$class" in
    boundary) echo "BoundaryProcedure" ;;
    refine)   echo "RefineProcedure" ;;
    *)
      echo "process-gate: unknown contract class '$class'" >&2
      return 2
      ;;
  esac
}

# --- validate <instance.ncl> <contract-class> --------------------------------
# Export-validate the procedure instance against the named contract. The gate
# APPLIES the class contract externally — the instance cannot self-weaken by
# omitting its contract import or binding. Exit 0 = pass; 1 = fail; 2 = error.
#
# Validation strategy (gate-locus principle): the Nickel export IS the gate.
# The gate writes a temp wrapper that imports the instance and FORCES the class
# contract: `(import "$abs_instance") | cf.Symbol`. This ensures the gate is
# not fooled by a deposit that exports as a bare record with no contract binding
# (e.g. steps=[]) or that imports the contract but never applies it. The
# upstream-pinned required-step set lives in the contract, not the instance —
# so a skip/shrink attack cannot succeed even if the instance omits the binding.
cmd_validate() {
  local instance="${1:-}" class="${2:-}"
  if [[ -z "$instance" || -z "$class" ]]; then
    echo "usage: process-gate.sh validate <instance.ncl> <contract: boundary|refine>" >&2
    exit 2
  fi
  if [[ ! -f "$instance" ]]; then
    echo "process-gate: no such instance: $instance" >&2
    exit 2
  fi

  # Resolve the contract file and symbol for the class; exit 2 on unknown class.
  local _cf _sym
  _cf="$(contract_file_for "$class")" || exit 2
  _sym="$(contract_symbol_for "$class")" || exit 2

  resolve_nickel

  # Resolve instance to absolute path so the temp wrapper's import is stable
  # regardless of the caller's working directory.
  local abs_instance
  abs_instance="$(realpath "$instance")"

  # Write a temp wrapper .ncl that imports the instance and APPLIES the class
  # contract. Both paths are absolute so no -I is needed for resolution: Nickel
  # resolves relative imports inside the contract file from its own directory
  # (which is $plugin/ledger/contracts/), so sibling contracts resolve correctly.
  local tmp
  tmp="$(mktemp --suffix=.ncl)"
  printf 'let cf = import "%s" in\n(import "%s") | cf.%s\n' \
    "$_cf" "$abs_instance" "$_sym" > "$tmp"

  local rc=0
  "${NICKEL[@]}" export "${NICKEL_IMPORT_FLAGS[@]}" "$tmp" >/dev/null || rc=$?
  rm -f "$tmp"
  return "$rc"
}

# --- register <contract-class> [pointer-path] --------------------------------
# Write the active-walk pointer and print a trap teardown expression to STDOUT.
# The caller MUST eval the output:
#   eval "$(bash process-gate.sh register boundary)"
# This installs a trap in the caller's shell that removes the pointer on exit.
cmd_register() {
  local class="${1:-}" pointer="${2:-}"
  if [[ -z "$class" ]]; then
    echo "usage: process-gate.sh register <contract: boundary|refine> [pointer-path]" >&2
    exit 2
  fi

  # Validate the class name before writing anything.
  contract_file_for "$class" >/dev/null || exit 2

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

  # Write the pointer: one line, the contract class.
  printf '%s\n' "$class" > "$pointer"

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
