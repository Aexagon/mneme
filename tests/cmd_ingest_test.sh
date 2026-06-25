#!/usr/bin/env bash
test_ingest_command_exists_and_wires() {
  local root; root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  local f="$root/plugins/mneme/commands/ingest.md"
  assert_file "$f" "ingest command exists" || return 1
  local body; body="$(cat "$f")"
  assert_contains "$body" "markitdown" "ingest converts rich files with markitdown" || return 1
  assert_contains "$body" "mneme_wiki_home" "ingest resolves the wiki home" || return 1
  assert_contains "$body" "pages/" "ingest writes summary pages" || return 1
  assert_contains "$body" "ingest" "ingest logs with the ingest op" || return 1
  assert_contains "$body" "bash <<'" "ingest runs helpers under explicit bash" || return 1
}
