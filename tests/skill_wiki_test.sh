#!/usr/bin/env bash
test_wiki_skill_documents_the_tier() {
  local root; root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  local f="$root/plugins/mneme/skills/mneme-wiki/SKILL.md"
  assert_file "$f" "mneme-wiki skill exists" || return 1
  local body; body="$(cat "$f")"
  assert_contains "$body" "never injected" "states wikis are never injected" || return 1
  assert_contains "$body" "/mneme:ingest" "points at the ingest command" || return 1
  assert_contains "$body" "pages/" "documents the corpus layout" || return 1
}
