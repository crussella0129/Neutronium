#!/usr/bin/env bash
# Tests for audit.sh.
#
# audit.sh is a linter that ships inside a skill, which makes it the one file
# here that can silently rot: a broken rule reads as a clean run. Each fixture
# under tests/fixtures/ pins one rule to an exit code and an expected marker,
# so the scope-depth heuristic can be tuned without regressing.
#
# Usage: bash scripts/test-audit.sh

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
AUDIT="$HERE/audit.sh"
FIXTURES="$HERE/../tests/fixtures"
PASSED=0
FAILED=0

# check <fixture> <expected-exit> <must-match> [must-not-match]
check() {
  local name="$1" want_code="$2" want="$3" reject="${4:-}"
  local out code ok=1

  out=$(bash "$AUDIT" "$FIXTURES/$name" 2>&1)
  code=$?

  [ "$code" = "$want_code" ] || ok=0
  [ -n "$want" ] && { printf '%s' "$out" | grep -qE "$want" || ok=0; }
  [ -n "$reject" ] && { printf '%s' "$out" | grep -qE "$reject" && ok=0; }

  if [ "$ok" = 1 ]; then
    printf '✓ %s\n' "$name"
    PASSED=$((PASSED + 1))
  else
    printf '✗ %s — exit %s (wanted %s), expected /%s/\n' "$name" "$code" "$want_code" "$want"
    printf '%s\n' "$out" | sed 's/^/      /'
    FAILED=$((FAILED + 1))
  fi
}

echo "── audit.sh tests"
echo

# Scope-depth rule: the same call is correct or fatal depending on where it sits.
check dom-ok             0 'ok .*No browser globals at module top level' '✗ FAIL|⚠ WARN'
check dom-module         1 '✗ FAIL.*module top level'
check dom-setup          0 '⚠ WARN.*setup body'

# Hard rules.
check react-import       1 '✗ FAIL.*No imports from react'
check classname          1 '✗ FAIL.*className'
check props-destructure  1 '✗ FAIL.*destructuring of props'

echo
if [ "$FAILED" -gt 0 ]; then
  echo "── $FAILED failed, $PASSED passed"
  exit 1
fi
echo "── all $PASSED passed"
