#!/usr/bin/env bash
# conditioning/install.sh — harness-agnostic conditioning delivery.
#
# Generates a per-role system prompt from compose.ncl and delivers it to the
# best available conditioning surface, walking the arsenal-class ladder:
#
#   Tier 1 — system prompt (strongest)
#     claude-code:  --append-system-prompt flag available → write to output-style
#                   persistent install surface (CLAUDE.md @import of generated file).
#                   Detected at runtime; not assumed.
#     agy:          --system-prompt flag available (per-launch only; no persistent surface)
#
#   Tier 2 — globally-read rules file (graceful floor)
#     Claude Code:  CLAUDE.md managed block (@-import of generated prompt file)
#     Generic:      AGENTS.md prepend section
#
# The functional core is compose.ncl + the HasCore injection-rule contract.
# This script is the imperative shell: it generates, then delivers.
# It NEVER composes prompts itself — `nickel export` is the sole combinator.
#
# ARCHITECTURE.md §5: adding a harness = one thin detection + install branch here;
# compose.ncl is unchanged.
#
# Usage:
#   conditioning/install.sh [--role ROLE] [--harness HARNESS] [--dry-run]
#   conditioning/install.sh --uninstall
#
# Options:
#   --role ROLE       Role to install (default: architect)
#                     One of: architect core-worker refine-worker doc-worker
#                             form-worker spec-worker boundary-worker
#   --harness NAME    Force a harness instead of auto-detecting
#                     One of: claude-code agy generic
#   --dry-run         Generate the prompt but print it to stdout; no harness writes.
#   --uninstall       Symmetric teardown: strip the conditioning block from
#                     CLAUDE.md and remove conditioning/generated/ (if present).
#                     Idempotent; no role or harness needed.
#
# Environment overrides:
#   NICKEL_CMD        nickel runner (default: nickel on PATH; shell.nix provides it)
#   PREDICATE_SRC     path to the predicate checkout (default: auto-resolved via realpath)
#   HOME              harness config root (honored as-is; testable via override)
#
# Exit: 0 = delivered / dry-run complete; non-zero = fatal (no harness write performed).
set -euo pipefail

# ---------------------------------------------------------------------------
# Paths — resolved via realpath for downstream portability (no project-relative
# assumptions; works from any CWD once installed anywhere on the filesystem).
# ---------------------------------------------------------------------------
self_path="$(realpath "${BASH_SOURCE[0]}")"
conditioning_dir="$(dirname "$self_path")"
predicate_src="${PREDICATE_SRC:-$(dirname "$conditioning_dir")}"
compose_ncl="$conditioning_dir/compose.ncl"

# Nickel runner: require nickel on PATH (provided by the project shell.nix).
# Do NOT fall back to `nix run`; enter the shell first: nix develop / direnv.
if [ -z "${NICKEL_CMD:-}" ]; then
  if ! command -v nickel >/dev/null 2>&1; then
    echo "conditioning/install.sh: 'nickel' is not on PATH." >&2
    echo "  Enter the project shell first:  nix develop  (or: use direnv with shell.nix)" >&2
    exit 1
  fi
  NICKEL_CMD="nickel"
fi

# Managed-block sentinels (same pattern as bootstrap/install.sh).
readonly BEGIN_MARK='# >>> predicate conditioning block >>>'
readonly END_MARK='# <<< predicate conditioning block <<<'

# ---------------------------------------------------------------------------
# parse args
# ---------------------------------------------------------------------------
role="architect"
harness=""
dry_run=false
uninstall=false

while [ "$#" -gt 0 ]; do
  case "$1" in
    --role)      role="${2:?--role needs a value}";    shift 2 ;;
    --harness)   harness="${2:?--harness needs a value}"; shift 2 ;;
    --dry-run)   dry_run=true; shift ;;
    --uninstall) uninstall=true; shift ;;
    -h|--help)
      sed -n '29,38p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo "install: unknown argument: $1" >&2; exit 2 ;;
  esac
done

# ---------------------------------------------------------------------------
# do_uninstall — symmetric teardown, called when --uninstall is passed.
# Strips the conditioning managed block from CLAUDE.md (idempotent; a missing
# block is a clean no-op) and removes conditioning/generated/ if it was written
# by a prior Tier-1 install. No role, no nickel needed.
# ---------------------------------------------------------------------------
do_uninstall() {
  local claude_md="$HOME/.claude/CLAUDE.md"

  # Strip the conditioning block from CLAUDE.md.
  if [ -f "$claude_md" ]; then
    if grep -qxF "$BEGIN_MARK" "$claude_md"; then
      local body
      body="$(awk -v b="$BEGIN_MARK" -v e="$END_MARK" '
        $0 == b { skip = 1; next }
        $0 == e { skip = 0; next }
        !skip   { print }
      ' "$claude_md")"
      printf '%s\n' "$body" >"$claude_md.conditioning.tmp"
      mv "$claude_md.conditioning.tmp" "$claude_md"
      echo "install: removed predicate conditioning block from $claude_md."
    else
      echo "install: no conditioning block found in $claude_md (already clean)."
    fi
  else
    echo "install: $claude_md does not exist (already clean)."
  fi

  # Remove conditioning/generated/ (written by Tier-1 install).
  local gen_dir="$conditioning_dir/generated"
  if [ -d "$gen_dir" ]; then
    rm -rf "$gen_dir"
    echo "install: removed $gen_dir."
  else
    echo "install: $gen_dir absent (already clean)."
  fi

  echo "install: uninstall done."
}

