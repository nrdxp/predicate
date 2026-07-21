#!/usr/bin/env bash
# Forge-prose gate — run over every drafted PR/issue/comment body BEFORE it is
# posted (forge §2 mandates drafting in a scratch file; this is the check that
# drafting exists to enable).
#
# Three checks, three recurring field failures:
#   1. INTERNAL IDS   — delegates to check_internal_ids.sh --files (full-content
#                       mode: a draft is wholly new prose).
#   2. PROCESS VOCAB  — the forge reader wants exactly two things: what is this
#                       work, and how do I review it. The production process —
#                       councils, seats, reconcile rounds, campaigns, dispatch
#                       mechanics — is never content, and it kept leaking as
#                       NARRATIVE that the token-level ID gate cannot see. This
#                       scan is ADVISORY-with-override: a hit means rewrite the
#                       sentence in substance terms, or consciously narrow
#                       FORGE_VOCAB_PAT in .ledger/config.sh for a legitimate
#                       per-project collision (a thread-pool repo's "worker",
#                       an orchestration product's "orchestrator"). Never
#                       silence it by habit.
#   3. HARD WRAPS     — GitHub renders single newlines in PR/issue bodies as
#                       hard <br> breaks, so terminal-habit column-wrapping
#                       renders as a staccato mess. Forge prose is soft-wrapped:
#                       one paragraph = one logical line, blank lines between,
#                       structure from markdown (headings, lists, fences) —
#                       never manual breaks. Flags consecutive prose lines
#                       outside fences, lists, headings, quotes, and tables.
#
# Usage:  check_forge_prose.sh --files <draft> [<draft> ...]
# Exit:   0 clean, 1 finding(s), 2 usage error.
set -u

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
# shellcheck source=/dev/null
[ -f "$root/.ledger/config.sh" ] && source "$root/.ledger/config.sh"
# Predicate-process vocabulary that has no place in forge prose. Word-boundary,
# case-insensitive; override per project via FORGE_VOCAB_PAT.
: "${FORGE_VOCAB_PAT:=\b(council|seat|reconcile|merge-consent|decorrelat[a-z]*|orchestrat[a-z]*|dispatch[a-z]*|worktree|campaign[a-z]*|persona[a-z]*|IBC|composer|boundary contract)\b}"

if [ "${1:-}" != "--files" ]; then
  echo "check_forge_prose: usage: check_forge_prose.sh --files <draft> [...]" >&2
  exit 2
fi
shift
[ "$#" -eq 0 ] && { echo "check_forge_prose: nothing to check"; exit 0; }

viol=0
for f in "$@"; do
  case "$f" in
    /*) abs="$f" ;;
    *)  abs="$root/$f" ;;
  esac
  if [ ! -f "$abs" ]; then
    echo "check_forge_prose: skipping missing file: $f" >&2
    continue
  fi

  # --- 1. internal IDs (full-content: a draft is wholly new prose) ---------
  if ! bash "$here/check_internal_ids.sh" --files "$abs" >/dev/null 2>&1; then
    echo "IDS   $f: campaign-internal tokens present (details:" \
         "check_internal_ids.sh --files $f)"
    viol=1
  fi

  # --- 2. process vocabulary (advisory-with-override) ----------------------
  vocab_hits="$(grep -niE "$FORGE_VOCAB_PAT" -- "$abs" || true)"
  if [ -n "$vocab_hits" ]; then
    printf '%s\n' "$vocab_hits" | sed "s|^|VOCAB $f:|"
    viol=1
  fi

  # --- 3. hard-wrapped prose ----------------------------------------------
  # Consecutive prose lines (outside fenced code, and neither line a heading,
  # list item, quote, table row, or indented block) = suspected manual wrap.
  wrap_hits="$(awk '
    /^(```|~~~)/ { fence = !fence; prev = 0; next }
    fence        { next }
    /^[[:space:]]*$/                 { prev = 0; next }
    /^(#|>|\||[[:space:]]{4})/       { prev = 0; next }
    /^[[:space:]]*([-*+]|[0-9]+[.)]) / { prev = 0; next }
    { if (prev) printf "%d: consecutive prose lines (suspected manual wrap)\n", NR
      prev = 1 }
  ' "$abs")"
  if [ -n "$wrap_hits" ]; then
    printf '%s\n' "$wrap_hits" | sed "s|^|WRAP  $f:|"
    viol=1
  fi
done

if [ "$viol" -ne 0 ]; then
  printf '%s\n' \
    '' \
    'FORGE-PROSE FINDINGS — fix before posting.' \
    '' \
    'The forge reader wants exactly two things: what is this work, and how do' \
    'I review it. IDS/VOCAB hits are production-process content — rewrite each' \
    'sentence in substance terms (what was found, what changed, how to verify)' \
    'or, for a genuine per-project collision, narrow FORGE_VOCAB_PAT in' \
    '.ledger/config.sh. WRAP hits are manual line breaks: GitHub renders them' \
    'literally — one paragraph per logical line, blank lines between.'
  exit 1
fi
exit 0
