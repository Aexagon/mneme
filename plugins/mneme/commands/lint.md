---
description: Audit the Mneme cache for dead links, orphans, INDEX drift, and contradictions — read-only, fixes only on confirmation
argument-hint: "[--project]"
allowed-tools: Bash, Read, Glob, Grep, Edit
---

You are running the Mneme `/mneme:lint` command. Audit the cache and produce a **read-only** report; apply fixes only after the user confirms.

Args: $ARGUMENTS

1. **Scope.** Default target is the global cache `~/.claude/mneme/cache/` (i.e. `$HOME/.claude/mneme/cache/`). If the args contain `--project`, target `./.mneme/cache/` instead. (Wiki and spine targets arrive with those tiers in later phases.)

2. **Run the mechanical checks under bash.** The helpers are bash functions and your default shell may be zsh, so invoke bash explicitly and keep the closing `SH` flush-left. Substitute `<cache-dir>` and read the output:

```bash
bash <<'SH'
mneme_lib="${CLAUDE_PLUGIN_ROOT:-}/hooks/scripts/lib"
[ -f "$mneme_lib/log.sh" ] || mneme_lib="$(dirname "$(find "$HOME/.claude/plugins" -path '*/mneme/hooks/scripts/lib/log.sh' 2>/dev/null | head -1)")"
. "$mneme_lib/md.sh"; . "$mneme_lib/links.sh"; . "$mneme_lib/log.sh"
echo "== dead links =="; mneme_links_dead "<cache-dir>"
echo "== orphans ==";     mneme_links_orphans "<cache-dir>"
echo "== index drift =="; mneme_md_index_drift "<cache-dir>"
SH
```

   - Dead links: `[[slug]]` targets with no matching note.
   - Orphans: notes nothing links to.
   - INDEX drift: `missing-file:` (an index entry with no file) and `unindexed:` (a note file with no index line).

3. **Semantic checks** (you judge these by reading the notes — the lib cannot):
   - Contradictions: two notes that assert opposing things.
   - Stale claims: notes that fail the durability test (no longer true).
   - Concept gaps: a concept referenced across notes that has no note of its own.

4. **Report**, grouped by check, with a one-line reason and the proposed fix for each finding. Change nothing yet — this stays **read-only** until the user confirms.

5. **On confirmation only**, apply the accepted fixes (add a missing `[[link]]`, drop a dead one, reconcile a contradiction, upsert/remove an INDEX line). Log each with `mneme_log_append "<cache-dir>" lint-fix "<slug>"` (run under `bash` as above). Never edit or delete without explicit confirmation.

This is the heavy audit; `/mneme:status prune` stays the light pass.
