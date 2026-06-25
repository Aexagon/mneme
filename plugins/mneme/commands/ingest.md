---
description: Ingest a source (file or URL) into a Mneme wiki — a per-corpus knowledge base read on demand, never injected
argument-hint: "<source> [--wiki <name>] [--project]"
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, WebFetch
---

You are running `/mneme:ingest`. Add a source to a **wiki** (Tier 2 knowledge): a per-corpus markdown knowledge base, read on demand and NEVER injected into a chat. Unlike the lean cache, a wiki can be large. Governed by the `mneme-wiki` skill.

Args: $ARGUMENTS

1. **Parse args.** `<source>` is a file path or URL. `--wiki <name>` names the corpus (default `general`). `--project` targets the project wiki `./.mneme/wiki/` instead of the global wiki home.

2. **Make the corpus** (helpers are bash; your default shell may be zsh, so invoke bash explicitly, closing `SH` flush-left). For `--project`, replace `$(mneme_wiki_home)` with `./.mneme/wiki`:

```bash
bash <<'SH'
mneme_lib="${CLAUDE_PLUGIN_ROOT:-}/hooks/scripts/lib"
[ -f "$mneme_lib/log.sh" ] || mneme_lib="$(dirname "$(find "$HOME/.claude/plugins" -path '*/mneme/hooks/scripts/lib/log.sh' 2>/dev/null | head -1)")"
. "$mneme_lib/wiki.sh"
corpus="$(mneme_wiki_home)/<name>"
mkdir -p "$corpus/sources" "$corpus/pages"
[ -f "$corpus/index.md" ] || printf '# Wiki: <name>\n\n## Pages\n\n## Entities\n\n## Concepts\n' > "$corpus/index.md"
echo "$corpus"
SH
```

3. **Bring in the source.** Save the raw source under `<corpus>/sources/`. For rich files (PDF, DOCX, PPTX, XLSX, images, audio, HTML, YouTube/Wikipedia URLs), run `markitdown <source>` first and save the converted markdown alongside the raw. For a plain web URL, fetch it. For plain text/markdown, copy as-is.

4. **Read + summarize.** Read the converted source and discuss the key takeaways. Write a **summary page** at `<corpus>/pages/<slug>.md` (frontmatter `name`/`description`/`type`, like a note, but the body may be long). Create or update **entity** and **concept** pages it touches (one page each), cross-linking with `[[slug]]`. 10–15 pages per source is fine — the wiki never loads into a chat.

5. **Update `<corpus>/index.md`** — add the new page(s) under the right section (Pages / Entities / Concepts).

6. **Log it** under bash:

```bash
bash <<'SH'
mneme_lib="${CLAUDE_PLUGIN_ROOT:-}/hooks/scripts/lib"
[ -f "$mneme_lib/log.sh" ] || mneme_lib="$(dirname "$(find "$HOME/.claude/plugins" -path '*/mneme/hooks/scripts/lib/log.sh' 2>/dev/null | head -1)")"
. "$mneme_lib/log.sh"; mneme_log_append "<corpus>" ingest "<slug>"
SH
```

7. **Confirm**: the corpus path, the pages written, and that it is queryable with `/mneme:recall "<q>" --wiki <name>`.
