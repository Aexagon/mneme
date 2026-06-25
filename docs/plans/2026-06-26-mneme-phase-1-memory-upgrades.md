# Mneme Phase 1 — Memory upgrades Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire the tested Phase 0 `lib/` engine into the command prompts so the memory tier gains an append-only `log.md`, reciprocal cross-references on `/remember`, a read-only file-the-answer-back on `/recall`, and a new `/mneme:lint` audit — with Mneme otherwise behaving as it does today.

**Architecture:** Phase 1 of the spec at `docs/specs/2026-06-25-mneme-gaps-and-folders-design.md` §6. The mechanical backbone already exists and is unit-tested (`lib/log.sh`, `lib/md.sh`, `lib/links.sh`). This phase adds two more mechanical helpers under TDD (`mneme_log_tail`, `mneme_md_index_drift`), then edits the command markdown prompts (`/remember`, `/recall`, `/status`, `/review`) and adds one new command (`/mneme:lint`) so the agent invokes those helpers. Semantic judgments (what is "related", what is a "contradiction") stay with the agent; the lib is the mechanism. Each prompt edit is guarded by a lightweight structural "wiring test" so the harness catches an accidental un-wiring.

**Tech Stack:** Bash 3.2 (macOS system bash), Python3 (already a loader/distiller dependency), plain-bash test assertions. The command files are Claude Code slash-command prompts (markdown), invoked by the agent with the Bash/Edit tools.

## Global Constraints

- Approach A: do NOT create anything under `~/core`, do NOT move or relocate any cache data.
- Backward compatible: with no `log.md` present and no new flags used, behavior is identical to today. `log.md` is created lazily on first write.
- `log.md` is NEVER injected into a chat. Only `INDEX.md` (and later the spine) load. The Phase 0 loader test already locks this; do not change `load-cache.sh` in this phase.
- Commands stay flat under `commands/` (subfolders would rename `/mneme:<x>`). The one new command is `commands/lint.md` → `/mneme:lint`.
- Plugin version stays `0.2.0` (the bump to `0.3.0` is Phase 4). Do NOT edit `plugin.json`.
- Cross-ref on `/remember` touches at most **3** related notes (protects the lean index).
- `/recall` stays read-only unless the user explicitly accepts the file-back offer.
- `/mneme:lint` is read-only; it applies fixes only on explicit confirmation.
- Wiki (`--wiki`) and spine (`--spine`) lint targets are OUT of Phase 1 — they arrive with their tiers in Phases 2 and 3. Phase 1 lint targets the cache (default) and `--project`.
- Work on the existing branch `phase-0-foundation` (it carries the Phase 0 foundation this phase builds on). Commits are local checkpoints only; do NOT push without Jerry's explicit say-so.
- Throwaway dirs for all tests: `mktemp -d`; never touch `~/.claude/mneme`.
- `bash tests/run.sh` must be green at every task boundary (Phase 0 left it at `pass=7 fail=0`).

## The lib resolver (used by every command edit)

Slash-command prompts must locate the plugin's `lib/` at runtime. Every command edit below uses this exact, env-first-with-discovery-fallback snippet (3.2-safe). If resolution fails, the prompt instructs the agent to fall back to doing the file edit by hand, so the command degrades gracefully:

```bash
mneme_lib="${CLAUDE_PLUGIN_ROOT:-}/hooks/scripts/lib"
[ -f "$mneme_lib/log.sh" ] || mneme_lib="$(dirname "$(find "$HOME/.claude/plugins" -path '*/mneme/hooks/scripts/lib/log.sh' 2>/dev/null | head -1)")"
. "$mneme_lib/md.sh"; . "$mneme_lib/links.sh"; . "$mneme_lib/log.sh"
```

## File Structure

