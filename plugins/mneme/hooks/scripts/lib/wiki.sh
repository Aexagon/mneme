#!/usr/bin/env bash
# Mneme shared engine: wiki (Tier 2) home + corpus resolution. A corpus is a
# subdir of the wiki home that contains an index.md.
mneme_wiki_home() {
  if [ -n "${MNEME_WIKI_DIR:-}" ]; then
    printf '%s\n' "$MNEME_WIKI_DIR"; return
  fi
  local cache="${MNEME_GLOBAL_DIR:-$HOME/.claude/mneme/cache}"
  printf '%s\n' "$(dirname "$cache")/wiki"
}

mneme_wiki_names() {
  local home="$1" d
  [ -d "$home" ] || return 0
  for d in "$home"/*/; do
    [ -f "${d}index.md" ] && basename "$d"
  done
}
