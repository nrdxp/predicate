#!/usr/bin/env bash
# Suite for ledger/gate/currency.py -- the git-level half of the expiry
# mechanism (.ledger/deposits/expiry-mechanics/architect-seat/
# 2026-08-24-ruling-expiry-mechanics.md [R1]/[R5]/[LM6]): lapse detection
# (`git diff --quiet <at> HEAD -- <scope>`), the anchor-not-an-ancestor
# report the compiled model's H1 precondition requires
# (`rewrite_escapes_monotonicity`, [LM3]), and the movable-ref refusal (H2).
#
# Built on a throwaway git repository (`git init` in a tmpdir, `-c
# user.name=/-c user.email=` inline flags -- never `git config`, per the
# commit gate's own rail) so every case controls its own commit graph
# precisely rather than depending on this repository's real history.
#
# Usage: test_currency.sh
# Exit:  0 = every case matched, 1 = a case mismatched, 2 = environment error.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
tool="$root/ledger/gate/currency.py"

command -v python3 >/dev/null 2>&1 || { echo "ENV: python3 not found on PATH"; exit 2; }
command -v git >/dev/null 2>&1 || { echo "ENV: git not found on PATH"; exit 2; }
[ -f "$tool" ] || { echo "ENV: currency.py missing: $tool"; exit 2; }

repo="$(mktemp -d)"
trap 'rm -rf "$repo"' EXIT

gid=(-c user.name=test-currency -c user.email=test@currency -c commit.gpgsign=false)
g() { git "${gid[@]}" -C "$repo" "$@"; }

g init -q -b main
mkdir -p "$repo/scope" "$repo/other"
echo "v1" > "$repo/scope/a.txt"
echo "v1" > "$repo/other/b.txt"
g add -A
g commit -q -m "c1: seed scope and other"
c1="$(g rev-parse HEAD)"

fails=0
# expect DESC EXPECTED-RC KEYWORD -- COMMAND...
expect() {
  local desc="$1" exp="$2" kw="$3"; shift 3
  [ "$1" = "--" ] && shift
  local out rc ok=1
  out="$("$@" 2>&1)"; rc=$?
  [ "$rc" -eq "$exp" ] || ok=0
  if [ -n "$kw" ]; then printf '%s' "$out" | grep -q -- "$kw" || ok=0; fi
  if [ "$ok" -eq 1 ]; then
    echo "PASS  ($rc) $desc"
  else
    echo "FAIL  (got rc=$rc want $exp; want-kw='$kw') $desc"
    printf '%s\n' "$out" | tail -6
    fails=$((fails + 1))
  fi
}

# --- current: nothing under scope changed since c1 ---------------------------
expect "at c1 with no further commits -> current" 0 "current" \
  -- python3 "$tool" --repo "$repo" --anchor "$c1" --scope "scope"

# --- lapsed: scope changed, other did not -------------------------------------
echo "v2" > "$repo/scope/a.txt"
g add -A
g commit -q -m "c2: change scope only"
c2="$(g rev-parse HEAD)"
expect "scope changed at c2 -> lapsed, names the changed path" 1 "scope/a.txt" \
  -- python3 "$tool" --repo "$repo" --anchor "$c1" --scope "scope"
expect "a DISJOINT scope (other/) is untouched by the scope-only change -> current" 0 "current" \
  -- python3 "$tool" --repo "$repo" --anchor "$c1" --scope "other"

# --- committed state only: an uncommitted scope edit changes nothing here ----
echo "v3-dirty" > "$repo/scope/a.txt"
expect "an UNCOMMITTED scope edit at HEAD=c2 -> still current (committed state only)" 0 "current" \
  -- python3 "$tool" --repo "$repo" --anchor "$c2" --scope "scope"
g checkout -q -- "$repo/scope/a.txt"

# --- anchor-not-an-ancestor: an orphan branch shares no history with c1/c2 ---
g checkout -q --orphan orphan1
g rm -rq --cached . >/dev/null 2>&1 || true
echo "orphan" > "$repo/scope/a.txt"
g add -A
g commit -q -m "orphan commit, unrelated history"
expect "anchor from a branch HEAD does not extend -> anchor-not-an-ancestor" 2 \
  "anchor-not-an-ancestor" \
  -- python3 "$tool" --repo "$repo" --anchor "$c1" --scope "scope"
g checkout -q main

# --- movable-ref anchors are refused, never resolved ---------------------------
expect "a branch name as anchor -> movable-ref, refused before any git lookup" 3 \
  "movable-ref" \
  -- python3 "$tool" --repo "$repo" --anchor "main" --scope "scope"
expect "a hex-shaped but non-existent commit -> refused, not silently current" 3 \
  "does not resolve" \
  -- python3 "$tool" --repo "$repo" --anchor "deadbeef01" --scope "scope"

echo
if [ "$fails" -eq 0 ]; then echo "test_currency: ALL PASS"; exit 0; fi
echo "test_currency: $fails FAILURE(S)"; exit 1
