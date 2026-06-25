#!/usr/bin/env bash
test_recall_offers_file_back_optin() {
  local root; root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  local body; body="$(cat "$root/plugins/mneme/commands/recall.md")"
  assert_contains "$body" "file the answer back" "recall offers to file a synthesis back" || return 1
  assert_contains "$body" "recall-filed" "recall logs a filed synthesis with the recall-filed op" || return 1
  assert_contains "$body" "read-only" "recall stays read-only by default" || return 1
}
