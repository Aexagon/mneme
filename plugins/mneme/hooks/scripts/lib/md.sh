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

# Two-way drift between INDEX.md and the note files. Uses temp files (not process
# substitution) so an empty side yields no spurious blank-line matches.
mneme_md_index_drift() {
  local dir="$1" index="$1/INDEX.md" itmp atmp b
  itmp="$(mktemp)"; atmp="$(mktemp)"
  grep -oE '\([^)]+\.md\)' "$index" 2>/dev/null | sed -E 's/^\(//; s/\)$//' | sort -u > "$itmp"
  for f in "$dir"/*.md; do
    [ -f "$f" ] || continue
    b="$(basename "$f")"
    case "$b" in INDEX.md|log.md|_*) continue;; esac
    printf '%s\n' "$b"
  done | sort -u > "$atmp"
  comm -23 "$itmp" "$atmp" | sed 's/^/missing-file: /'
  comm -13 "$itmp" "$atmp" | sed 's/^/unindexed: /'
  rm -f "$itmp" "$atmp"
}