# ---------------------------------------------------------------------------
# validate_role — guard BEFORE any Nickel interpolation.
# The $role string is interpolated into a Nickel expression; an unchecked
# value lets an attacker break out of the string literal and import arbitrary
# files (e.g., --role 'x" (import "/etc/passwd") #').
# Validating against the known set eliminates the injection surface entirely.
# ---------------------------------------------------------------------------
validate_role() {
  local r="$1"
  case "$r" in
    architect|core-worker|refine-worker|doc-worker|form-worker|spec-worker|boundary-worker)
      return 0 ;;
    *)
      echo "install: unknown role '${r}'." >&2
      echo "install: valid roles: architect core-worker refine-worker doc-worker" \
           "form-worker spec-worker boundary-worker" >&2
      exit 2 ;;
  esac
}

# ---------------------------------------------------------------------------
# generate_prompt — the functional core call.
# Runs `nickel export` on compose.ncl; treats non-zero exit as FATAL per spec.
# The HasCore injection-rule contract fires here; if core is absent the export
# fails and this function exits non-zero before any harness write occurs.
# ---------------------------------------------------------------------------
generate_prompt() {
  local role_arg="$1"
  # Extract a single role field as plain text via a wrapper expression piped
  # to nickel export.  The wrapper imports compose.ncl by absolute path (safe
  # across any CWD) and accesses the role field via std.record.get for
  # hyphenated key safety.
  local wrapper
  wrapper="std.record.get \"${role_arg}\" (import \"${compose_ncl}\")"
  # Capture stdout (the prompt) ONLY; route stderr to a temp file. Folding stderr
  # into the prompt (2>&1) corrupts it with runner noise — e.g. nix's "unpacking
  # '...' into the Git cache" progress line on first fetch lands inside the prompt.
  local prompt _err
  _err="$(mktemp)"
  if ! prompt="$(echo "$wrapper" | $NICKEL_CMD export --format text 2>"$_err")"; then
    echo "install: FATAL — nickel export failed for role '${role_arg}'." >&2
    echo "install: nickel diagnostics:" >&2
    cat "$_err" >&2
    rm -f "$_err"
    echo "install: No harness surface was written." >&2
    exit 1
  fi
  rm -f "$_err"
  printf '%s' "$prompt"
}

# ---------------------------------------------------------------------------
# harness detection — probe capabilities at runtime; do not pre-encode.
# Implements the P-ARSENAL ladder: strongest first.
# ---------------------------------------------------------------------------
detect_harness() {
  local explicit="$1"
  if [ -n "$explicit" ]; then printf '%s' "$explicit"; return; fi

  # Tier 1: claude-code — probe for --append-system-prompt in the CLI help.
  if command -v claude >/dev/null 2>&1; then
    if claude --help 2>/dev/null | grep -q -- '--append-system-prompt'; then
      printf 'claude-code-tier1'; return
    fi
    # claude CLI present but no Tier 1 surface → fall to Tier 2.
    printf 'claude-code'; return
  fi

  # agy (per-launch Tier 1 via --system-prompt).
  if command -v agy >/dev/null 2>&1; then
    printf 'agy'; return
  fi

  # Generic fallback: AGENTS.md prepend.
  printf 'generic'
}

# ---------------------------------------------------------------------------
# delivery: claude-code Tier 1 — write to a generated file, @import it from
# the CLAUDE.md managed block.  The generated file is placed next to compose.ncl
# so the import path is stable and harness-readable.
# ---------------------------------------------------------------------------
install_claude_code_tier1() {
  local prompt="$1"
  local generated_file="$conditioning_dir/generated/${role}.md"
  mkdir -p "$(dirname "$generated_file")"
  printf '%s' "$prompt" >"$generated_file"
  echo "install: wrote generated prompt to $generated_file"

  # Wire the @import into CLAUDE.md managed block (idempotent, append-safe).
  local claude_md="$HOME/.claude/CLAUDE.md"
  mkdir -p "$(dirname "$claude_md")"
  [ -f "$claude_md" ] || : >"$claude_md"

  local import_line="@$generated_file"

  local body
  body="$(awk -v b="$BEGIN_MARK" -v e="$END_MARK" '
    $0 == b { skip = 1; next }
    $0 == e { skip = 0; next }
    !skip   { print }
  ' "$claude_md")"

  {
    if [ -n "$body" ]; then printf '%s\n' "$body"; fi
    printf '%s\n' "$BEGIN_MARK"
    printf '# Generated by conditioning/install.sh — role: %s\n' "$role"
    printf '# Managed block; re-run install.sh to update. Edit outside this block.\n'
    printf '%s\n' "$import_line"
    printf '%s\n' "$END_MARK"
  } >"$claude_md.conditioning.tmp"
  mv "$claude_md.conditioning.tmp" "$claude_md"
  echo "install: wired @import into $claude_md (idempotent)."
}

