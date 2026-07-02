# mneme (plugin)

The Mneme plugin: a SessionStart hook that loads a persistent cache into every chat, a SessionEnd distiller that auto-captures learnings to the inbox, seven commands spanning the memory and knowledge tiers, and three skills.

- `hooks/scripts/load-cache.sh` — injects the cache index (global + project overlay) + the loop protocol at session start.
- `hooks/scripts/distill.sh` — SessionEnd background distiller (ON by default): proposes auto-notes into `~/.claude/mneme/inbox/` for `/mneme:review`. Disable with `distill=off` in `~/.claude/mneme/config`.
- `commands/remember.md` — `/mneme:remember "<learning>"`, applies the relevance gate, dedupes, writes a note, updates the index.
- `commands/recall.md` — `/mneme:recall "<query>"`, searches the cache (or a wiki corpus with `--wiki <name>`).
- `commands/status.md` — `/mneme:status [prune]`, health and pruning.
- `commands/review.md` — `/mneme:review`, pull the inbox: promote or discard auto-distilled notes.
- `commands/lint.md` — `/mneme:lint [--project | --wiki <name>]`, read-only audit for dead links, orphans, and index drift; fixes only on confirmation.
- `commands/ingest.md` — `/mneme:ingest <source> [--wiki <name>]`, ingest a file or URL into a wiki (Tier 2 knowledge).
- `commands/loop.md` — `/mneme:loop "<goal>" --done "<criterion>"`, drive one goal to completion, verifying each pass.
- `skills/mneme-engine` — the full cache protocol (schema, gate, lean-index + dedupe rules).
- `skills/mneme-wiki` — the knowledge-tier protocol: how a wiki corpus is built, queried, and audited.
- `skills/new-skill` — scaffold a new skill and wire it to the cache.

Cache data (Tier 1 memory) lives OUTSIDE this plugin: `~/.claude/mneme/cache/` (global), `<project>/.mneme/cache/` (project), and the auto-capture inbox `~/.claude/mneme/inbox/` (notes awaiting `/mneme:review`). Wiki data (Tier 2 knowledge) lives alongside it as a sibling of `cache/`: `~/.claude/mneme/wiki/` (global) and `<project>/.mneme/wiki/` (project). Updating or reinstalling the plugin never touches any of it.

See the repo root `README.md` for install + usage, or `docs/explainer/index.html` for the full manual.
