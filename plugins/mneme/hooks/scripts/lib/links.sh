#!/usr/bin/env bash
# Mneme shared engine: [[wikilink]] graph. Depends on lib/md.sh for name: resolution.
mneme_links_in_note() {
  grep -oE '\[\[[A-Za-z0-9_-]+\]\]' "$1" 2>/dev/null | sed -E 's/\[\[(.*)\]\]/\1/' | sort -u
}

mneme_links_add() {
  local file="$1" slug="$2"
  grep -qE "\[\[${slug}\]\]" "$file" 2>/dev/null && return 0
  if grep -qE '^Related:' "$file" 2>/dev/null; then
    local tmp; tmp="$(mktemp)"
    sed -E "s|^(Related:.*)$|\1 [[${slug}]]|" "$file" > "$tmp" && mv "$tmp" "$file"
  else
    printf '\nRelated: [[%s]]\n' "$slug" >> "$file"
  fi
}

mneme_links_inbound() {
  local dir="$1" slug="$2"
  grep -lE "\[\[${slug}\]\]" "$dir"/*.md 2>/dev/null | while read -r f; do basename "$f"; done
}

# All slugs that are link targets but have no note whose name: matches.
mneme_links_dead() {
  local dir="$1" names targets
  names="$(for f in "$dir"/*.md; do [ -f "$f" ] && mneme_md_frontmatter_get "$f" name; done | sort -u)"
  targets="$(for f in "$dir"/*.md; do [ -f "$f" ] && mneme_links_in_note "$f"; done | sort -u)"
  comm -23 <(printf '%s\n' "$targets") <(printf '%s\n' "$names")
}

# Notes whose name: is never the target of any [[link]].
mneme_links_orphans() {
  local dir="$1" linked
  linked="$(for f in "$dir"/*.md; do [ -f "$f" ] && mneme_links_in_note "$f"; done | sort -u)"
  for f in "$dir"/*.md; do
    [ -f "$f" ] || continue
    local nm; nm="$(mneme_md_frontmatter_get "$f" name)"
    [ -n "$nm" ] || continue
    printf '%s\n' "$linked" | grep -qx "$nm" || basename "$f"
  done
}
