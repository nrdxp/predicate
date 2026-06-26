#!/usr/bin/env bash
# Hermetic test suite for check_commit_msg.py.
# Exits non-zero if any case produces an unexpected return code.
set -euo pipefail

SCRIPT="$(dirname "$0")/check_commit_msg.py"
PASS=0
FAIL=0

check() {
    local description="$1"
    local expected_rc="$2"  # "0" or "nonzero"
    shift 2
    # remaining args passed directly to the script
    set +e
    python3 "$SCRIPT" "$@"
    local actual_rc=$?
    set -e

    if [[ "$expected_rc" == "0" ]]; then
        if [[ "$actual_rc" -eq 0 ]]; then
            echo "PASS  [rc=0]  $description"
            PASS=$((PASS + 1))
        else
            echo "FAIL  [rc=$actual_rc, want 0]  $description"
            FAIL=$((FAIL + 1))
        fi
    else
        if [[ "$actual_rc" -ne 0 ]]; then
            echo "PASS  [rc=$actual_rc≠0]  $description"
            PASS=$((PASS + 1))
        else
            echo "FAIL  [rc=0, want non-zero]  $description"
            FAIL=$((FAIL + 1))
        fi
    fi
}

# --- positive: well-formed merge: header ---------------------------------
check "merge: integrate the foo branch (positive)" \
    "0" \
    --message "merge: integrate the foo branch"

# --- negative: over-length merge: header (>50 chars) --------------------
# 51-char header: "merge: " (7) + 44 chars of description = 51
check "merge: header exceeding 50 chars (negative)" \
    "nonzero" \
    --message "merge: this description is way too long to be valid"

# --- sanity: bare git auto-generated subject must fail -------------------
check "Merge branch 'x' without conventional type (must fail)" \
    "nonzero" \
    --message "Merge branch 'foo'"

# --- regression: existing type feat: still passes ------------------------
check "feat: x (existing type still passes)" \
    "0" \
    --message "feat: add a new thing"

# --- summary --------------------------------------------------------------
echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
