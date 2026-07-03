#!/usr/bin/env bash
# Mneme — SessionStart cache loader.
# Injects the global cache index (+ project overlay, if present) and the loop
# protocol into every chat as additionalContext (Claude Code SessionStart format).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GLOBAL_CACHE="${MNEME_GLOBAL_DIR:-$HOME/.claude/mneme/cache}"
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
PROJECT_CACHE="$PROJECT_ROOT/.mneme/cache"
PROTOCOL_FILE="$SCRIPT_DIR/../../assets/protocol-snippet.md"
WIKI_HOME="${MNEME_WIKI_DIR:-$(dirname "$GLOBAL_CACHE")/wiki}"
PROJECT_WIKI="$PROJECT_ROOT/.mneme/wiki"

if command -v python3 >/dev/null 2>&1; then
  python3 - "$GLOBAL_CACHE" "$PROJECT_CACHE" "$PROTOCOL_FILE" "$WIKI_HOME" "$PROJECT_WIKI" <<'PY' || exit 0
import json, os, sys

global_cache, project_cache, protocol_file = sys.argv[1], sys.argv[2], sys.argv[3]

# Lean-index guard: never flood the context window. Default 16000, overridable per
# machine or per invocation via MNEME_MAX_CHARS. Read from the environment (this
# heredoc is single-quoted, so shell vars do NOT interpolate here); any invalid or
# non-positive value falls back to the default.
try:
    MAX_CHARS = int(os.environ.get("MNEME_MAX_CHARS", "16000"))
    if MAX_CHARS <= 0:
        raise ValueError
except ValueError:
    MAX_CHARS = 16000

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

# Tier 2 notice only: name the corpora, never read their bodies/indexes.
def wiki_names(home):
    out = []
    try:
        for n in sorted(os.listdir(home)):
            if os.path.isfile(os.path.join(home, n, "index.md")):
                out.append(n)
    except OSError:
        pass
    return out
wiki_home, project_wiki = sys.argv[4], sys.argv[5]
corpora = wiki_names(wiki_home) + wiki_names(project_wiki)
if corpora:
    parts.append("# Mneme wikis\n\nWikis: " + ", ".join(corpora) + " — query with /recall --wiki <name>")

# Inbox signal: count auto-captured notes waiting to be folded in (never their bodies).
# This is the cue the protocol uses to OFFER a conversational review — so a
# non-technical user never has to learn /mneme:review. Mirrors review.md's filter
# (*.md, excluding _-prefixed). Bodies are NEVER read here — count only.
try:
    inbox = os.path.join(os.path.dirname(global_cache), "inbox")
    pending = len([f for f in os.listdir(inbox)
                   if f.endswith(".md") and not f.startswith("_")])
except OSError:
    pending = 0
if pending:
    parts.append("# Mneme inbox\n\n%d auto-captured note(s) pending. At a natural "
                 "moment, offer in plain words to fold the useful ones into memory, "
                 "then promote the ones the user approves. Don't make them learn "
                 "\"inbox\" or any command." % pending)

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
