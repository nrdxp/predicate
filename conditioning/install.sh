#!/usr/bin/env bash
# conditioning/install.sh — native, install-time conditioning delivery.
#
# Predicate is INSTRUCTIONS + GENERATED PROMPTS, not a process wrapper. This
# script materializes predicate's behavioral law into each harness's NATIVE
# surface at install time, generated from `compose.ncl` on every run (no stale
# committed copy). It NEVER composes prompts itself — `nickel export` is the sole
# combinator; this is the imperative shell at the effect boundary.
#
# Per-harness native delivery (docs/conditioning-layer.md §Delivery — adding a
# harness is one branch):
#
#   claude-code:
#     - OUTPUT STYLE  → <claude-dir>/output-styles/predicate-composer.md
#       (frontmatter `keep-coding-instructions: false`: empties Claude Code's
#        built-in software-engineering block while PRESERVING tool defs, env info,
#        agent identity, and safety scaffolding — so predicate's law cleanly
#        becomes the behavioral half with nothing contradicting underneath. The
#        markdown body is appended to the system prompt.)
#     - WORKER AGENTS → <claude-dir>/agents/predicate-<role>.md  (every worker
#       permutation persisted; the agent body becomes that subagent's full system
#       prompt. A transparent CONVENIENCE cache — the composer may instead inject
#       a freshly generated persona dynamically via the native subagent path.)
#
#   agy:
#     - GEMINI.md     → <gemini-dir>/GEMINI.md  (managed block; injected into the
#       system prompt, so the law lands. No persistent worker surface: agy
#       generates worker personas from the same source at launch.)
#
# ACTIVATION NOTE: writing the output-style FILE does not by itself select it.
# To make predicate the active behavioral law, the harness must select the style
# (`/output-style` or `"outputStyle": "Predicate Composer"` in settings.json).
# That belongs to bootstrap/settings, not to this generator.
#
# Usage:
#   conditioning/install.sh [--harness NAME] [--dry-run]
#   conditioning/install.sh --role ROLE --dry-run     # inspect one composed prompt
#   conditioning/install.sh --uninstall
#
# Options:
#   --harness NAME    Restrict delivery to one harness's surfaces.
#                     One of: claude-code | agy | all   (default: claude-code)
#                     Legacy aliases accepted: antigravity, generic → agy.
#   --role ROLE       DRY-RUN ONLY: which composed prompt to print. A real install
#                     always materializes the full surface for the harness; this
#                     flag does not narrow it. Accepted for back-compat.
#                     One of: composer core-worker refine-worker doc-worker
#                             form-worker spec-worker boundary-worker
#                             survey-worker test-worker
#                             refuter-reviewer hickey-reviewer lowy-reviewer
#                             api-reviewer security-reviewer git-review-reviewer
#                             ai-slop-reviewer prior-art-reviewer vestigial-reviewer
#                             test-reviewer
#                             architect-seat lead-maintainer-seat process-auditor-seat
#                             hacker-seat
#   --dry-run         Print the delivery plan (and, with --role, that role's full
#                     composed prompt); write nothing to any surface.
#   --uninstall       Remove every predicate-owned conditioning surface across
#                     both harnesses. Idempotent; no role or harness needed.
#
# Environment overrides (hermeticity — point tests at a throwaway dir):
#   PREDICATE_CLAUDE_DIR  Claude config root (default: $HOME/.claude)
#   PREDICATE_GEMINI_DIR  agy/Gemini config root (default: $HOME/.gemini)
#   HOME                  base for the two defaults above
#   NICKEL_CMD            nickel runner (default: nickel on PATH; shell.nix provides it)
#   PREDICATE_SRC         predicate checkout (default: auto-resolved via realpath)
#
# Exit: 0 = delivered / dry-run / uninstall complete; non-zero = fatal (no write).
set -euo pipefail

# ---------------------------------------------------------------------------
# Paths — resolved via realpath for portability (no project-relative CWD assumptions).
# ---------------------------------------------------------------------------
self_path="$(realpath "${BASH_SOURCE[0]}")"
conditioning_dir="$(dirname "$self_path")"
predicate_src="${PREDICATE_SRC:-$(dirname "$conditioning_dir")}"
compose_ncl="$conditioning_dir/compose.ncl"

