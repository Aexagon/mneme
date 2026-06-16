#!/usr/bin/env bash
# Mneme — SessionStart cache loader.
# Injects the global cache index (+ project overlay, if present) and the loop
# protocol into every chat as additionalContext (Claude Code SessionStart format).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GLOBAL_CACHE="${MNEME_GLOBAL_DIR:-$HOME/.claude/mneme/cache}"
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
PROJECT_CACHE="$PROJECT_ROOT/.mneme/cache"
PROTOCOL_FILE="$SCRIPT_DIR/protocol-snippet.md"

if command -v python3 >/dev/null 2>&1; then
  python3 - "$GLOBAL_CACHE" "$PROJECT_CACHE" "$PROTOCOL_FILE" <<'PY' || exit 0
import json, os, sys

global_cache, project_cache, protocol_file = sys.argv[1], sys.argv[2], sys.argv[3]
MAX_CHARS = 16000  # lean-index guard: never flood the context window

def read(path):
    try:
        with open(path, "r", encoding="utf-8") as f:
            return f.read().strip()
    except OSError:
        return ""

def strip_h1(text):
    # Drop a leading markdown H1 so the loader supplies the only section header.
    lines = text.split("\n")
    if lines and lines[0].lstrip().startswith("# "):
        lines = lines[1:]
        while lines and lines[0].strip() == "":
            lines = lines[1:]
    return "\n".join(lines).strip()

parts = []

protocol = read(protocol_file)
if protocol:
    parts.append(protocol)

gi = strip_h1(read(os.path.join(global_cache, "INDEX.md")))
if gi:
    parts.append("# Mneme cache (global)\n\n" + gi)
else:
    parts.append("# Mneme cache (global)\n\n(empty - nothing saved yet. Save durable, reusable learnings with /mneme:remember.)")

pi = strip_h1(read(os.path.join(project_cache, "INDEX.md")))
if pi:
    parts.append("# Mneme cache (this project)\n\n" + pi)

context = "\n\n---\n\n".join(parts)
if len(context) > MAX_CHARS:
    context = context[:MAX_CHARS] + "\n\n[...Mneme index truncated - run /mneme:status to prune.]"

print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": context,
    }
}))
PY
else
  # Fallback when python3 is unavailable: plain-text stdout (Claude Code injects it).
  [ -f "$PROTOCOL_FILE" ] && cat "$PROTOCOL_FILE" && echo
  if [ -f "$GLOBAL_CACHE/INDEX.md" ]; then
    cat "$GLOBAL_CACHE/INDEX.md"; echo
  fi
  if [ -f "$PROJECT_CACHE/INDEX.md" ]; then
    echo "## Project overlay"; cat "$PROJECT_CACHE/INDEX.md"; echo
  fi
fi
