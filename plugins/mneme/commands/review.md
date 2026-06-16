---
description: Review auto-distilled notes waiting in the Mneme pending tray; confirm or reject each before they enter the trusted cache
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

You are running `/mneme:review`. The background distiller *proposes* notes into a pending tray; you decide what enters the trusted cache. Nothing here has been trusted yet.

1. List the pending notes in `~/.claude/mneme/cache/_pending/*.md` (i.e. `$HOME/.claude/mneme/cache/_pending/`). Ignore files whose names start with `_`. For each, show: name, type, one-line description, and a short preview of the body. If there are none, say "No pending notes to review." and stop.

2. Ask the user which to KEEP (promote) and which to DISCARD. Accept "keep all", "discard all", or a specific selection.

3. For each KEPT note:
   - Apply the relevance gate once more (durable AND reusable in a different future chat). If it fails, recommend discarding instead.
   - DEDUPE against the main cache (`~/.claude/mneme/cache/*.md`): if an existing note already covers it, merge/update that note rather than adding a duplicate.
   - Otherwise move the file from `_pending/` into the main cache (you may keep the `source: auto` line as provenance), and add one line to `INDEX.md`: `- [<Title>](<file>.md) — <description>`.

4. For each DISCARDED note: delete it from `_pending/`.

5. Confirm what was promoted and what was dropped, in a couple of lines.

Never promote a note without the user's explicit confirmation.