- `plugins/mneme/hooks/scripts/lib/log.sh` — ADD `mneme_log_tail`.
- `plugins/mneme/hooks/scripts/lib/md.sh` — ADD `mneme_md_index_drift`.
- `plugins/mneme/commands/remember.md` — ADD cross-ref + log steps.
- `plugins/mneme/commands/recall.md` — ADD opt-in file-back step; soften the read-only footer.
- `plugins/mneme/commands/status.md` — ADD recent-activity tail; log prunes; point to `/mneme:lint`.
- `plugins/mneme/commands/review.md` — ADD promote logging.
- `plugins/mneme/commands/lint.md` — NEW command.
- `plugins/mneme/skills/mneme-engine/SKILL.md` — document the log, cross-ref, file-back, and `/mneme:lint`; add `/mneme:lint` to the command list.
- `tests/lib_log_test.sh`, `tests/lib_md_test.sh` — ADD a test for each new helper.
- `tests/cmd_remember_test.sh`, `tests/cmd_recall_test.sh`, `tests/cmd_maintenance_test.sh`, `tests/cmd_lint_test.sh`, `tests/skill_engine_test.sh` — NEW wiring tests.

---

### Task 1: `mneme_log_tail` — last-N log entries

**Files:**
- Modify: `plugins/mneme/hooks/scripts/lib/log.sh`
- Test: `tests/lib_log_test.sh`

**Interfaces:**
- Consumes: `mneme_log_append` (already in `log.sh`).
- Produces: `mneme_log_tail <cache_dir> [n]` — prints the last `n` (default 5) `## [` timeline entries from `<cache_dir>/log.md`; prints nothing if the log is absent.

- [ ] **Step 1: Add the failing test**

Append to `tests/lib_log_test.sh`:

```bash
test_log_tail_returns_last_n() {
  local root tmp; root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  . "$root/plugins/mneme/hooks/scripts/lib/log.sh"
  tmp="$(mktemp -d)"
  mneme_log_append "$tmp" remember note-one
  mneme_log_append "$tmp" remember note-two
  mneme_log_append "$tmp" prune note-three "dup"
  local out; out="$(mneme_log_tail "$tmp" 2)"
  rm -rf "$tmp"
  assert_not_contains "$out" "note-one" "tail 2 drops the oldest entry" || return 1
  assert_contains "$out" "note-two" "tail 2 keeps the second entry" || return 1
  assert_contains "$out" "note-three" "tail 2 keeps the newest entry" || return 1
}
```

- [ ] **Step 2: Run, expect FAIL**

Run: `bash tests/run.sh`
Expected: `NOT - test_log_tail_returns_last_n` (`mneme_log_tail` undefined), `fail>=1`, exit non-zero.

- [ ] **Step 3: Implement**

Append to `plugins/mneme/hooks/scripts/lib/log.sh`:

```bash
# Last n (default 5) timeline entries. Empty if the log does not exist yet.
mneme_log_tail() {
  local dir="$1" n="${2:-5}"
  grep '^## \[' "$dir/log.md" 2>/dev/null | tail -n "$n"
}
```

- [ ] **Step 4: Run, expect PASS**

Run: `bash tests/run.sh`
Expected: `ok - test_log_tail_returns_last_n`, `fail=0`.

- [ ] **Step 5: Commit**

```bash
git add plugins/mneme/hooks/scripts/lib/log.sh tests/lib_log_test.sh
git commit -m "feat(lib): add log.sh mneme_log_tail"
```

---

### Task 2: `mneme_md_index_drift` — INDEX-vs-files drift

**Files:**
- Modify: `plugins/mneme/hooks/scripts/lib/md.sh`
- Test: `tests/lib_md_test.sh`

**Interfaces:**
- Produces: `mneme_md_index_drift <cache_dir>` — prints `missing-file: <name>` for each `(name.md)` referenced in `INDEX.md` with no such file, and `unindexed: <name>` for each note file with no `INDEX.md` line. `INDEX.md`, `log.md`, and `_`-prefixed files are excluded from the note set. Prints nothing when the index and the files agree.

- [ ] **Step 1: Add the failing test**

Append to `tests/lib_md_test.sh`:

```bash
test_md_index_drift() {
  local root tmp; root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  . "$root/plugins/mneme/hooks/scripts/lib/md.sh"
  tmp="$(mktemp -d)"
  printf '# Mneme cache\n\n- [Alpha](fact-alpha.md) — indexed and present\n- [Ghost](fact-ghost.md) — indexed but missing\n' > "$tmp/INDEX.md"
  printf -- '---\nname: alpha\n---\nbody\n' > "$tmp/fact-alpha.md"
  printf -- '---\nname: lonely\n---\nbody\n' > "$tmp/fact-lonely.md"
  printf 'some log line\n' > "$tmp/log.md"
  local out; out="$(mneme_md_index_drift "$tmp")"
  rm -rf "$tmp"
  assert_contains "$out" "missing-file: fact-ghost.md" "flags an index entry with no file" || return 1
  assert_contains "$out" "unindexed: fact-lonely.md" "flags a note file with no index line" || return 1
  assert_not_contains "$out" "fact-alpha.md" "a correctly-indexed note is not flagged" || return 1
  assert_not_contains "$out" "log.md" "log.md is excluded from the note set" || return 1
}
```

