#!/usr/bin/env bash
test_log_append_creates_and_appends() {
  local root tmp; root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  . "$root/plugins/mneme/hooks/scripts/lib/log.sh"
  tmp="$(mktemp -d)"
  mneme_log_append "$tmp" remember feedback-no-em-dash
  mneme_log_append "$tmp" prune old-note "duplicate"
  local body; body="$(cat "$tmp/log.md")"
  rm -rf "$tmp"
  assert_contains "$body" "# Mneme log" "log has a header" || return 1
  assert_contains "$body" "remember | feedback-no-em-dash" "log records the op + slug" || return 1
  assert_contains "$body" "prune | old-note — duplicate" "log records an optional note" || return 1
}

test_log_tail_returns_last_n() {
  local root tmp; root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  . "$root/plugins/mneme/hooks/scripts/lib/log.sh"
  tmp="$(mktemp -d)"
  mneme_log_append "$tmp" remember note-one
  mneme_log_append "$tmp" remember note-two
  mneme_log_append "$tmp" prune note-three "dup"
  local out; out="$(mneme_log_tail "$tmp" 2)"
  rm -rf "$tmp"
  assert_not_contains "$out" "note-one" "tail 2 drops the oldest entry" || return 1
  assert_contains "$out" "note-two" "tail 2 keeps the second entry" || return 1
  assert_contains "$out" "note-three" "tail 2 keeps the newest entry" || return 1
}
