#!/usr/bin/env bash
# The helpers are bash functions, but the agent's login shell may be zsh. Every
# prompt that runs a helper block must invoke bash explicitly (heredoc), so the
# helpers run under bash and source+call happen in one shell.
test_helper_blocks_invoke_bash_explicitly() {
  local root cmd body; root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  for cmd in remember status review lint; do
    body="$(cat "$root/plugins/mneme/commands/$cmd.md")"
    assert_contains "$body" "bash <<'" "$cmd.md runs its helper block under explicit bash" || return 1
  done
}