# Target roots — overridable for hermetic tests; default under $HOME for real installs.
claude_dir="${PREDICATE_CLAUDE_DIR:-$HOME/.claude}"
gemini_dir="${PREDICATE_GEMINI_DIR:-$HOME/.gemini}"

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

# Output-style display name (also the value to set in settings.json `outputStyle`).
readonly OUTPUT_STYLE_NAME='Predicate Composer'
readonly OUTPUT_STYLE_FILE='predicate-composer.md'

# The worker roles materialized as persisted Claude agents.
readonly WORKER_ROLES=(core-worker refine-worker doc-worker form-worker spec-worker boundary-worker survey-worker test-worker)
# The reviewer roles — read-only adversarial lenses. A distinct class: each
# composes the reviewer module (NOT producer), so they form a sibling list rather
# than joining WORKER_ROLES. This declaration is kept byte-identical to the one in
# test_conditioning.sh (F6 lockstep).
readonly REVIEWER_ROLES=(refuter-reviewer hickey-reviewer lowy-reviewer api-reviewer security-reviewer git-review-reviewer ai-slop-reviewer prior-art-reviewer vestigial-reviewer test-reviewer)
# The architect-tier council SEATS — a distinct class: each composes the
# council module (NOT producer), a sibling list like REVIEWER_ROLES. Kept
# byte-identical to the declaration in test_conditioning.sh (F6 lockstep).
readonly COUNCIL_ROLES=(architect-seat lead-maintainer-seat process-auditor-seat hacker-seat)
# Every role materialized as a persisted Claude agent (workers + reviewers + seats).
readonly AGENT_ROLES=("${WORKER_ROLES[@]}" "${REVIEWER_ROLES[@]}" "${COUNCIL_ROLES[@]}")
# All valid roles (for --role validation and dry-run targeting). The composer is
# the single output-style role (non-agent); the rest are dispatchable agents.
readonly ALL_ROLES=(composer "${AGENT_ROLES[@]}")

# ---------------------------------------------------------------------------
# parse args
# ---------------------------------------------------------------------------
role="composer"
role_explicit=false
harness="claude-code"
dry_run=false
uninstall=false

while [ "$#" -gt 0 ]; do
  case "$1" in
    --role)      role="${2:?--role needs a value}"; role_explicit=true; shift 2 ;;
    --harness)   harness="${2:?--harness needs a value}"; shift 2 ;;
    --dry-run)   dry_run=true; shift ;;
    --uninstall) uninstall=true; shift ;;
    -h|--help)
      sed -n '34,60p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo "install: unknown argument: $1" >&2; exit 2 ;;
  esac
done

# Normalize harness, accepting legacy bootstrap aliases.
case "$harness" in
  claude-code|agy|all) ;;
  antigravity|generic) harness="agy" ;;   # legacy aliases → native agy surface
  *)
    echo "install: unknown harness '$harness'." >&2
    echo "install: valid: claude-code | agy | all (aliases: antigravity, generic → agy)" >&2
    exit 2 ;;
esac

# ---------------------------------------------------------------------------
# validate_role — guard BEFORE any Nickel interpolation.
# The $role string is interpolated into a Nickel expression; an unchecked value
# lets an attacker break out of the string literal and import arbitrary files
# (e.g. --role 'x" (import "/etc/passwd") #'). Validating against the known set
# eliminates the injection surface entirely.
# ---------------------------------------------------------------------------
validate_role() {
  local r="$1" known
  for known in "${ALL_ROLES[@]}"; do
    [ "$r" = "$known" ] && return 0
  done
  echo "install: unknown role '${r}'." >&2
  echo "install: valid roles: ${ALL_ROLES[*]}" >&2
  exit 2
}

