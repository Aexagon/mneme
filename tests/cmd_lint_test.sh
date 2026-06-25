#!/usr/bin/env bash
test_lint_command_exists_and_wires_helpers() {
  local root; root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  local f="$root/plugins/mneme/commands/lint.md"
  assert_file "$f" "lint command file exists" || return 1
  local body; body="$(cat "$f")"
  assert_contains "$body" "mneme_links_dead" "lint checks dead links" || return 1
  assert_contains "$body" "mneme_links_orphans" "lint checks orphan notes" || return 1
  assert_contains "$body" "mneme_md_index_drift" "lint checks INDEX drift" || return 1
  assert_contains "$body" "read-only" "lint is read-only until confirmed" || return 1
}
