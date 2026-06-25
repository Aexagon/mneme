#!/usr/bin/env bash
_links_fixture() {
  local d="$1"
  printf -- '---\nname: a\ndescription: note a\ntype: fact\n---\n\nSee [[b]].\n' > "$d/fact-a.md"
  printf -- '---\nname: b\ndescription: note b\ntype: fact\n---\n\nLone note. Points to [[ghost]].\n' > "$d/fact-b.md"
}

test_links_in_note_and_add() {
  local root tmp; root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  . "$root/plugins/mneme/hooks/scripts/lib/md.sh"
  . "$root/plugins/mneme/hooks/scripts/lib/links.sh"
  tmp="$(mktemp -d)"; _links_fixture "$tmp"
  assert_eq "$(mneme_links_in_note "$tmp/fact-a.md")" "b" "reads [[b]] from note a" || { rm -rf "$tmp"; return 1; }
  mneme_links_add "$tmp/fact-b.md" a
  mneme_links_add "$tmp/fact-b.md" a   # idempotent
  assert_eq "$(grep -c '\[\[a\]\]' "$tmp/fact-b.md")" "1" "add is idempotent" || { rm -rf "$tmp"; return 1; }
  rm -rf "$tmp"
}

test_links_inbound_dead_orphans() {
  local root tmp; root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  . "$root/plugins/mneme/hooks/scripts/lib/md.sh"
  . "$root/plugins/mneme/hooks/scripts/lib/links.sh"
  tmp="$(mktemp -d)"; _links_fixture "$tmp"
  assert_contains "$(mneme_links_inbound "$tmp" b)" "fact-a.md" "a links to b (inbound)" || { rm -rf "$tmp"; return 1; }
  assert_contains "$(mneme_links_dead "$tmp")" "ghost" "ghost is a dead link" || { rm -rf "$tmp"; return 1; }
  assert_contains "$(mneme_links_orphans "$tmp")" "fact-a.md" "a has no inbound links (orphan)" || { rm -rf "$tmp"; return 1; }
  rm -rf "$tmp"
}
