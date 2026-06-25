---
description: Pull the Mneme inbox — review auto-distilled notes and promote or discard each before they enter the trusted cache
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

You are running `/mneme:review`. The background distiller *proposes* notes into the **inbox**; you decide what enters the trusted cache. Nothing in the inbox has been trusted or injected into any chat yet.

1. List the inbox notes in `~/.claude/mneme/inbox/*.md` (i.e. `$HOME/.claude/mneme/inbox/`). If the legacy tray `~/.claude/mneme/cache/_pending/*.md` still exists, treat those as inbox notes too (move them into `inbox/` first). Ignore files whose names start with `_`. For each, show: name, type, one-line description, and a short preview of the body. If there are none, say "Inbox is empty — nothing to review." and stop.

2. Ask the user which to KEEP (promote) and which to DISCARD. Accept "keep all", "discard all", or a specific selection.

3. For each KEPT note:
   - Apply the relevance gate once more (durable AND reusable in a different future chat). If it fails, recommend discarding instead.
   - DEDUPE against the main cache (`~/.claude/mneme/cache/*.md`): if an existing note already covers it, merge/update that note rather than adding a duplicate.
   - Otherwise move the file from `inbox/` into the main cache (you may keep the `source: auto` line as provenance), add one line to `INDEX.md`: `- [<Title>](<file>.md) — <description>`, and log the promotion. The helper is a bash function and your default shell may be zsh, so run this single command (keep the closing `SH` flush-left):

```bash
bash <<'SH'
mneme_lib="${CLAUDE_PLUGIN_ROOT:-}/hooks/scripts/lib"
[ -f "$mneme_lib/log.sh" ] || mneme_lib="$(dirname "$(find "$HOME/.claude/plugins" -path '*/mneme/hooks/scripts/lib/log.sh' 2>/dev/null | head -1)")"
. "$mneme_lib/log.sh"; mneme_log_append "$HOME/.claude/mneme/cache" promote "<slug>"
SH
```

4. For each DISCARDED note: delete it from `inbox/`.

5. Confirm what was promoted and what was dropped, in a couple of lines.

Never promote a note without the user's explicit confirmation.
