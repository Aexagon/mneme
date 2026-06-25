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