- [ ] **Step 2: Run, expect FAIL**

Run: `bash tests/run.sh`
Expected: `NOT - test_md_index_drift`, exit non-zero.

- [ ] **Step 3: Implement**

Append to `plugins/mneme/hooks/scripts/lib/md.sh`:

```bash
# Two-way drift between INDEX.md and the note files. Uses temp files (not process
# substitution) so an empty side yields no spurious blank-line matches.
mneme_md_index_drift() {
  local dir="$1" index="$1/INDEX.md" itmp atmp b
  itmp="$(mktemp)"; atmp="$(mktemp)"
  grep -oE '\([^)]+\.md\)' "$index" 2>/dev/null | sed -E 's/^\(//; s/\)$//' | sort -u > "$itmp"
  for f in "$dir"/*.md; do
    [ -f "$f" ] || continue
    b="$(basename "$f")"
    case "$b" in INDEX.md|log.md|_*) continue;; esac
    printf '%s\n' "$b"
  done | sort -u > "$atmp"
  comm -23 "$itmp" "$atmp" | sed 's/^/missing-file: /'
  comm -13 "$itmp" "$atmp" | sed 's/^/unindexed: /'
  rm -f "$itmp" "$atmp"
}
```

- [ ] **Step 4: Run, expect PASS**

Run: `bash tests/run.sh`
Expected: `ok - test_md_index_drift`, `fail=0`.

- [ ] **Step 5: Commit**

```bash
git add plugins/mneme/hooks/scripts/lib/md.sh tests/lib_md_test.sh
git commit -m "feat(lib): add md.sh mneme_md_index_drift"
```

---

### Task 3: Wire the log + cross-ref into `/remember`

**Files:**
- Modify: `plugins/mneme/commands/remember.md`
- Test: `tests/cmd_remember_test.sh`

**Interfaces:**
- Consumes: `mneme_links_add`, `mneme_log_append` (lib), via the resolver snippet.

- [ ] **Step 1: Add the failing wiring test**

Create `tests/cmd_remember_test.sh`:

```bash
#!/usr/bin/env bash
test_remember_wires_crossref_and_log() {
  local root; root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  local body; body="$(cat "$root/plugins/mneme/commands/remember.md")"
  assert_contains "$body" "mneme_links_add" "remember adds reciprocal cross-refs via the lib" || return 1
  assert_contains "$body" "mneme_log_append" "remember logs the save" || return 1
  assert_contains "$body" "at most **3**" "remember states the <=3 cross-ref cap" || return 1
}
```

- [ ] **Step 2: Run, expect FAIL**

Run: `bash tests/run.sh`
Expected: `NOT - test_remember_wires_crossref_and_log`, exit non-zero.

- [ ] **Step 3: Edit `remember.md`**

In `plugins/mneme/commands/remember.md`, find step 7 (the current final step):

```markdown
7. **Confirm** to the user in one or two lines: the note path, whether it was created or updated, and the description.
```

Replace it with these three steps:

```markdown
7. **Cross-reference** (keeps the cache a graph, not a pile). Resolve the Mneme lib:
   ```bash
   mneme_lib="${CLAUDE_PLUGIN_ROOT:-}/hooks/scripts/lib"
   [ -f "$mneme_lib/log.sh" ] || mneme_lib="$(dirname "$(find "$HOME/.claude/plugins" -path '*/mneme/hooks/scripts/lib/log.sh' 2>/dev/null | head -1)")"
   . "$mneme_lib/md.sh"; . "$mneme_lib/links.sh"; . "$mneme_lib/log.sh"
   ```
   Pick at most **3** existing notes most genuinely related to this one (shared terms in the description/body, or the same `type`). For each, add the link both directions:
   `mneme_links_add "<this-note-file>" "<their-slug>"` and `mneme_links_add "<their-note-file>" "<this-slug>"`.
   Add nothing if there is no real relation; never exceed 3 touched notes (the index stays lean). If the lib will not resolve, add the `[[slug]]` links by hand with Edit instead.

8. **Log the save.** `mneme_log_append "<target-cache-dir>" remember "<this-slug>"`. This appends to `log.md`, an append-only timeline that is never injected into a chat.

9. **Confirm** to the user in one or two lines: the note path, whether it was created or updated, the description, and any notes it was cross-linked to.
```

