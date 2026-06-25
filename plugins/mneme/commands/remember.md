---
description: Save a durable, reusable learning to the Mneme cache (global, or project with --project)
argument-hint: "\"<the learning>\" [--project]"
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

You are running the Mneme `/remember` command. Save the learning below to the cache as one atomic note, following the Mneme conventions.

LEARNING (raw args): $ARGUMENTS

Steps:

1. **Scope.** If the args contain `--project`, the target cache is `./.mneme/cache/` (relative to the current working directory; create it if missing). Otherwise the target is the global cache `~/.claude/mneme/cache/` (i.e. `$HOME/.claude/mneme/cache/`). Strip the `--project` flag out of the learning text.

2. **Relevance gate.** Decide: would this help a *different future chat*? It must be **durable** (still true later) AND **reusable** (not a throwaway detail of this one conversation).
   - If it FAILS the gate, do not write anything. Tell the user why in one line and stop.
   - If it PASSES, continue.

3. **Classify** the note `type` as one of: `fact`, `preference`, `pattern`, `reference`, `project`.

4. **Dedupe.** Glob the target cache dir for existing `*.md` notes and Grep for the same topic. If a note already covers this, UPDATE that file instead of creating a new one. Otherwise create a new file named `<type>-<kebab-slug>.md`.

5. **Write the note** with this exact frontmatter + body:
   ```
   ---
   name: <kebab-slug>
   description: <one line; this is what shows in the index>
   type: <type>
   ---
   <the durable, reusable content. Link related notes with [[other-slug]].>
   ```

6. **Update the index** `INDEX.md` in the target cache dir: add (or update) one bullet:
   `- [<Title>](<filename>.md) — <description>`
   If `INDEX.md` does not exist, create it with a `# Mneme cache` header first. One line per note.

7. **Cross-reference + log the save.** Pick at most **3** existing notes most genuinely related to this one (shared terms in the description/body, or the same `type`); add nothing if there is no real relation, and never exceed 3 touched notes (the index stays lean). Then run the reciprocal links and the log as ONE command. The helpers are bash functions and your default shell may be zsh, so invoke bash explicitly and keep the closing `SH` flush-left:

```bash
bash <<'SH'
mneme_lib="${CLAUDE_PLUGIN_ROOT:-}/hooks/scripts/lib"
[ -f "$mneme_lib/log.sh" ] || mneme_lib="$(dirname "$(find "$HOME/.claude/plugins" -path '*/mneme/hooks/scripts/lib/log.sh' 2>/dev/null | head -1)")"
. "$mneme_lib/md.sh"; . "$mneme_lib/links.sh"; . "$mneme_lib/log.sh"
# reciprocal links, both directions, for each related note (<=3):
mneme_links_add "<this-note-file>" "<their-slug>"; mneme_links_add "<their-note-file>" "<this-slug>"
# record the save (appends to log.md, which is never injected):
mneme_log_append "<target-cache-dir>" remember "<this-slug>"
SH
```

If `mneme_lib` does not resolve (empty), add the `[[slug]]` links by hand with Edit and skip the log.

8. **Confirm** to the user in one or two lines: the note path, whether it was created or updated, the description, and any notes it was cross-linked to.

Lean-index rule: the index is injected into every chat, so keep descriptions tight and never let a note's body sprawl. One fact per file.
