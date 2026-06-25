#!/usr/bin/env bash
test_engine_documents_phase1() {
  local root; root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  local body; body="$(cat "$root/plugins/mneme/skills/mneme-engine/SKILL.md")"
  assert_contains "$body" "log.md" "engine documents the timeline log" || return 1
  assert_contains "$body" "/mneme:lint" "engine lists the lint command" || return 1
  assert_contains "$body" "Cross-ref" "engine documents cross-referencing" || return 1
}
