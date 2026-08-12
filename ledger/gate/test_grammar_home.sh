#!/usr/bin/env bash
# Mutation suite for check_grammar_home.py — the check that binds
# docs/entries.md (the vocabulary home) to ledger/derive/extract_entries.py
# (the grammar that reads it).
#
# A check that only ever passes proves nothing, so every case here MUTATES one
# side and asserts the check catches it, in BOTH directions:
#
#   COVERAGE    a token the extractor maps but the home never names
#   VOCABULARY  a token the home names but the extractor does not recognize
#
# The mutations are derived from the LIVE files, never from committed copies:
# a snapshot of docs/entries.md would be a second record of the vocabulary,
# which is the exact failure mode the home exists to prevent.
#
# Usage: test_grammar_home.sh
# Exit:  0 = every case matched, 1 = a case mismatched, 2 = environment error.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
check="$root/ledger/gate/check_grammar_home.py"
doc="$root/docs/entries.md"
extractor="$root/ledger/derive/extract_entries.py"

command -v python3 >/dev/null 2>&1 || { echo "ENV: python3 not found on PATH"; exit 2; }
[ -f "$check" ]     || { echo "ENV: check missing: $check"; exit 2; }
[ -f "$doc" ]       || { echo "ENV: vocabulary home missing: $doc"; exit 2; }
[ -f "$extractor" ] || { echo "ENV: extractor missing: $extractor"; exit 2; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fails=0
expect() {
  local desc="$1" exp="$2" kw="$3"; shift 3
  [ "$1" = "--" ] && shift
  local out rc ok=1
  out="$( cd "$root" && "$@" 2>&1 )"; rc=$?
  [ "$rc" -eq "$exp" ] || ok=0
  if [ -n "$kw" ]; then printf '%s' "$out" | grep -q -- "$kw" || ok=0; fi
  if [ "$ok" -eq 1 ]; then
    echo "PASS  ($rc) $desc"
  else
    echo "FAIL  (got rc=$rc want $exp; want-kw='$kw') $desc"
    printf '%s\n' "$out" | tail -3
    fails=$((fails + 1))
  fi
}

run() { python3 "$check" "$@"; }

# --- green: the live pair agrees -------------------------------------------
expect "live home + live extractor -> agree" 0 "PASS" \
  -- run

# --- COVERAGE: the extractor maps a token the home does not name ------------
# Strip every `supersedes::` span from the home. This reproduces exactly the
# state the repository was in before the closure-edge grammar was documented.
sed 's/`supersedes::[^`]*`//g' "$doc" > "$tmp/home-missing-token.md"
expect "home drops a mapped token -> COVERAGE" 1 'COVERAGE:   `supersedes::`' \
  -- run --doc "$tmp/home-missing-token.md"

# The same direction reached from the other side: the extractor grows a token
# and the home, untouched, has never heard of it.
sed 's/^MAPPED = {"check",/MAPPED = {"rescinds", "check",/' "$extractor" \
  > "$tmp/extractor-grown.py"
grep -q '"rescinds"' "$tmp/extractor-grown.py" \
  || { echo "ENV: MAPPED mutation did not apply — the literal moved"; exit 2; }
expect "extractor maps a new token -> COVERAGE" 1 'COVERAGE:   `rescinds::`' \
  -- run --extractor "$tmp/extractor-grown.py"

# --- VOCABULARY: the home names a token the extractor rejects ---------------
{ cat "$doc"; printf '\n- An invented token: `rescinds:: [X]`.\n'; } \
  > "$tmp/home-invented-token.md"
expect "home invents a token -> VOCABULARY" 1 'VOCABULARY: `rescinds::`' \
  -- run --doc "$tmp/home-invented-token.md"

# --- the metavariable is not an invented token ------------------------------
# The home writes `token:: value` to describe the span SHAPE. If that were read
# as a token name, the check would fail on the correct document forever.
grep -q '`token::' "$doc" \
  || { echo "ENV: the home no longer writes the \`token::\` metavariable"; exit 2; }
expect "metavariable \`token::\` is not read as a token" 0 "PASS" \
  -- run --doc "$doc"

# --- environment errors are exit 2, never a false verdict -------------------
expect "missing home -> ENV, not a pass" 2 "no such file" \
  -- run --doc "$tmp/does-not-exist.md"
expect "missing extractor -> ENV, not a pass" 2 "no such file" \
  -- run --extractor "$tmp/does-not-exist.py"

if [ "$fails" -ne 0 ]; then
  echo "FAIL: $fails grammar-home case(s) mismatched"; exit 1
fi
echo "PASS: all grammar-home cases matched their expected exit codes"
exit 0
