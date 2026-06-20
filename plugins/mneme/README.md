# mneme (plugin)

The Mneme plugin: a SessionStart hook that loads a persistent cache into every chat, five commands for the learning loop, and two skills.

- `hooks/scripts/load-cache.sh` — injects the cache index (global + project overlay) + the loop protocol at session start.
- `commands/remember.md` — `/mneme:remember "<learning>"`, applies the relevance gate, dedupes, writes a note, updates the index.
- `commands/recall.md` — `/mneme:recall "<query>"`, searches the cache.
- `commands/status.md` — `/mneme:status [prune]`, health and pruning.
- `commands/review.md` — `/mneme:review`, promote or discard auto-distilled notes from the pending tray.
- `commands/loop.md` — `/mneme:loop "<goal>" --done "<criterion>"`, drive one goal to completion, verifying each pass.
- `skills/mneme-engine` — the full cache protocol (schema, gate, lean-index + dedupe rules).
- `skills/new-skill` — scaffold a new skill and wire it to the cache.

Cache data lives OUTSIDE this plugin: `~/.claude/mneme/cache/` (global) and `<project>/.mneme/cache/` (project). Updating or reinstalling the plugin never touches it.

See the repo root `README.md` for install + usage.
