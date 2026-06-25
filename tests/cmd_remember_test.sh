#!/usr/bin/env bash
test_remember_wires_crossref_and_log() {
  local root; root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  local body; body="$(cat "$root/plugins/mneme/commands/remember.md")"
  assert_contains "$body" "mneme_links_add" "remember adds reciprocal cross-refs via the lib" || return 1
  assert_contains "$body" "mneme_log_append" "remember logs the save" || return 1
  assert_contains "$body" "at most **3**" "remember states the <=3 cross-ref cap" || return 1
}