- [ ] **Step 4: Run, expect PASS (and all prior tests still green)**

Run: `bash tests/run.sh`
Expected: `ok - test_remember_wires_crossref_and_log`, `fail=0`.

- [ ] **Step 5: Commit**

```bash
git add plugins/mneme/commands/remember.md tests/cmd_remember_test.sh
git commit -m "feat(remember): cross-ref related notes and log each save"
```

---

### Task 4: Recall-files-back in `/recall`

**Files:**
- Modify: `plugins/mneme/commands/recall.md`
- Test: `tests/cmd_recall_test.sh`

**Interfaces:**
- Consumes: `/mneme:remember` (preferred path) or `mneme_log_append` with op `recall-filed`.

- [ ] **Step 1: Add the failing wiring test**

Create `tests/cmd_recall_test.sh`:

```bash
#!/usr/bin/env bash
test_recall_offers_file_back_optin() {
  local root; root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  local body; body="$(cat "$root/plugins/mneme/commands/recall.md")"
  assert_contains "$body" "file the answer back" "recall offers to file a synthesis back" || return 1
  assert_contains "$body" "recall-filed" "recall logs a filed synthesis with the recall-filed op" || return 1
  assert_contains "$body" "read-only" "recall stays read-only by default" || return 1
}
```

- [ ] **Step 2: Run, expect FAIL**

Run: `bash tests/run.sh`
Expected: `NOT - test_recall_offers_file_back_optin`, exit non-zero.

- [ ] **Step 3: Edit `recall.md`**

In `plugins/mneme/commands/recall.md`, find the final line:

```markdown
Keep the output scannable. Do NOT modify any files.
```

Replace it with:

```markdown
5. **Offer to file the answer back** — only when you synthesized across **≥2 notes**. If answering required combining two or more notes, end by offering to save that synthesis as a new note (`reference` or `pattern`), cross-referenced to its sources. This is opt-in: do nothing unless the user confirms. On confirmation, prefer `/mneme:remember "<the synthesis>"` (it applies the gate, dedupes, cross-refs, and logs); or, if writing the note directly, also `mneme_log_append "<cache-dir>" recall-filed "<slug>"`. If you did not combine multiple notes, skip this step.

Keep the output scannable. Recall is **read-only** by default — never modify a file unless the user accepts the file-back offer above.
```

- [ ] **Step 4: Run, expect PASS**

Run: `bash tests/run.sh`
Expected: `ok - test_recall_offers_file_back_optin`, `fail=0`.

- [ ] **Step 5: Commit**

```bash
git add plugins/mneme/commands/recall.md tests/cmd_recall_test.sh
git commit -m "feat(recall): opt-in file-the-answer-back, still read-only by default"
```

---

### Task 5: Surface + finish the log wiring on the maintenance commands

**Files:**
- Modify: `plugins/mneme/commands/status.md`
- Modify: `plugins/mneme/commands/review.md`
- Test: `tests/cmd_maintenance_test.sh`

**Interfaces:**
- Consumes: `mneme_log_tail`, `mneme_log_append` (lib), via the resolver snippet.

- [ ] **Step 1: Add the failing wiring tests**

Create `tests/cmd_maintenance_test.sh`:

```bash
#!/usr/bin/env bash
test_status_tails_log_and_points_to_lint() {
  local root; root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  local body; body="$(cat "$root/plugins/mneme/commands/status.md")"
  assert_contains "$body" "mneme_log_tail" "status surfaces the recent log activity" || return 1
  assert_contains "$body" "/mneme:lint" "status points heavier audits to /mneme:lint" || return 1
}

test_review_logs_promote() {
  local root; root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  local body; body="$(cat "$root/plugins/mneme/commands/review.md")"
  assert_contains "$body" "mneme_log_append" "review logs promotions" || return 1
  assert_contains "$body" "promote" "review uses the promote op" || return 1
}
```

