#!/usr/bin/env bash
# Tiny assertion helpers for Mneme's bash tests. Each prints FAIL and returns 1.
assert_contains() {
  case "$1" in *"$2"*) return 0;; *) echo "  FAIL: $3 (missing: $2)"; return 1;; esac
}
assert_not_contains() {
  case "$1" in *"$2"*) echo "  FAIL: $3 (unexpected: $2)"; return 1;; *) return 0;; esac
}
assert_eq() {
  [ "$1" = "$2" ] && return 0
  echo "  FAIL: $3 (got '$1', want '$2')"; return 1
}
assert_file() {
  [ -f "$1" ] && return 0
  echo "  FAIL: $2 (no file: $1)"; return 1
}
