---
description: Audit the Mneme cache for dead links, orphans, INDEX drift, and contradictions — read-only, fixes only on confirmation
argument-hint: "[--project]"
allowed-tools: Bash, Read, Glob, Grep, Edit
---

You are running the Mneme `/mneme:lint` command. Audit the cache and produce a **read-only** report; apply fixes only after the user confirms.

Args: $ARGUMENTS

1. **Scope.** Default target is the global cache `~/.claude/mneme/cache/` (i.e. `$HOME/.claude/mneme/cache/`). If the args contain `--project`, target `./.mneme/cache/` instead. (Wiki and spine targets arrive with those tiers in later phases.)

2. **Resolve the lib:**
   ```bash
   mneme_lib="${CLAUDE_PLUGIN_ROOT:-}/hooks/scripts/lib"
   [ -f "$mneme_lib/log.sh" ] || mneme_lib="$(dirname "$(find "$HOME/.claude/plugins" -path '*/mneme/hooks/scripts/lib/log.sh' 2>/dev/null | head -1)")"
   . "$mneme_lib/md.sh"; . "$mneme_lib/links.sh"; . "$mneme_lib/log.sh"
   ```

3. **Mechanical checks** (run against `<cache-dir>`, report each finding):
   - Dead links: `mneme_links_dead "<cache-dir>"` — `[[slug]]` targets with no matching note.
   - Orphans: `mneme_links_orphans "<cache-dir>"` — notes nothing links to.
   - INDEX drift: `mneme_md_index_drift "<cache-dir>"` — `missing-file:` (index entry, no file) and `unindexed:` (file, no index line).

4. **Semantic checks** (you judge these by reading the notes — the lib cannot):
   - Contradictions: two notes that assert opposing things.
   - Stale claims: notes that fail the durability test (no longer true).
   - Concept gaps: a concept referenced across notes that has no note of its own.

5. **Report**, grouped by check, with a one-line reason and the proposed fix for each finding. Change nothing yet.

6. **On confirmation only**, apply the accepted fixes (add a missing `[[link]]`, drop a dead one, reconcile a contradiction, upsert/remove an INDEX line). For each fix, `mneme_log_append "<cache-dir>" lint-fix "<slug>"`. Never edit or delete without explicit confirmation.

This is the heavy audit; `/mneme:status prune` stays the light pass.
