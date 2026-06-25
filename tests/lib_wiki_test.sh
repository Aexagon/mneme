#!/usr/bin/env bash
test_wiki_home_resolves() {
  local root; root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  . "$root/plugins/mneme/hooks/scripts/lib/wiki.sh"
  assert_eq "$(MNEME_WIKI_DIR=/x/w mneme_wiki_home)" "/x/w" "explicit MNEME_WIKI_DIR wins" || return 1
  assert_eq "$(MNEME_WIKI_DIR= MNEME_GLOBAL_DIR=/a/b/cache mneme_wiki_home)" "/a/b/wiki" "derives sibling of the cache" || return 1
}

test_wiki_names_lists_corpora() {
  local root tmp; root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  . "$root/plugins/mneme/hooks/scripts/lib/wiki.sh"
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/alpha" "$tmp/beta" "$tmp/empty"
  printf '# a\n' > "$tmp/alpha/index.md"
  printf '# b\n' > "$tmp/beta/index.md"
  local out; out="$(mneme_wiki_names "$tmp")"
  rm -rf "$tmp"
  assert_contains "$out" "alpha" "lists a corpus with index.md" || return 1
  assert_contains "$out" "beta" "lists a second corpus" || return 1
  assert_not_contains "$out" "empty" "skips a dir with no index.md" || return 1
}
