---
description: Search the Mneme cache and surface matching notes
argument-hint: "<query>"
allowed-tools: Bash, Read, Glob, Grep
---

You are running the Mneme `/recall` command. Search the cache for: $ARGUMENTS

Steps:

1. Search both caches for the query (case-insensitive), across note bodies and descriptions:
   - global: `~/.claude/mneme/cache/` (i.e. `$HOME/.claude/mneme/cache/`)
   - project (only if it exists): `./.mneme/cache/`
   Use Grep over the `*.md` files.

2. Rank matches by relevance. For the top matches, show: the note Title, its one-line description, the file path, and the matching snippet.

3. If a top match clearly answers the query, Read it fully and give the answer.

4. If nothing matches, say so plainly and suggest the closest related notes by topic, if any.

Keep the output scannable. Do NOT modify any files.
