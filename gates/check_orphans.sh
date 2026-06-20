#!/usr/bin/env bash
# Semantic orphan gate — the referential-truth half of C6 that check_docs misses.
# check_docs.py validates markdown LINK SYNTAX; this validates that a workflow a
# reference NAMES still EXISTS. Fails (exit 1) if any surviving, authoritative
# file references a removed/demoted workflow as if it were live.
#
# Reference forms detected per removed workflow <n>:
#   /<n>            an invocation, not followed by a word char or hyphen (so
#                   /plan matches neither /planning nor /plan-review).
#   skills/<n>/     a skill-directory path reference.
#   `<n>`           a backticked workflow name presented as a live example
#                   (e.g. a "Workflow SOPs (e.g. `plan`, `core`)" list).
#   the <n> workflow   active-invocation prose ("run the plan workflow"). The
#                   definite article is deliberate: it distinguishes a live
#                   invocation from correctly-historical prose ("Formerly
#                   carried by a sketch workflow, since demoted") and from
#                   generic/negated phrasing ("not a discrete planning
#                   workflow", "exactly ONE predicate workflow"), which the
#                   campaign intentionally keeps.
#
# Usage: check_orphans.sh <repo-root> <removed-workflow>...
# Exit:  0 = no orphan refs, 1 = orphan refs found, 2 = usage error.
set -u
root="${1:-}"
if [ -z "$root" ]; then echo "usage: check_orphans.sh <repo-root> <removed-workflow>..." >&2; exit 2; fi
shift
if [ "$#" -eq 0 ]; then echo "usage: check_orphans.sh <repo-root> <removed-workflow>..." >&2; exit 2; fi

# Load project config if present; a downstream repo can override ORPHAN_TARGETS
# (bash array), ORPHAN_EXCLUDE (grep -vE pattern suffix), and SKILLS_DIR (the
# skills-directory token used in reference patterns). Absent config → predicate
# defaults below.
# shellcheck source=/dev/null
[ -f "$root/.ledger/config.sh" ] && source "$root/.ledger/config.sh"
# Default to predicate's authoritative surfaces when not set by config.
if [ -z "${ORPHAN_TARGETS+set}" ]; then
  ORPHAN_TARGETS=(skills templates ambient.md README.md AGENTS.md rules.md docs/authoring.md docs/getting-started.md)
fi
# Default exclusion: genuine URLs and this project's own install-path name.
: "${ORPHAN_EXCLUDE:=plugins/predicate}"
# Default skills-directory token used in reference-pattern matching.
: "${SKILLS_DIR:=skills}"

pat=""
for n in "$@"; do
  # /<name> not followed by a word char or hyphen (so /plan matches neither
  # /planning nor /plan-review), OR a skills/<name>/ path reference, OR the
  # backticked name as a live example, OR "the <name> workflow" prose.
  pat="${pat:+$pat|}(/${n}([^A-Za-z0-9-]|\$)|${SKILLS_DIR}/${n}/|\`${n}\`|the ${n} workflow)"
done

# cd into the root so grep emits RELATIVE match paths. CRITICAL: an absolute root
# prefixes every match line with the repo's own path (which contains "predicate"
# and "github.com"), and the content exclusion below would then vacuously strip
# every line, falsely reporting "clean". Relative paths keep the exclusion honest.
cd "$root" 2>/dev/null || { echo "check_orphans: no such root: $root" >&2; exit 2; }

# Authoritative surfaces only. Dated history (docs/chronicle.md, docs/plans/) and
# the .scratch working set are intentionally excluded — they record history.
# Exclude genuine URL / install-path CONTENT: the project is itself named
# "predicate", so its URLs (https://.../predicate) and plugin install paths
# (plugins/predicate) are not workflow invocations. Safe now that paths are relative.
# Case-sensitive (no -i): workflow/skill names are lowercase by convention, so a
# lowercase `plan` is the cut workflow while an uppercase `PLAN`/`SKETCH` is a
# campaign STATE or chronicle protocol name — legitimately distinct, not an orphan.
hits=$(grep -rnE "$pat" "${ORPHAN_TARGETS[@]}" 2>/dev/null | grep -vE "https?://|${ORPHAN_EXCLUDE}")

if [ -n "$hits" ]; then
  echo "ORPHAN WORKFLOW REFERENCES (named but removed/demoted):"
  echo "$hits"
  exit 1
fi
echo "no orphan workflow references"
exit 0
