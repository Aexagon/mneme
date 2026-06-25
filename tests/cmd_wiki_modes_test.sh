#!/usr/bin/env bash
test_recall_has_wiki_branch() {
  local root; root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  local body; body="$(cat "$root/plugins/mneme/commands/recall.md")"
  assert_contains "$body" "--wiki" "recall has a --wiki query branch" || return 1
  assert_contains "$body" "mneme_wiki_home" "recall resolves the wiki home" || return 1
}

test_lint_has_wiki_target() {
  local root; root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  local body; body="$(cat "$root/plugins/mneme/commands/lint.md")"
  assert_contains "$body" "--wiki" "lint can target a wiki corpus" || return 1
  assert_contains "$body" "mneme_wiki_home" "lint resolves the wiki home" || return 1
}
