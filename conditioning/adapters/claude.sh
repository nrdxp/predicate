#!/usr/bin/env bash
# conditioning/adapters/claude.sh — per-launch Claude Code adapter.
#
# Wraps a claude CLI invocation with --append-system-prompt for the given role.
# This is the Tier 1 (per-launch) injection path for Claude Code.
#
# Usage:
#   source conditioning/adapters/claude.sh
#   claude_with_conditioning --role ROLE [-- <claude args>...]
#
# Or invoke directly to emit a ready-to-use command (useful for orchestrators):
#   bash conditioning/adapters/claude.sh --role core-worker -- --model sonnet --print
#
# The adapter calls conditioning/install.sh to generate the prompt (always fresh,
# never cached), then passes it to `claude` via --append-system-prompt.
#
# Exit: propagates the exit status of `claude`.
set -euo pipefail

self_path="$(realpath "${BASH_SOURCE[0]}")"
adapters_dir="$(dirname "$self_path")"
conditioning_dir="$(dirname "$adapters_dir")"
install_sh="$conditioning_dir/install.sh"

# Nickel runner (inherited or auto-detected by install.sh).
export NICKEL_CMD="${NICKEL_CMD:-}"

claude_with_conditioning() {
  local role="architect"
  local extra_args=()

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --role) role="${2:?--role needs a value}"; shift 2 ;;
      --)     shift; extra_args=("$@"); break ;;
      *)      extra_args+=("$1"); shift ;;
    esac
  done

  # Generate the prompt (HasCore contract enforced; fatal on failure).
  local prompt
  prompt="$(bash "$install_sh" --role "$role" --dry-run 2>/dev/null | \
    awk '/^---$/{found=1; next} found{print}')"

  if [ -z "$prompt" ]; then
    echo "adapter/claude: FATAL — empty prompt for role '$role'." >&2
    exit 1
  fi

  exec claude --append-system-prompt "$prompt" "${extra_args[@]+"${extra_args[@]}"}"
}

# Direct invocation: run claude_with_conditioning with all args.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  claude_with_conditioning "$@"
fi