- [ ] **Step 2: Run, expect FAIL**

Run: `bash tests/run.sh`
Expected: both new tests `NOT`, exit non-zero.

- [ ] **Step 3: Edit `status.md`**

In `plugins/mneme/commands/status.md`, find this STATUS bullet:

```markdown
- The 5 most recently modified notes (name + description).
```

Replace it with:

```markdown
- The 5 most recently modified notes (name + description).
- Recent activity — the last 5 entries from the timeline. Resolve the lib, then `mneme_log_tail "<cache-dir>" 5`:
  ```bash
  mneme_lib="${CLAUDE_PLUGIN_ROOT:-}/hooks/scripts/lib"
  [ -f "$mneme_lib/log.sh" ] || mneme_lib="$(dirname "$(find "$HOME/.claude/plugins" -path '*/mneme/hooks/scripts/lib/log.sh' 2>/dev/null | head -1)")"
  . "$mneme_lib/log.sh"
  ```
  If there is no `log.md` yet, say so. The log is an append-only timeline of saves / prunes / promotes; it is never injected into a chat.
```

Then find the end of the **PRUNE** section:

```markdown
- On confirmation, delete the confirmed notes and update `INDEX.md` to match.
```

Replace it with:

```markdown
- On confirmation, delete the confirmed notes, update `INDEX.md` to match, and `mneme_log_append "<cache-dir>" prune "<slug>"` for each removed note.
- For deeper audits — dead `[[links]]`, orphan notes, INDEX-vs-files drift, contradictions — point the user to `/mneme:lint`. `/status prune` stays the light pass.
```

- [ ] **Step 4: Edit `review.md`**

In `plugins/mneme/commands/review.md`, find the "Otherwise move the file" sub-bullet of step 3:

```markdown
   - Otherwise move the file from `inbox/` into the main cache (you may keep the `source: auto` line as provenance), and add one line to `INDEX.md`: `- [<Title>](<file>.md) — <description>`.
```

Replace it with:

```markdown
   - Otherwise move the file from `inbox/` into the main cache (you may keep the `source: auto` line as provenance), add one line to `INDEX.md`: `- [<Title>](<file>.md) — <description>`, and log the promotion. Resolve the lib once (`mneme_lib="${CLAUDE_PLUGIN_ROOT:-}/hooks/scripts/lib"; [ -f "$mneme_lib/log.sh" ] || mneme_lib="$(dirname "$(find "$HOME/.claude/plugins" -path '*/mneme/hooks/scripts/lib/log.sh' 2>/dev/null | head -1)")"; . "$mneme_lib/log.sh"`), then `mneme_log_append "$HOME/.claude/mneme/cache" promote "<slug>"`.
```

- [ ] **Step 5: Run, expect PASS**

Run: `bash tests/run.sh`
Expected: both maintenance tests `ok`, `fail=0`.

- [ ] **Step 6: Commit**

```bash
git add plugins/mneme/commands/status.md plugins/mneme/commands/review.md tests/cmd_maintenance_test.sh
git commit -m "feat(status,review): surface the log tail, log prunes/promotes, point to /lint"
```

---

### Task 6: New `/mneme:lint` command

**Files:**
- Create: `plugins/mneme/commands/lint.md`
- Test: `tests/cmd_lint_test.sh`

**Interfaces:**
- Consumes: `mneme_links_dead`, `mneme_links_orphans` (links.sh), `mneme_md_index_drift` (md.sh), `mneme_log_append` (log.sh), via the resolver snippet.

- [ ] **Step 1: Add the failing wiring test**

Create `tests/cmd_lint_test.sh`:

```bash
#!/usr/bin/env bash
test_lint_command_exists_and_wires_helpers() {
  local root; root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  local f="$root/plugins/mneme/commands/lint.md"
  assert_file "$f" "lint command file exists" || return 1
  local body; body="$(cat "$f")"
  assert_contains "$body" "mneme_links_dead" "lint checks dead links" || return 1
  assert_contains "$body" "mneme_links_orphans" "lint checks orphan notes" || return 1
  assert_contains "$body" "mneme_md_index_drift" "lint checks INDEX drift" || return 1
  assert_contains "$body" "read-only" "lint is read-only until confirmed" || return 1
}
```

- [ ] **Step 2: Run, expect FAIL**

