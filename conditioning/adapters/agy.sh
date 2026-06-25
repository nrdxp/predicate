#!/usr/bin/env bash
# conditioning/adapters/agy.sh — per-launch agy adapter.
#
# Wraps an agy invocation with --system-prompt for the given role.
# This is the Tier 1 (per-launch) injection path for agy.
#
# Usage:
#   source conditioning/adapters/agy.sh
#   agy_with_conditioning --role ROLE [-- <agy args>...]
#
# Or invoke directly:
#   bash conditioning/adapters/agy.sh --role refine-worker \
#     -- --model flash --prompt-interactive "$(cat node_ibc.md)"
#
# If agy does not support --system-prompt, falls back to prepending the prompt
# to the initial user turn via --prompt-interactive (Tier 3 graceful degradation).
#
# Exit: propagates the exit status of `agy`.
set -euo pipefail

self_path="$(realpath "${BASH_SOURCE[0]}")"
adapters_dir="$(dirname "$self_path")"
conditioning_dir="$(dirname "$adapters_dir")"
install_sh="$conditioning_dir/install.sh"

export NICKEL_CMD="${NICKEL_CMD:-}"

agy_with_conditioning() {
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
    echo "adapter/agy: FATAL — empty prompt for role '$role'." >&2
    exit 1
  fi

  # Tier 1: --system-prompt (preferred; detected at runtime).
  if agy --help 2>/dev/null | grep -q -- '--system-prompt'; then
    exec agy --system-prompt "$prompt" "${extra_args[@]+"${extra_args[@]}"}"
  else
    # Tier 3 fallback: prepend to --prompt-interactive.
    # Extract any --prompt-interactive value from extra_args and prepend core.
    local ibc_text=""
    local remaining_args=()
    local i=0
    while [ "$i" -lt "${#extra_args[@]}" ]; do
      if [ "${extra_args[$i]}" = "--prompt-interactive" ]; then
        i=$(( i + 1 ))
        ibc_text="${extra_args[$i]}"
      else
        remaining_args+=("${extra_args[$i]}")
      fi
      i=$(( i + 1 ))
    done
    local prepended="SYSTEM CONDITIONING:\n${prompt}\n\n---\nTASK:\n${ibc_text}"
    exec agy --prompt-interactive "$prepended" \
      "${remaining_args[@]+"${remaining_args[@]}"}"
  fi
}

# Direct invocation.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  agy_with_conditioning "$@"
fi
