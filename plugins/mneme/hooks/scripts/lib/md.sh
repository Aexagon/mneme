#!/usr/bin/env bash
# Mneme shared engine: frontmatter read + INDEX.md bookkeeping. Note bodies are authored by commands.
mneme_md_frontmatter_get() {
  awk -v key="$2" '
    NR==1 && $0=="---" {infm=1; next}
    infm && $0=="---" {exit}
    infm {
      i=index($0,":")
      if (i>0) {
        k=substr($0,1,i-1); v=substr($0,i+1)
        gsub(/^[ \t]+|[ \t]+$/,"",k); gsub(/^[ \t]+|[ \t]+$/,"",v)
        if (k==key) {print v; exit}
      }
    }' "$1" 2>/dev/null
}

mneme_md_index_upsert() {
  local dir="$1" file="$2" title="$3" desc="$4" index="$1/INDEX.md" tmp
  [ -d "$dir" ] || mkdir -p "$dir"
  [ -f "$index" ] || printf '# Mneme cache\n\n' > "$index"
  tmp="$(mktemp)"
  grep -vF "($file)" "$index" > "$tmp" 2>/dev/null || true
  printf -- '- [%s](%s) — %s\n' "$title" "$file" "$desc" >> "$tmp"
  mv "$tmp" "$index"
}

mneme_md_index_remove() {
  local dir="$1" file="$2" index="$1/INDEX.md" tmp
  [ -f "$index" ] || return 0
  tmp="$(mktemp)"
  grep -vF "($file)" "$index" > "$tmp" 2>/dev/null || true
  mv "$tmp" "$index"
}
