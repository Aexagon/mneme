#!/usr/bin/env bash
test_md_frontmatter_get() {
  local root tmp; root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  . "$root/plugins/mneme/hooks/scripts/lib/md.sh"
  tmp="$(mktemp -d)"
  printf -- '---\nname: jerry-voice\ndescription: bullets, hint do not declare\ntype: preference\n---\n\nBody.\n' > "$tmp/n.md"
  local v; v="$(mneme_md_frontmatter_get "$tmp/n.md" name)"
  rm -rf "$tmp"
  assert_eq "$v" "jerry-voice" "frontmatter name parsed" || return 1
}

test_md_index_upsert_and_remove() {
  local root tmp; root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  . "$root/plugins/mneme/hooks/scripts/lib/md.sh"
  tmp="$(mktemp -d)"
  mneme_md_index_upsert "$tmp" "preference-jerry-voice.md" "Jerry voice" "bullets, not prose"
  mneme_md_index_upsert "$tmp" "preference-jerry-voice.md" "Jerry voice" "bullets; hint do not declare"
  local body; body="$(cat "$tmp/INDEX.md")"
  assert_contains "$body" "[Jerry voice](preference-jerry-voice.md) — bullets; hint do not declare" "upsert replaces, not duplicates" || { rm -rf "$tmp"; return 1; }
  assert_eq "$(grep -c 'preference-jerry-voice.md' "$tmp/INDEX.md")" "1" "exactly one index line for the file" || { rm -rf "$tmp"; return 1; }
  mneme_md_index_remove "$tmp" "preference-jerry-voice.md"
  assert_eq "$(grep -c 'preference-jerry-voice.md' "$tmp/INDEX.md")" "0" "remove drops the line" || { rm -rf "$tmp"; return 1; }
  rm -rf "$tmp"
}
