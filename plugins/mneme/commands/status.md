---
description: Mneme status and health, with optional prune (cache stats, recent notes, remove stale/duplicate notes)
argument-hint: "[prune] [--project]"
allowed-tools: Bash, Read, Glob, Grep, Edit
---

You are running the Mneme `/status` command. Default action: STATUS. If the args contain `prune`, also run PRUNE. Scope is global unless `--project` is present (then `./.mneme/cache/`).

Args: $ARGUMENTS

**STATUS** — report:
- Cache location(s) in use (global at `~/.claude/mneme/cache/`, and the project overlay `./.mneme/cache/` if present).
- Note count, total size, and `INDEX.md` size in lines + KB.
- The 5 most recently modified notes (name + description).
- Health flag: if `INDEX.md` exceeds ~300 lines or ~16 KB, warn that it is approaching the size where Claude Code stops loading it, and recommend pruning (the lean-index rule).
- Auto-capture state: report ON or OFF. It is **ON by default**; it is OFF only if `~/.claude/mneme/config` contains `distill=off` (or `MNEME_DISTILL_ENABLED=0`). If ON, give the one-liner to disable it: `echo 'distill=off' >> ~/.claude/mneme/config`. If OFF, the one-liner to re-enable: remove that line.
- Inbox: count auto-distilled notes waiting in `~/.claude/mneme/inbox/*.md` (also the legacy `~/.claude/mneme/cache/_pending/*.md` if it still exists; ignore `_`-prefixed files). If any, prompt the user to run `/mneme:review` to pull them.
- One line on how the loop works: notes here load into every chat; save with `/mneme:remember`, search with `/mneme:recall`.

**PRUNE** (only if requested) — propose, then act on confirmation:
- Identify candidates: near-duplicates, notes that are no longer true (failed the durability test), and very low-value notes that never get used.
- Show the candidate list with a one-line reason each. Ask the user to confirm before deleting anything.
- On confirmation, delete the confirmed notes and update `INDEX.md` to match.

Never delete without explicit confirmation.