Run: `bash tests/run.sh`
Expected: `NOT - test_lint_command_exists_and_wires_helpers`, exit non-zero.

- [ ] **Step 3: Create `lint.md`**

Create `plugins/mneme/commands/lint.md`:

```markdown
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
```

- [ ] **Step 4: Run, expect PASS**

Run: `bash tests/run.sh`
Expected: `ok - test_lint_command_exists_and_wires_helpers`, `fail=0`.

- [ ] **Step 5: Commit**

```bash
git add plugins/mneme/commands/lint.md tests/cmd_lint_test.sh
git commit -m "feat(lint): add /mneme:lint read-only cache audit"
```

---

### Task 7: Document Phase 1 in `mneme-engine` + Phase 1 checkpoint

**Files:**
- Modify: `plugins/mneme/skills/mneme-engine/SKILL.md`
- Test: `tests/skill_engine_test.sh`

**Interfaces:** none new (documentation).

- [ ] **Step 1: Add the failing wiring test**

Create `tests/skill_engine_test.sh`:

```bash
#!/usr/bin/env bash
test_engine_documents_phase1() {
  local root; root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  local body; body="$(cat "$root/plugins/mneme/skills/mneme-engine/SKILL.md")"
  assert_contains "$body" "log.md" "engine documents the timeline log" || return 1
  assert_contains "$body" "/mneme:lint" "engine lists the lint command" || return 1
  assert_contains "$body" "Cross-ref" "engine documents cross-referencing" || return 1
}
```

- [ ] **Step 2: Run, expect FAIL**

Run: `bash tests/run.sh`
Expected: `NOT - test_engine_documents_phase1`, exit non-zero.

- [ ] **Step 3: Edit `SKILL.md`**

In `plugins/mneme/skills/mneme-engine/SKILL.md`, find the `## Dedupe on write` section header:

```markdown
## Dedupe on write
```

Insert this new section immediately BEFORE it:

```markdown
## Cross-ref on write — keep the cache a graph

A note is worth more when it is connected. When `/mneme:remember` writes a note, it then links it to at most **3** existing notes it is genuinely related to (shared terms or the same `type`), adding the `[[slug]]` both directions via the tested `lib/links.sh` helper. The cap protects the lean index. Links live on a `Related:` line in the body; bodies are never injected, only the index is.

## The timeline log (`log.md`)

Each cache dir has an append-only `log.md` — one line per mutating action (`remember`, `promote`, `prune`, `recall-filed`, `lint-fix`). It is written by the commands via `lib/log.sh` (`mneme_log_append`) and read by `/mneme:status` (`mneme_log_tail`). Like note bodies, **`log.md` is never injected into a chat** — only `INDEX.md` loads. It is created lazily on the first write, so a fresh cache has none.

Then find the `## Pruning` section:

```markdown
## Pruning

Periodically remove: near-duplicates, notes that are no longer true, and low-value notes that never get used. Always confirm with the user before deleting. Keep the index honest.
```

Replace it with:

```markdown
## Pruning and linting

`/mneme:status prune` is the light pass: remove near-duplicates, notes no longer true, and low-value notes that never get used (always confirm before deleting). `/mneme:lint` is the heavy audit: it reports dead `[[links]]`, orphan notes, INDEX-vs-files drift (mechanical, via the lib) plus contradictions and stale claims (semantic, by reading), and applies fixes only on confirmation. Both keep the index honest.

`/mneme:recall` can also grow the cache: when it answers by synthesizing across two or more notes, it offers (opt-in) to file that synthesis back as a new, cross-referenced note. Recall is read-only unless you accept.
```

- [ ] **Step 4: Edit the command list in `SKILL.md`**

In the `## Commands` section, find:

```markdown
- `/mneme:status [prune] [--project]` — status, health, auto-capture state, and pruning.
```

Insert a new line immediately after it:

```markdown
- `/mneme:lint [--project]` — read-only audit (dead links, orphans, INDEX drift, contradictions); fixes on confirmation.
```

- [ ] **Step 5: Run — full Phase 1 checkpoint**

Run: `bash tests/run.sh`
Expected: every `test_*` is `ok`. The suite is now the 7 Phase 0 tests plus 8 Phase 1 functions (`log_tail`, `index_drift`, remember, recall, status, review, lint, engine): `pass=15 fail=0`, exit 0. The gate that matters is `fail=0`.

