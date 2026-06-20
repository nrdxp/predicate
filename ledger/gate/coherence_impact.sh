#!/usr/bin/env bash
# Bidirectional coherence-impact evaluator (the explicit per-landing RECONCILE
# step). RECONCILE judges a landing two ways at the boundary:
#
#   backward  does this landing break ALREADY-LANDED artifacts? (e.g. a cut
#             leaves a now-dangling reference in a surviving file)
#   forward   does this landing invalidate PENDING artifacts? (handled by the
#             premise-freshness pass; this gate covers what freshness cannot:
#             structural breakage across the whole tree)
#
# Routing follows the Verification Dual: re-run every machine-check that an
# evaluator exists for over the affected surface (the symbolic path); for any
# concern no evaluator covers, emit an explicit decorrelated-review DISPATCH
# directive (the adversarial path). The dispatch is deterministic even though
# the dispatched review returns a soft verdict — which is what keeps the
# PROTOCOL machine-executable. Catching breakage here, at the boundary, is the
# fix for drift that otherwise surfaces only at CLOSE.
#
# Machine-checks run (each only when its evaluator and inputs are present):
#   contract   nickel export of every ledger artifact still exits 0
#   orphans    no surviving file references a removed workflow as if live
#   links      markdown link syntax still resolves
#
# Usage:
#   coherence_impact.sh <repo-root> [--removed <workflow> ...]
# Output: per-check PASS/FAIL, a DISPATCH line per uncovered concern, verdict.
# Exit:   0 = all machine-checks passed (review dispatches, if any, are advisory
#         and tracked by the orchestrator), 1 = a machine-check failed (breakage
#         caught at the boundary), 2 = usage / environment error.
set -u

root="${1:-}"
if [ -z "$root" ] || [ ! -d "$root" ]; then
  echo "usage: coherence_impact.sh <repo-root> [--removed <workflow> ...]" >&2
  exit 2
fi
shift
removed=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --removed) shift; removed+=("$1") ;;
    *) echo "coherence_impact: unknown arg: $1" >&2; exit 2 ;;
  esac
  shift || true
done

fails=0
gate="$root/ledger/gate"
gates="$root/gates"

# Load project config if present; a downstream repo can override LINK_TARGETS
# (bash array) to match its own authoritative surface layout.
# Absent config → predicate defaults (mirrors check_orphans' ORPHAN_TARGETS list so
# that both gates apply the same frozen-history exclusion without duplicating it).
# shellcheck source=/dev/null
[ -f "$root/.ledger/config.sh" ] && source "$root/.ledger/config.sh"
# Default: same authoritative surfaces as check_orphans.sh ORPHAN_TARGETS.
# docs/plans/, docs/chronicle.md, and .scratch/.ledger working trees are
# intentionally omitted — they record frozen history, not live doctrine.
if [ -z "${LINK_TARGETS+set}" ]; then
  LINK_TARGETS=(skills templates ambient.md README.md AGENTS.md rules.md docs/authoring.md docs/getting-started.md)
fi

# --- contract: every ledger artifact still satisfies its Nickel contract -----
if [ -x "$gate/ledger-validate.sh" ] && [ -d "$root/ledger" ]; then
  artifacts=$(find "$root/ledger/examples" "$root/ledger/contracts" \
    -name '*.ncl' 2>/dev/null | sort)
  contract_fail=0
  for a in $artifacts; do
    # contracts/ are libraries (imported, not exported standalone); only the
    # examples export as artifacts. Skip pure contract libs.
    case "$a" in */contracts/*) continue ;; esac
    "$gate/ledger-validate.sh" structure "$a" >/dev/null 2>&1 \
      || { echo "FAIL  contract: $a no longer exports"; contract_fail=1; }
  done
  if [ "$contract_fail" -eq 0 ]; then
    echo "PASS  contract: every ledger example still exports"
  else
    fails=$((fails + 1))
  fi
else
  echo "DISPATCH  contract: no ledger gate present -> decorrelated review"
fi

# --- orphans: no surviving file references a removed workflow as if live -----
if [ "${#removed[@]}" -gt 0 ]; then
  if [ -x "$gates/check_orphans.sh" ]; then
    if "$gates/check_orphans.sh" "$root" "${removed[@]}" >/dev/null 2>&1; then
      echo "PASS  orphans: no live reference to a removed workflow"
    else
      echo "FAIL  orphans: a surviving file references a removed workflow"
      fails=$((fails + 1))
    fi
  else
    echo "DISPATCH  orphans: no orphan gate present -> decorrelated review"
  fi
fi

# --- links: markdown link syntax still resolves ------------------------------
# The link gate ships with the doc-audit skill (its script survived the skill's
# merge into documentation); fall back to a gates/ copy if one is promoted.
# Scans LINK_TARGETS only (authoritative surfaces), matching the exclusion used
# by check_orphans.sh — frozen history (docs/plans/, docs/chronicle.md, and
# the .scratch/.ledger working trees) is naturally excluded by not being listed.
link_gate=""
for cand in "$gates/check_docs.py" "$root/skills/doc-audit/scripts/check_docs.py"; do
  [ -f "$cand" ] && { link_gate="$cand"; break; }
done
if [ -n "$link_gate" ]; then
  link_fail=0
  for t in "${LINK_TARGETS[@]}"; do
    [ -e "$root/$t" ] || continue
    python3 "$link_gate" "$root/$t" >/dev/null 2>&1 || link_fail=1
  done
  if [ "$link_fail" -eq 0 ]; then
    echo "PASS  links: markdown link syntax resolves"
  else
    echo "FAIL  links: a markdown link no longer resolves"
    fails=$((fails + 1))
  fi
else
  # Link integrity has an evaluator in principle but none is wired here; the
  # adversarial path covers it explicitly rather than silently skipping.
  echo "DISPATCH  links: no link gate present -> decorrelated review"
fi

# Concerns with no deterministic evaluator at all (semantic coherence: does the
# landing's MEANING still cohere with the system's doctrine?) always route to
# the adversarial path — they are why CLOSE had a decorrelated sweep.
echo "DISPATCH  semantic-coherence: no evaluator can exist -> decorrelated review"

if [ "$fails" -ne 0 ]; then
  echo "INCOHERENT: $fails machine-check(s) failed — breakage caught at the boundary"
  exit 1
fi
echo "COHERENT (machine surface): all evaluators passed; review dispatches tracked"
exit 0
