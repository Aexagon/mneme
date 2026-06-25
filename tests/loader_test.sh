#!/usr/bin/env bash
# Smoke test: load-cache.sh injects the protocol + the index, never log.md, and honors the cap.
test_loader_injects_protocol_and_index() {
  local root tmp out
  root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  tmp="$(mktemp -d)"; mkdir -p "$tmp/cache"
  printf '# Mneme cache\n\n- [Demo](fact-demo.md) — a throwaway line\n' > "$tmp/cache/INDEX.md"
  printf 'this log line must not be injected\n' > "$tmp/cache/log.md"
  out="$(MNEME_GLOBAL_DIR="$tmp/cache" bash "$root/plugins/mneme/hooks/scripts/load-cache.sh" \
        | python3 -c 'import json,sys;print(json.load(sys.stdin)["hookSpecificOutput"]["additionalContext"])')"
  rm -rf "$tmp"
  assert_contains "$out" "Mneme is active." "loader injects the protocol" || return 1
  assert_contains "$out" "[Demo](fact-demo.md)" "loader injects the index bullet" || return 1
  assert_not_contains "$out" "this log line must not be injected" "loader never injects log.md" || return 1
}

test_loader_honors_max_chars() {
  local root tmp out
  root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  tmp="$(mktemp -d)"; mkdir -p "$tmp/cache"
  printf '# Mneme cache\n\n- [Demo](fact-demo.md) — a throwaway line that is fairly long\n' > "$tmp/cache/INDEX.md"
  out="$(MNEME_GLOBAL_DIR="$tmp/cache" MNEME_MAX_CHARS=120 bash "$root/plugins/mneme/hooks/scripts/load-cache.sh" \
        | python3 -c 'import json,sys;print(json.load(sys.stdin)["hookSpecificOutput"]["additionalContext"])')"
  rm -rf "$tmp"
  assert_contains "$out" "Mneme index truncated" "loader truncates past MNEME_MAX_CHARS" || return 1
}