# ---------------------------------------------------------------------------
# delivery: claude-code Tier 2 — CLAUDE.md managed block with inline prompt.
# Used when --append-system-prompt is not available.
# ---------------------------------------------------------------------------
install_claude_code_tier2() {
  local prompt="$1"
  local claude_md="$HOME/.claude/CLAUDE.md"
  mkdir -p "$(dirname "$claude_md")"
  [ -f "$claude_md" ] || : >"$claude_md"

  local body
  body="$(awk -v b="$BEGIN_MARK" -v e="$END_MARK" '
    $0 == b { skip = 1; next }
    $0 == e { skip = 0; next }
    !skip   { print }
  ' "$claude_md")"

  {
    if [ -n "$body" ]; then printf '%s\n' "$body"; fi
    printf '%s\n' "$BEGIN_MARK"
    printf '# Generated conditioning for role: %s\n' "$role"
    printf '# Managed by conditioning/install.sh — re-run to update.\n'
    printf '%s\n' "$prompt"
    printf '%s\n' "$END_MARK"
  } >"$claude_md.conditioning.tmp"
  mv "$claude_md.conditioning.tmp" "$claude_md"
  echo "install: wrote conditioning (Tier 2) to $claude_md."
}

# ---------------------------------------------------------------------------
# delivery: agy — print the per-launch dispatch pattern; no persistent surface.
# agy is per-launch only; no persistent install is possible via conditioning.
# ---------------------------------------------------------------------------
install_agy() {
  local prompt="$1"
  local generated_file="$conditioning_dir/generated/${role}.md"
  mkdir -p "$(dirname "$generated_file")"
  printf '%s' "$prompt" >"$generated_file"
  echo "install: wrote generated prompt to $generated_file"
  echo "install: agy has no persistent system-prompt surface."
  echo "install: use the following per-launch pattern (Tier 1):"
  printf '\n  agy --system-prompt "$(cat %s)" --model <tier> --prompt-interactive "$(cat node_ibc.md)"\n\n' \
    "$generated_file"
}

# ---------------------------------------------------------------------------
# delivery: generic — prepend to AGENTS.md.
# ---------------------------------------------------------------------------
install_generic() {
  local prompt="$1"
  local agents_md="${PWD}/AGENTS.md"
  [ -f "$agents_md" ] || : >"$agents_md"

  local body
  body="$(awk -v b="$BEGIN_MARK" -v e="$END_MARK" '
    $0 == b { skip = 1; next }
    $0 == e { skip = 0; next }
    !skip   { print }
  ' "$agents_md")"

  {
    printf '%s\n' "$BEGIN_MARK"
    printf '# Generated conditioning for role: %s\n' "$role"
    printf '# Managed by conditioning/install.sh — re-run to update.\n'
    printf '%s\n' "$prompt"
    printf '%s\n' "$END_MARK"
    if [ -n "$body" ]; then printf '%s\n' "$body"; fi
  } >"$agents_md.conditioning.tmp"
  mv "$agents_md.conditioning.tmp" "$agents_md"
  echo "install: wrote conditioning to $agents_md (generic Tier 2)."
}

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------
if "$uninstall"; then
  do_uninstall
  exit 0
fi

validate_role "$role"
echo "install: generating prompt for role='$role' ..."
prompt="$(generate_prompt "$role")"
echo "install: generated ${#prompt} chars (HasCore contract passed)."

if "$dry_run"; then
  echo "install: --dry-run; printing prompt to stdout and exiting."
  echo "---"
  printf '%s\n' "$prompt"
  exit 0
fi

harness="$(detect_harness "$harness")"
echo "install: harness=$harness"

case "$harness" in
  claude-code-tier1) install_claude_code_tier1 "$prompt" ;;
  claude-code)       install_claude_code_tier2 "$prompt" ;;
  agy)               install_agy "$prompt" ;;
  generic)           install_generic "$prompt" ;;
  *)
    echo "install: unknown harness: $harness" >&2
    exit 2 ;;
esac

echo "install: done."