# ---------------------------------------------------------------------------
# generate_prompt — the functional core call.
# Runs `nickel export` on a wrapper that selects one role field of compose.ncl.
# The HasCore injection-rule contract fires here; if core is absent the export
# fails and this function exits non-zero before any surface is written.
# ---------------------------------------------------------------------------
generate_prompt() {
  local role_arg="$1"
  # Wrapper imports compose.ncl by absolute path (CWD-safe) and accesses the role
  # field via std.record.get (hyphenated-key safe).
  local wrapper
  wrapper="std.record.get \"${role_arg}\" (import \"${compose_ncl}\")"
  # Capture stdout (the prompt) ONLY; route stderr to a temp file. Folding stderr
  # into the prompt (2>&1) corrupts it with runner noise.
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
# worker_description — the `description` frontmatter that drives delegation.
# Concise: names the discipline so the composer can route to it.
# ---------------------------------------------------------------------------
# Per-role default model class. This is what lets the harness launch each
# agent at its expected tier WITHOUT the composer specifying it per dispatch:
# council seats reason at architect tier (opus) even under a cheaper composer;
# workers and reviewers default to sonnet; the surveyor is deliberately haiku —
# quick and bounded, predicated on the composer supplying well-defined
# boundaries (its conditioning requires exactly that). A campaign IBC may
# elevate a specific dispatch; these are the ambient defaults.
agent_model() {
  case "$1" in
    *-seat)          printf 'opus' ;;
    survey-worker)   printf 'haiku' ;;
    *)               printf 'sonnet' ;;
  esac
}

worker_description() {
  case "$1" in
    core-worker)     printf 'TDD feature implementation under the /core workflow: write the failing test invariant, verify baseline failure, then implement to green within the stated file surface.' ;;
    refine-worker)   printf 'Refine and optimize existing artifacts under /refine: contraction-loop sweeps to a fixed point, each finding grounded; cut, do not thin.' ;;
    doc-worker)      printf 'Documentation authoring and auditing under /doc-audit: link integrity, heading hierarchy, table formatting, and grounded claims written for the stranger-reader.' ;;
    form-worker)     printf 'Formal mathematical domain modeling under /form: construct, validate, and connect models whose every invariant has a falsification signpost.' ;;
    spec-worker)     printf 'Normative specification under /spec: machine-checkable invariants, permitted transitions, and forbidden states; every constraint names its evaluator.' ;;
    survey-worker)   printf 'Read-only cheap-tier territory mapping: locate and excerpt with file:line evidence, enumerate the universe before coverage claims, deposit findings and remainders; never judge, synthesize, or edit.' ;;
    boundary-worker) printf 'IBC authoring and refinement under /boundary: S1–S7 sufficiency contraction with deterministic acceptance criteria.' ;;
    test-worker)     printf 'Red-first test engineering under /core + /robust-testing: derive test invariants from acceptance criteria, write them as runnable tests, verify each fails for the right reason; never implement the feature.' ;;
    refuter-reviewer)     printf 'Lens-free read-only adversarial reviewer: attack the artifact as a whole for any defect, decorrelated by fresh eyes alone; name defects, never edit.' ;;
    hickey-reviewer)      printf 'Read-only structural-simplicity reviewer (hickey lens): scan for complected concerns and concept multiplication; name defects, never edit.' ;;
    lowy-reviewer)        printf 'Read-only volatility-decomposition reviewer (lowy lens): test module boundaries against axes of change; name defects, never edit.' ;;
    api-reviewer)         printf 'Read-only API surface-coherence reviewer (api lens): audit the public surface for minimality, type safety, and composability; name defects, never edit.' ;;
    security-reviewer)    printf 'Read-only security reviewer (security lens): trust-model and taint analysis against a capable adversary; name defects, never edit.' ;;
    git-review-reviewer)  printf 'Read-only change-coherence reviewer (git-review lens): purpose-first audit of git history and commit boundaries; name defects, never edit.' ;;
    ai-slop-reviewer)     printf 'Read-only AI-generated-code reviewer (ai-slop lens): hunt hollow plausibility, hallucinated APIs, and transformer cadence; name defects, never edit.' ;;
    prior-art-reviewer)   printf 'Read-only outward reviewer (prior-art lens): measure the artifact against production-tested references and literature by citation; name defects, never edit.' ;;
    vestigial-reviewer)   printf 'Read-only drift-residue reviewer (vestigial lens): hunt dead code, orphaned scaffolding, and stale breadcrumbs by reachability; name defects, never edit.' ;;
    test-reviewer)        printf 'Read-only test-surface reviewer (test lens): is the surface sufficient for the claims, and is every test earning its keep — hunt green-by-construction, mock-testing, weakened invariants, and superfluous tests to cut; name defects, never edit.' ;;
    architect-seat)       printf 'Council seat — the BOUNDARY lens: goal-fit, strategy, and architecture coherence. Sovereign over boundary-design; drives dag-amendment. Convened for exceptional (load-bearing) nodes, structural faults, and campaign CLOSE — not routine reconciles.' ;;
    lead-maintainer-seat) printf 'Council seat — the MERGE GATE: the hostile elite engineer-maintainer who owns the maintenance burden. Every merge needs his affirmative consent; green gates are necessary but never sufficient.' ;;
    process-auditor-seat) printf 'Council seat — the PROCESS + RESIDUE auditor: checks the composer against the pact and the law, proposes bars, and hunts vestigial residue greedily. Independent; reads the durable record directly.' ;;
    hacker-seat)          printf 'Council seat — the ATTACK lens: first-principles adversarial attacker of the system as built. Findings bind by demonstrated attack path; convened for security-consequential nodes and campaign CLOSE.' ;;
    *) printf 'Predicate worker persona.' ;;
  esac
}

