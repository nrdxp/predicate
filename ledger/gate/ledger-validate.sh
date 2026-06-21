#!/usr/bin/env bash
# Ledger validation gate — one portable command, invoked at BOTH the commit
# gate (rules.md §3) and at dispatch. It carries two checks that share one
# principle, "demonstrate the condition unforgeably":
#
#   1. STRUCTURE  the ledger artifact satisfies its Nickel contract
#                 (`nickel export` exits 0). A malformed artifact cannot pass.
#   2. AUTHORITY  every staged path falls under some DAG node's declared
#                 file_surface — "not in the IBC -> not authorized". A change
#                 with no authorizing node fails the gate.
#
# Portability (AC7): nickel need not be on PATH. The runner is resolved to a
# direct `nickel` XOR `nix run nixpkgs#nickel --`, so the gate is identical in
# a human shell and a headless orchestrator. If neither is reachable the gate
# halts non-zero rather than skipping its checks (Reserved halt: a gate that
# cannot run is not a gate that passes).
#
# Usage:
#   ledger-validate.sh structure <artifact.ncl>
#       export the artifact; exit 0 iff it satisfies its contract.
#
#   ledger-validate.sh authorize <dag.ncl> [path ...]
#       export+validate the DAG, then authorize the given paths against it.
#       With no paths, authorize the staged change (git diff --cached).
#
#   ledger-validate.sh commit-gate <dag.ncl>
#       the commit-gate entry: structure-validate the DAG, then authorize the
#       staged change set against it. This is what rules.md §3 wires.
#
# Exit codes: 0 = pass, 1 = a check failed, 2 = usage / environment error.
set -euo pipefail

# Resolve THIS script's own real directory (symlink-safe via realpath) so the
# sibling machinery it invokes — authorized.py — is located relative to where the
# PLUGIN lives, not relative to whatever repo is being gated. The gate is correct
# wherever it is invoked from, including through a symlink in a consuming repo.
here="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" && pwd)"

# --- portable nickel runner (AC7) -----------------------------------------
# Resolve once; every nickel call below goes through "$@" expansion of it.
#
# Import-path seam (downstream consumers): this script is installed at
# <plugin>/ledger/gate/ledger-validate.sh, so <plugin>/ledger/contracts is
# two directory levels up from $here. NICKEL_IMPORT_FLAGS holds the -I flag
# injected after the `export` subcommand at each call site (Nickel requires
# -I to follow the subcommand, not precede it). This lets a downstream .ncl
# file import predicate contracts by LOGICAL NAME — `import "dag.ncl"` —
# without vendoring or absolute paths. Predicate's own artifacts use relative
# imports (import "../contracts/dag.ncl") and are unaffected: Nickel resolves
# relative imports against the importing file first; -I only adds a fallback
# search dir.
plugin="$(cd "$here/../.." && pwd)"
NICKEL_IMPORT_FLAGS=(-I "$plugin/ledger/contracts")

resolve_nickel() {
  if command -v nickel >/dev/null 2>&1; then
    NICKEL=(nickel)
  elif command -v nix >/dev/null 2>&1; then
    NICKEL=(nix run nixpkgs#nickel --)
  else
    echo "ledger-validate: neither 'nickel' nor 'nix' on PATH; cannot run gate" >&2
    exit 2
  fi
}

# structure <artifact.ncl>: validate one artifact.
# Contract definitions (ledger/contracts/) hold contracts/functions — not
# serializable — so they are typechecked rather than exported. Instances
# (ledger/fixtures/, ledger/state/, etc.) are export-validated as before.
cmd_structure() {
  local artifact="${1:-}"
  if [[ -z "$artifact" ]]; then
    echo "usage: ledger-validate.sh structure <artifact.ncl>" >&2
    exit 2
  fi
  if [[ ! -f "$artifact" ]]; then
    echo "ledger-validate: no such artifact: $artifact" >&2
    exit 2
  fi
  resolve_nickel
  # Resolve to absolute path so the path-pattern check is reliable regardless
  # of how the caller spells the path.  Classification is keyed on the
  # ARTIFACT'S own resolved path — not on the plugin's contracts/ dir — so
  # the check works when the script lives in a different worktree or repo
  # root than the artifact being validated (e.g. a worktree commit).
  local abs_artifact
  abs_artifact="$(realpath "$artifact")"
  case "$abs_artifact" in
    */ledger/contracts/*.ncl)
      # Contract definitions hold types/functions — not serializable — so
      # typecheck only.  Set -I to the artifact's own directory so sibling
      # contracts in the SAME tree are importable without absolute paths.
      "${NICKEL[@]}" typecheck -I "$(dirname "$abs_artifact")" "$artifact" >/dev/null
      ;;
    *)
      "${NICKEL[@]}" export "${NICKEL_IMPORT_FLAGS[@]}" "$artifact" >/dev/null
      ;;
  esac
}

# authorize <dag.ncl> [path ...]: validate the DAG, then check paths.
cmd_authorize() {
  local dag="${1:-}"
  if [[ -z "$dag" ]]; then
    echo "usage: ledger-validate.sh authorize <dag.ncl> [path ...]" >&2
    exit 2
  fi
  shift || true
  if [[ ! -f "$dag" ]]; then
    echo "ledger-validate: no such DAG: $dag" >&2
    exit 2
  fi
  resolve_nickel
  # Export once; reuse the validated JSON for the authorization predicate so
  # the structural gate and the authority gate read the same graph. mktemp +
  # explicit cleanup (not a RETURN trap, which would clobber the exit code we
  # want to propagate from authorized.py).
  local tmp
  tmp="$(mktemp)"
  "${NICKEL[@]}" export "${NICKEL_IMPORT_FLAGS[@]}" "$dag" >"$tmp"

  local rc=0
  if [[ "$#" -gt 0 ]]; then
    local args=()
    local p
    for p in "$@"; do args+=(--path "$p"); done
    python3 "$here/authorized.py" --dag "$tmp" "${args[@]}" || rc=$?
  else
    git diff --cached --name-only \
      | python3 "$here/authorized.py" --dag "$tmp" || rc=$?
  fi
  rm -f "$tmp"
  return "$rc"
}

# commit-gate <dag.ncl>: structure-validate the DAG, then authorize staged.
cmd_commit_gate() {
  local dag="${1:-}"
  if [[ -z "$dag" ]]; then
    echo "usage: ledger-validate.sh commit-gate <dag.ncl>" >&2
    exit 2
  fi
  cmd_structure "$dag"
  cmd_authorize "$dag"
}

main() {
  local sub="${1:-}"
  shift || true
  case "$sub" in
    structure)    cmd_structure "$@" ;;
    authorize)    cmd_authorize "$@" ;;
    commit-gate)  cmd_commit_gate "$@" ;;
    *)
      echo "usage: ledger-validate.sh {structure|authorize|commit-gate} ..." >&2
      exit 2
      ;;
  esac
}

main "$@"
