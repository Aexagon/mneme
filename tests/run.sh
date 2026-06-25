#!/usr/bin/env bash
# Mneme test runner. Sources assert + every *_test.sh, runs each test_* function.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/tests/lib/assert.sh"
PASS=0; FAIL=0
for f in "$ROOT"/tests/*_test.sh; do
  [ -f "$f" ] || continue
  . "$f"
  for fn in $(declare -F | awk '{print $3}' | grep '^test_'); do
    if "$fn"; then echo "ok   - $fn"; PASS=$((PASS+1))
    else echo "NOT  - $fn"; FAIL=$((FAIL+1)); fi
    unset -f "$fn"
  done
done
echo "----"
echo "pass=$PASS fail=$FAIL"
[ "$FAIL" -eq 0 ]