- [ ] **Step 6: Manual smoke (real session, throwaway cache)**

With the plugin loaded locally, against a throwaway `MNEME_GLOBAL_DIR`: `/mneme:remember "test fact"` then a second related save (confirm a `Related:` line appears in both and a line in `log.md`), `/mneme:status` (confirm "Recent activity" shows the log tail), `/mneme:lint` (confirm a read-only report, no edits without confirmation). This proves the prompt wiring resolves the lib and calls the helpers.

- [ ] **Step 7: Commit**

```bash
git add plugins/mneme/skills/mneme-engine/SKILL.md tests/skill_engine_test.sh
git commit -m "docs(engine): document the log, cross-ref, file-back, and /mneme:lint"
```

---

## Self-Review

**1. Spec coverage (Phase 1 scope, spec §6 + §11):**
- `log.md` infrastructure → `mneme_log_tail` (Task 1) + writes wired into remember (Task 3), recall (Task 4), status-prune + review-promote (Task 5), lint-fix (Task 6). The five writer ops `remember | promote | prune | recall-filed | lint-fix` are all wired; `ingest` is Phase 2. ✓
- Cross-ref on `/remember`, reciprocal, ≤3 → Task 3. ✓
- Recall files back, opt-in, read-only by default → Task 4. ✓
- `/mneme:lint` (mechanical via lib + semantic by agent; read-only; confirm-to-fix) → Task 6, with `mneme_md_index_drift` built in Task 2. ✓
- `/status` shows the log tail and points to `/lint` → Task 5. ✓
- Engine skill documents all four → Task 7. ✓
- Deferred correctly: `--wiki`/`--spine` lint targets (Phases 2–3), README rewrites + version bump (Phase 4), loader changes (none needed — Phase 0's loader test already locks "`log.md` never injected").

**2. Placeholder scan:** No TBD/TODO. Every code step is complete and runnable; every prompt edit shows the exact replacement text. The lib resolver is repeated verbatim where used (intentional — the engineer may read tasks out of order, and the command files genuinely each need their own copy).

**3. Type/name consistency:** `mneme_log_append`, `mneme_log_tail`, `mneme_md_index_drift`, `mneme_links_add`, `mneme_links_dead`, `mneme_links_orphans` are used identically in tests, lib, and the command prompts. Log ops are spelled consistently (`remember`, `promote`, `prune`, `recall-filed`, `lint-fix`) across remember/review/status/recall/lint and the engine doc, matching the spec §5 set. The wiring tests assert on these exact strings, so a rename in a prompt without a matching test update fails loudly.

**Note on Step 5 of Task 7:** `pass=15` = 9 lib/loader tests (2 loader + 2 log + 3 md + 2 links — Tasks 1–2 add one each to log and md) + 6 command/skill wiring functions (remember, recall, status, review, lint, engine, across 5 files — `cmd_maintenance_test.sh` holds two). The gate that matters is `fail=0`.

---

## Phase 1.1 — zsh hardening (post-execution addendum)

**Why:** the smoke run surfaced that this machine's default shell (what the agent's Bash tool runs for bare commands) is **zsh 5.9**, not bash, and that interactive zsh has xtrace on with a custom `PS4='+%N:%i> '`. Sourcing the bash-targeted `lib/*.sh` helpers into zsh and calling them leaks assignment traces (`nm=''` …) onto stdout — corrupting the output `/mneme:lint` and `/status` parse. The lib itself is correct (proven: 15 tests via `bash tests/run.sh`, plus `env -i bash --noprofile --norc` and explicit `bash -c` both produce clean output). Root cause was a *test-method* artifact (sourcing bash funcs into zsh), but it implies a real runtime requirement.

**Fix:** every prompt that runs a helper block now invokes it via a single explicit `bash <<'SH' … SH` heredoc (terminator flush-left), so helpers run under a fresh bash with clean defaults regardless of the login shell — and source+call live in one invocation (Bash-tool shell state does not persist between calls). Hardened: `remember.md`, `status.md`, `review.md`, `lint.md`. Guard: `tests/cmd_bash_invocation_test.sh` asserts each of the four contains `bash <<'`. Suite is now `pass=16`. See memory note `reference-shell-zsh-bash-helpers`.
