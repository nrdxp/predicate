#!/usr/bin/env bash
# Self-containment gate (the semantic rule the commit-hygiene VALIDATOR omits).
# A commit message must be reconstructable from the repo alone — no internal
# campaign references: node IDs (P1, P14, ...), layer tags (L1/L2), or AC/C ids.
# Complements check_commit_msg.py (form only). Usage: <msg> -> 0 clean / 1 viol.
set -u
msg="${1:-}"
# P[0-9]+ covers every node ID (the prior P1..P11 cap silently passed P12+,
# which the campaign now uses) without a leading zero so it cannot match a bare
# "P0"-style token; node IDs start at P1.
pat='\bP[1-9][0-9]*\b|\bnode P[0-9]|\bL[0-9]\b|\bAC-?P?[0-9]+|\bC-P[0-9]+'
hits=$(printf '%s' "$msg" | grep -noE "$pat" || true)
if [ -n "$hits" ]; then
  printf 'SELF-CONTAINMENT VIOLATION — internal refs:\n%s\n' "$hits"
  exit 1
fi
exit 0
