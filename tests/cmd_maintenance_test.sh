#!/usr/bin/env bash
test_status_tails_log_and_points_to_lint() {
  local root; root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  local body; body="$(cat "$root/plugins/mneme/commands/status.md")"
  assert_contains "$body" "mneme_log_tail" "status surfaces the recent log activity" || return 1
  assert_contains "$body" "/mneme:lint" "status points heavier audits to /mneme:lint" || return 1
}

test_review_logs_promote() {
  local root; root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  local body; body="$(cat "$root/plugins/mneme/commands/review.md")"
  assert_contains "$body" "mneme_log_append" "review logs promotions" || return 1
  assert_contains "$body" "promote" "review uses the promote op" || return 1
}
