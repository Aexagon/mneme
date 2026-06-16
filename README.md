# Mneme

A self-improving engine for Claude Code. Install it once and every chat starts knowing what past chats learned, because Mneme loads a persistent cache into each session and writes new, durable learnings back to it.

## What you get

- **A cache that lives in all chats.** A SessionStart hook loads a global cache (and an optional per-project overlay) into every conversation.
- **A learning loop.** Save durable, reusable learnings as you work or on command, and the next chat starts ahead.
- **A skill bay.** Drop skills in and they are auto-discovered; skills can read and write the same cache.

## Install

```
/plugin marketplace add <this-repo-url-or-local-path>
/plugin install mneme@mneme
```

Restart the session. You should see the Mneme cache load at the top of the chat.

## Use

- `/mneme:remember "<learning>" [--project]` — save a durable, reusable learning.
- `/mneme:recall "<query>"` — search the cache.
- `/mneme:status [prune]` — status, health, and pruning.

## How it works

- **Code** lives in the plugin. **Data** (the cache) lives outside it, at `~/.claude/mneme/cache/` (global) and `<project>/.mneme/cache/` (project overlay), so updating the plugin never wipes your memory.
- The cache is small atomic notes plus a lean `INDEX.md`. The index is injected into every chat, so it is kept short by design; note bodies are read on demand.
- Capture is **manual** (`/mneme:remember`) and **inline** (the agent saves durable learnings as it works). An automatic background distiller is planned but ships off by default.

## The two rules that keep it healthy

1. **Relevance gate:** only save what would help a *different future chat*. Durable AND reusable.
2. **Lean index:** one fact per file; keep `INDEX.md` short or it stops loading.

See the `mneme-engine` skill for the full protocol.

## Layout

```
mneme/                                  (git repo = marketplace)
  .claude-plugin/marketplace.json
  plugins/mneme/
    .claude-plugin/plugin.json
    hooks/         hooks.json + scripts/load-cache.sh + protocol-snippet.md
    commands/      remember.md, recall.md, status.md
    skills/        mneme-engine/, new-skill/
    README.md
```