# ---------------------------------------------------------------------------
# strip_managed_block — echo a file's content with the predicate managed block
# removed. A missing block is a clean pass-through.
# ---------------------------------------------------------------------------
strip_managed_block() {
  local file="$1"
  [ -f "$file" ] || return 0
  awk -v b="$BEGIN_MARK" -v e="$END_MARK" '
    $0 == b { skip = 1; next }
    $0 == e { skip = 0; next }
    !skip   { print }
  ' "$file"
}

# ===========================================================================
# Delivery — claude-code
# ===========================================================================

# Output style: predicate owns the whole file → write it entirely.
install_output_style() {
  local prompt="$1"
  local dir="$claude_dir/output-styles"
  local file="$dir/$OUTPUT_STYLE_FILE"
  mkdir -p "$dir"
  {
    printf -- '---\n'
    printf 'name: %s\n' "$OUTPUT_STYLE_NAME"
    printf 'description: %s\n' "Predicate's complete behavioral law as the composer — the live conductor/moderator and front door."
    printf 'keep-coding-instructions: false\n'
    printf -- '---\n\n'
    printf '%s\n' "$prompt"
  } >"$file.tmp"
  mv "$file.tmp" "$file"
  echo "install: wrote output style → $file"
}

# Worker agents: one predicate-owned file per worker permutation.
install_worker_agents() {
  local dir="$claude_dir/agents"
  mkdir -p "$dir"
  local r prompt file
  for r in "${AGENT_ROLES[@]}"; do
    prompt="$(generate_prompt "$r")"
    file="$dir/predicate-$r.md"
    {
      printf -- '---\n'
      printf 'name: predicate-%s\n' "$r"
      printf 'description: %s\n' "$(worker_description "$r")"
      printf 'model: %s\n' "$(agent_model "$r")"
      printf -- '---\n\n'
      printf '%s\n' "$prompt"
    } >"$file.tmp"
    mv "$file.tmp" "$file"
    echo "install: wrote worker agent → $file"
  done
}

# ===========================================================================
# Delivery — agy (GEMINI.md, managed block; user content outside it is preserved)
# ===========================================================================
install_gemini() {
  local prompt="$1"
  local file="$gemini_dir/GEMINI.md"
  mkdir -p "$gemini_dir"

  local body
  body="$(strip_managed_block "$file")"

  {
    if [ -n "$body" ]; then printf '%s\n' "$body"; fi
    printf '%s\n' "$BEGIN_MARK"
    printf '<!-- Generated by conditioning/install.sh — role: composer.\n'
    printf '     Managed block; re-run install.sh to update. Edit OUTSIDE this block. -->\n'
    printf '%s\n' "$prompt"
    printf '%s\n' "$END_MARK"
  } >"$file.tmp"
  mv "$file.tmp" "$file"
  echo "install: wrote GEMINI.md (managed block) → $file"
}

