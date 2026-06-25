---
description: Search the Mneme cache and surface matching notes
argument-hint: "<query>"
allowed-tools: Bash, Read, Glob, Grep
---

You are running the Mneme `/recall` command. Search the cache for: $ARGUMENTS

Steps:

**Wiki mode.** If the args contain `--wiki <name>`, do NOT search the lean cache. Instead query that corpus: resolve the home under bash (closing `SH` flush-left), then read `index.md` first and the relevant `pages/`, answer with citations to the page paths, and stop. You may offer to file the answer back as a new page in that corpus (`mneme_log_append "<corpus>" recall-filed "<slug>"`). Otherwise (no `--wiki`), do the cache search below.

```bash
bash <<'SH'
mneme_lib="${CLAUDE_PLUGIN_ROOT:-}/hooks/scripts/lib"
[ -f "$mneme_lib/log.sh" ] || mneme_lib="$(dirname "$(find "$HOME/.claude/plugins" -path '*/mneme/hooks/scripts/lib/log.sh' 2>/dev/null | head -1)")"
. "$mneme_lib/wiki.sh"; echo "corpus: $(mneme_wiki_home)/<name>"
SH
```

1. Search both caches for the query (case-insensitive), across note bodies and descriptions:
   - global: `~/.claude/mneme/cache/` (i.e. `$HOME/.claude/mneme/cache/`)
   - project (only if it exists): `./.mneme/cache/`
   Use Grep over the `*.md` files.

2. Rank matches by relevance. For the top matches, show: the note Title, its one-line description, the file path, and the matching snippet.

3. If a top match clearly answers the query, Read it fully and give the answer.

4. If nothing matches, say so plainly and suggest the closest related notes by topic, if any.

5. **Offer to file the answer back** — only when you synthesized across **≥2 notes**. If answering required combining two or more notes, end by offering to save that synthesis as a new note (`reference` or `pattern`), cross-referenced to its sources. This is opt-in: do nothing unless the user confirms. On confirmation, prefer `/mneme:remember "<the synthesis>"` (it applies the gate, dedupes, cross-refs, and logs); or, if writing the note directly, also `mneme_log_append "<cache-dir>" recall-filed "<slug>"`. If you did not combine multiple notes, skip this step.

Keep the output scannable. Recall is **read-only** by default — never modify a file unless the user accepts the file-back offer above.
