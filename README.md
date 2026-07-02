# Mneme

A self-improving engine for Claude Code. Install it once and every chat starts knowing what past chats learned, because Mneme loads a persistent cache into each session and writes new, durable learnings back to it.

For the full plain-language walkthrough, open `docs/explainer/index.html` in your browser.

## What you get

- **A cache that lives in all chats.** A SessionStart hook loads a global cache (and an optional per-project overlay) into every conversation.
- **A learning loop.** Save durable, reusable learnings as you work or on command, and the next chat starts ahead.
- **A knowledge tier (wiki).** Ingest whole documents into a per-topic wiki and query it on demand — it never gets injected wholesale, so it can be as big as you need.
- **A skill bay.** Drop skills in and they are auto-discovered; skills can read and write the same cache.

## Install

```
/plugin marketplace add Aexagon/mneme
/plugin install mneme@mneme
```

Restart the session. You should see the Mneme cache load at the top of the chat.

## Use

- `/mneme:remember "<learning>" [--project]` — save a durable, reusable learning.
- `/mneme:recall "<query>"` — search the cache. Add `--wiki <name>` to query a knowledge-tier corpus instead (e.g. `/mneme:recall "refund policy" --wiki handbook`).
- `/mneme:status [prune]` — status, health, and pruning.
- `/mneme:review` — pull the inbox: review notes the auto-distiller proposed (on by default; see below).
- `/mneme:lint [--project | --wiki <name>]` — read-only audit for dead links, orphan notes, and index drift; fixes only on confirmation.
- `/mneme:ingest <source> [--wiki <name>] [--project]` — ingest a file or URL into a wiki (Tier 2 knowledge).
- `/mneme:loop "<goal>" --done "<criterion>"` — drive a goal to completion, verifying each pass.

## The loop engine

Memory is the outer loop (every new chat starts smarter). `/mneme:loop` is the inner loop: it drives one goal to completion in the current chat.

```
/mneme:loop "make the test suite green" --done "npm test exits 0" --max 8
```

It primes from the cache, then runs plan -> act -> verify -> repeat against the success criterion YOU state, capturing learnings each pass. It stops honestly: success (verified against your criterion), stuck (no progress, it asks rather than spins), or incomplete (hit the cap, reports what is left). Because each pass reads and writes the cache, the same goal run twice gets faster, and future tasks inherit what it learned.

## How it works

- **Code** lives in the plugin. **Data** (the cache) lives outside it, at `~/.claude/mneme/cache/` (global) and `<project>/.mneme/cache/` (project overlay), so updating the plugin never wipes your memory.
- The cache is small atomic notes plus a lean `INDEX.md`. The index is injected into every chat, so it is kept short by design; note bodies are read on demand.
- Capture is **manual** (`/mneme:remember`) and **inline** (the agent saves durable learnings as it works), plus an optional **automatic distiller** (below).

### Two tiers: memory and knowledge

Mneme keeps two different kinds of information, on purpose, so neither one bloats the other:

- **Tier 1 — memory (the cache).** Small, durable notes — facts, preferences, patterns. Kept lean on purpose and **injected into every chat** via `INDEX.md`, so Claude always has it without asking.
- **Tier 2 — knowledge (the wiki).** Whole documents you `/mneme:ingest` into a named corpus (a handbook, a policy doc, a project spec). It can be as large as you need, and is **read on demand** with `/mneme:recall --wiki <name>` — it is never dumped into a chat wholesale, only named so you know it is there.

Rule of thumb: save a one-line fact or preference to the cache; ingest a whole document into a wiki.

## Automatic capture (on by default)

A background distiller catches learnings on sessions where nobody saved anything. It ships **on**; disable with `echo 'distill=off' >> ~/.claude/mneme/config`.

- Fires on **SessionEnd**, reads the transcript, and asks **Sonnet** (`claude-sonnet-4-6`) to extract only durable, reusable notes (same relevance gate, deduped against the index). Trivially short sessions are skipped (no model call).
- It **captures to an inbox, you pull on demand:** notes land as markdown in `~/.claude/mneme/inbox/` and are never injected into chats. Pull anytime with `/mneme:review`, or just open the folder — promote what you want into the live cache, discard the rest.
- A recursion guard stops the headless model call from re-triggering the distiller.

## The two rules that keep it healthy

1. **Relevance gate:** only save what would help a *different future chat*. Durable AND reusable.
2. **Lean index:** one fact per file; keep `INDEX.md` short or it stops loading.

See the `mneme-engine` skill for the full protocol.

## Layout

```
mneme/                                  (git repo = marketplace)
  .claude-plugin/marketplace.json
  docs/explainer/                       full plain-language manual (index.html)
  plugins/mneme/
    .claude-plugin/plugin.json
    hooks/         hooks.json + scripts/ (load-cache.sh, distill.sh) + protocol-snippet.md
    commands/      remember.md, recall.md, status.md, review.md, lint.md, ingest.md, loop.md
    skills/        mneme-engine/, mneme-wiki/, new-skill/
    README.md
```
