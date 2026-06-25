#!/usr/bin/env bash
# Mneme shared engine: append-only timeline. Never injected into a chat.
mneme_log_append() {
  local dir="$1" op="$2" slug="$3" note="${4:-}"
  local log="$dir/log.md" today
  [ -d "$dir" ] || mkdir -p "$dir"
  [ -f "$log" ] || printf '# Mneme log\n\n' > "$log"
  today="$(date '+%Y-%m-%d' 2>/dev/null || echo unknown)"
  if [ -n "$note" ]; then
    printf '## [%s] %s | %s — %s\n' "$today" "$op" "$slug" "$note" >> "$log"
  else
    printf '## [%s] %s | %s\n' "$today" "$op" "$slug" >> "$log"
  fi
}

# Last n (default 5) timeline entries. Empty if the log does not exist yet.
mneme_log_tail() {
  local dir="$1" n="${2:-5}"
  grep '^## \[' "$dir/log.md" 2>/dev/null | tail -n "$n"
}