# ===========================================================================
# Uninstall — remove every predicate-owned surface, both harnesses. Idempotent.
# ===========================================================================
do_uninstall() {
  local removed=0

  # Output style.
  local os_file="$claude_dir/output-styles/$OUTPUT_STYLE_FILE"
  if [ -f "$os_file" ]; then rm -f "$os_file"; echo "install: removed $os_file"; removed=1; fi

  # Worker + reviewer agents.
  local r af
  for r in "${AGENT_ROLES[@]}"; do
    af="$claude_dir/agents/predicate-$r.md"
    if [ -f "$af" ]; then rm -f "$af"; echo "install: removed $af"; removed=1; fi
  done

  # GEMINI.md managed block; drop the file if nothing else remains.
  local gm="$gemini_dir/GEMINI.md"
  if [ -f "$gm" ] && grep -qxF "$BEGIN_MARK" "$gm"; then
    local body
    body="$(strip_managed_block "$gm")"
    if printf '%s' "$body" | grep -q '[^[:space:]]'; then
      printf '%s\n' "$body" >"$gm.tmp"; mv "$gm.tmp" "$gm"
      echo "install: stripped conditioning block from $gm"
    else
      rm -f "$gm"; echo "install: removed $gm (predicate-only file, now empty)"
    fi
    removed=1
  fi

  # Legacy cleanup: a prior (pre-native) install may have left a conditioning
  # block in CLAUDE.md. Strip it idempotently so no orphan survives.
  local claude_md="$claude_dir/CLAUDE.md"
  if [ -f "$claude_md" ] && grep -qxF "$BEGIN_MARK" "$claude_md"; then
    local cbody
    cbody="$(strip_managed_block "$claude_md")"
    printf '%s\n' "$cbody" >"$claude_md.tmp"; mv "$claude_md.tmp" "$claude_md"
    echo "install: stripped legacy conditioning block from $claude_md"
    removed=1
  fi

  [ "$removed" -eq 0 ] && echo "install: no predicate conditioning surfaces found (already clean)."
  echo "install: uninstall done."
}

# ===========================================================================
# main
# ===========================================================================
if "$uninstall"; then
  do_uninstall
  exit 0
fi

validate_role "$role"

# Dry-run: print the plan, and (with --role) the targeted composed prompt.
if "$dry_run"; then
  echo "install: --dry-run (harness=$harness); no surface will be written."
  echo "install: plan:"
  case "$harness" in
    claude-code|all)
      echo "  - output style → $claude_dir/output-styles/$OUTPUT_STYLE_FILE (keep-coding-instructions: false)"
      for r in "${AGENT_ROLES[@]}"; do
        echo "  - worker agent → $claude_dir/agents/predicate-$r.md"
      done ;;
  esac
  case "$harness" in
    agy|all) echo "  - GEMINI.md (managed block) → $gemini_dir/GEMINI.md" ;;
  esac
  echo "install: composed prompt for role='$role':"
  echo "---"
  printf '%s\n' "$(generate_prompt "$role")"
  exit 0
fi

if "$role_explicit"; then
  echo "install: note — --role is dry-run-only; a real install materializes the full surface."
fi

echo "install: native delivery (harness=$harness) ..."

# Composer prompt is reused for the output style and GEMINI.md.
composer_prompt=""
need_composer=false
case "$harness" in claude-code|all|agy) need_composer=true ;; esac
if "$need_composer"; then
  composer_prompt="$(generate_prompt "composer")"
  echo "install: generated composer prompt (${#composer_prompt} chars; HasCore passed)."
fi

case "$harness" in
  claude-code)
    install_output_style "$composer_prompt"
    install_worker_agents ;;
  agy)
    install_gemini "$composer_prompt" ;;
  all)
    install_output_style "$composer_prompt"
    install_worker_agents
    install_gemini "$composer_prompt" ;;
esac

echo "install: done."
echo "install: to ACTIVATE the output style, select it (\`/output-style\`) or set"
echo "install:   \"outputStyle\": \"$OUTPUT_STYLE_NAME\" in $claude_dir/settings.json."
