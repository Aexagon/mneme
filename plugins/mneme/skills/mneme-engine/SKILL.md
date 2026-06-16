---
name: mneme-engine
description: The Mneme self-improving cache protocol — how to read the cache, when to save a learning (the relevance gate), the note schema, the lean-index and dedupe rules, and how skills read/write the cache. Use when capturing a learning to Mneme, writing a cache note by hand, pruning the cache, or building a skill that reads or writes Mneme.
---

# Mneme engine — the loop protocol

Mneme makes Claude Code compound: a persistent cache loads into every chat, and each chat can write durable learnings back so the next chat starts ahead. This skill is the manual for doing that well.

## Where the cache lives

- **Global** (loads in every chat on this machine): `~/.claude/mneme/cache/`
- **Project overlay** (loads on top, when present): `<project>/.mneme/cache/`
- Each cache dir has an `INDEX.md` (the lean, always-loaded summary) plus one file per note.
- This is separate from Claude Code's built-in auto-memory. Do not conflate them.

## The loop

1. **Load** — the SessionStart hook injects both INDEX.md files + this protocol at the start of every chat. The index is what you always see; note bodies are read on demand.
2. **Use** — treat the loaded notes as known context. Read a full note file when its index line is relevant to the task.
3. **Capture** — when you learn something worth keeping, write it back (see the gate below).
4. **Grow** — the next chat loads the bigger, better cache.

## The relevance gate (the single most important rule)

Before writing ANYTHING, ask: **would this help a different future chat?**
A learning qualifies only if it is both:
- **Durable** — still true tomorrow and next month, not a transient detail of this chat.
- **Reusable** — useful beyond this one conversation (a fact, a preference, a repeatable pattern, a reference), not a one-off result.

If it fails either test, do not save it. A cache full of junk is worse than a small one: the index gets long, and a long index stops loading.

Good saves: a stable preference ("Jerry wants bullets, not prose"), a hard-won fact about a system, a reusable procedure, a pointer to a resource.
Bad saves: "the build passed just now", "the file is currently open", anything tied to this chat only.

## Note schema

One fact per file. Filename: `<type>-<kebab-slug>.md`.

```
---
name: <kebab-slug>
description: <one line — this is exactly what shows in INDEX.md>
type: fact | preference | pattern | reference | project
---
<the durable, reusable content. Keep it tight. Link related notes with [[other-slug]].>
```

Types:
- **fact** — something true about the world, a system, a person.
- **preference** — how the user wants things done.
- **pattern** — a reusable procedure or playbook ("how to do X").
- **reference** — a pointer to a resource (path, URL, tool, doc).
- **project** — ongoing work, goals, or constraints not derivable from the code.

## INDEX.md — keep it lean

`INDEX.md` is injected into every chat, so it is the budget that matters. Rules:
- One bullet per note: `- [<Title>](<file>.md) — <description>`.
- Put detail in the note body, never in the index line.
- If the index grows past ~300 lines or ~16 KB, prune (run `/mneme:status prune`). Past that size Claude Code truncates it and the cache silently stops loading.

## Dedupe on write

Before creating a note, glob the cache dir and grep for the same topic. If a note already covers it, UPDATE that file (and its index line) instead of adding a near-duplicate. Merge, do not multiply.

## Pruning

Periodically remove: near-duplicates, notes that are no longer true, and low-value notes that never get used. Always confirm with the user before deleting. Keep the index honest.

## How a skill reads or writes the cache

Any skill in the bay can join the loop:
- **Read:** glob `~/.claude/mneme/cache/*.md` (and the project overlay) and read the notes relevant to its job. The index lines are already in context.
- **Write:** follow the schema above, or just call `/mneme:remember "<learning>"`, which applies the gate, dedupes, writes the note, and updates the index for you.

## Automatic capture — the distiller (off by default)

A background distiller can catch learnings on chats where nobody saved anything. It is **off until you enable it**, and it never writes straight into the trusted cache.

- **Trigger:** `SessionEnd`. When a session closes, the distiller reads the transcript.
- **Model:** Sonnet (`claude-sonnet-4-6`), run headless. It applies the same relevance gate and is shown the current index so it dedupes instead of piling on.
- **Propose, don't commit:** distilled notes land in a **pending tray** at `~/.claude/mneme/cache/_pending/` with `source: auto` in their frontmatter. The loader does NOT inject pending notes, so unconfirmed material never pollutes a chat. Review with `/mneme:review` to promote or discard each.
- **Recursion guard:** the headless call sets `MNEME_DISTILL=1`; the distiller exits immediately if it sees that var, so the child session can never re-trigger it.
- **Enable:** `echo 'distill=on' >> ~/.claude/mneme/config` (or set `MNEME_DISTILL_ENABLED=1`). Disable by removing that line.

## The loop engine

`/mneme:loop` drives a single goal to completion: it primes from the cache, then runs plan -> act -> verify -> repeat against a success criterion YOU state, capturing learnings each pass. It is the active counterpart to the cache. The cache is memory across chats (the outer loop); the loop engine is iterate-to-done within a task (the inner loop). Because each pass reads and writes the cache, the same goal run twice gets faster and future tasks inherit what it learned. It always stops honestly: success (verified), stuck (no progress, it asks for help), or incomplete (hit the iteration cap).

## Commands

- `/mneme:remember "<learning>" [--project]` — save a learning (applies the gate + dedupe).
- `/mneme:recall "<query>"` — search the cache.
- `/mneme:status [prune] [--project]` — status, health, auto-capture state, and pruning.
- `/mneme:review` — review pending auto-distilled notes; promote or discard each.
- `/mneme:loop "<goal>" --done "<criterion>" [--max N]` — drive a goal to completion, verifying each pass.
