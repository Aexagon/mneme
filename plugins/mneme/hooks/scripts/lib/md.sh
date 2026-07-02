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

# mkdir-based lock (portable: macOS has no flock). Concurrent writers (parallel
# Claude sessions running remember/review) must not clobber each other's INDEX.md.
# Bounded retries + short sleeps (~3s total), then stale-break: a lock dir older
# than ~10s belongs to a crashed writer and must not deadlock every future session.
_mneme_md_lock() {
  local lock="$1.lock" i mt now
  for i in $(seq 1 30); do
    if mkdir "$lock" 2>/dev/null; then return 0; fi
    mt="$(stat -f %m "$lock" 2>/dev/null || stat -c %Y "$lock" 2>/dev/null)"
    now="$(date +%s)"
    if [ -n "$mt" ] && [ $((now - mt)) -ge 10 ]; then
      rm -rf "$lock" 2>/dev/null
      mkdir "$lock" 2>/dev/null && return 0
    fi
    sleep 0.1
  done
  return 1  # caller proceeds unlocked: fail SOFT (a rare dup/lost line beats a hung hook)
}
_mneme_md_unlock() { rm -rf "$1.lock" 2>/dev/null; }

mneme_md_index_upsert() {
  local dir="$1" file="$2" title="$3" desc="$4" index="$1/INDEX.md"
  [ -d "$dir" ] || mkdir -p "$dir"
  [ -f "$index" ] || printf '# Mneme cache\n\n' > "$index"
  # Critical section in a subshell with trap-EXIT so the lock is released on every
  # path (grep/mv failure included), regardless of the caller's set -e/-u state.
  _mneme_md_lock "$index"; local locked=$?
  (
    [ "$locked" -eq 0 ] && trap '_mneme_md_unlock "$index"' EXIT
    local tmp; tmp="$(mktemp "$dir/.index.XXXXXX")"  # same dir → mv is atomic rename; no .md suffix → invisible to drift glob
    grep -vF "($file)" "$index" > "$tmp" 2>/dev/null || true
    printf -- '- [%s](%s) — %s\n' "$title" "$file" "$desc" >> "$tmp"
    mv "$tmp" "$index"
  )
}

mneme_md_index_remove() {
  local dir="$1" file="$2" index="$1/INDEX.md"
  [ -f "$index" ] || return 0
  _mneme_md_lock "$index"; local locked=$?
  (
    [ "$locked" -eq 0 ] && trap '_mneme_md_unlock "$index"' EXIT
    local tmp; tmp="$(mktemp "$dir/.index.XXXXXX")"
    grep -vF "($file)" "$index" > "$tmp" 2>/dev/null || true
    mv "$tmp" "$index"
  )
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
