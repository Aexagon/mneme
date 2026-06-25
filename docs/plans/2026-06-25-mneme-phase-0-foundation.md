# Mneme Phase 0 — Foundation (test harness + shared lib + reorg) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Put a green test harness, a shared `lib/` engine, and the optimised folder structure in place, with Mneme behaving exactly as it does today.

**Architecture:** Phase 0 of the spec at `docs/specs/2026-06-25-mneme-gaps-and-folders-design.md`. Tests-first: a runnable harness exists before any file moves. Then three pure-bash `lib/` helpers (`log`, `md`, `links`) the later phases build on. Then the reorg (relocate `protocol-snippet`, move the explainer, add `docs/design/` and a workspace file), with the harness proving nothing broke.

**Tech Stack:** Bash, Python3 (already a dependency of the loader/distiller), plain-bash test assertions.

## Global Constraints

- Approach A: do NOT create anything under `~/core`, do NOT move or relocate any cache data.
- Backward compatible: with no env vars set and no `log.md`/wiki present, behavior is identical to today.
- `log.md` and the wiki are NEVER injected into a chat. Only `INDEX.md` (and later the spine) load.
- Commands stay flat under `commands/` (subfolders would rename `/mneme:<x>`). Phase 0 adds no commands.
- Plugin version stays `0.2.0` in Phase 0 (the bump to `0.3.0` is Phase 4).
- Work on a branch named `phase-0-foundation`, NOT `main`. Commits are local checkpoints only; do NOT push to GitHub without Jerry's explicit say-so.
- Throwaway caches for all tests: point `MNEME_GLOBAL_DIR` at a `mktemp -d` dir; never touch `~/.claude/mneme`.

## File Structure

- `tests/run.sh` — test runner: sources `tests/lib/assert.sh` and every `tests/*_test.sh`, runs `test_*` functions, prints pass/fail, exits non-zero on any failure.
- `tests/lib/assert.sh` — tiny assertion helpers (`assert_contains`, `assert_not_contains`, `assert_eq`, `assert_file`).
- `tests/loader_test.sh` — smoke test of `load-cache.sh` against a throwaway cache.
- `tests/lib_log_test.sh`, `tests/lib_md_test.sh`, `tests/lib_links_test.sh` — unit tests for the helpers.
- `plugins/mneme/hooks/scripts/lib/log.sh` — append-only `log.md` helper.
- `plugins/mneme/hooks/scripts/lib/md.sh` — frontmatter read + INDEX.md upsert/remove.
- `plugins/mneme/hooks/scripts/lib/links.sh` — `[[wikilink]]` graph helpers.
- `plugins/mneme/assets/protocol-snippet.md` — moved from `hooks/scripts/protocol-snippet.md`.
- `plugins/mneme/hooks/scripts/load-cache.sh` — one line changed: protocol path now points at `assets/`.
- `docs/explainer/index.html` — moved from `docs/mneme-explainer.html`.
- `docs/README.md`, `docs/design/architecture.md`, `docs/design/data-layout.md` — new docs.
- `mneme.code-workspace` — VS Code multi-root workspace with watcher excludes.

---

### Task 1: Test harness + baseline smoke test

**Files:**
- Create: `tests/lib/assert.sh`
- Create: `tests/run.sh`
- Create: `tests/loader_test.sh`

**Interfaces:**
- Produces: `assert_contains <haystack> <needle> <msg>`, `assert_not_contains <haystack> <needle> <msg>`, `assert_eq <got> <want> <msg>`, `assert_file <path> <msg>` (each prints `FAIL: ...` and returns 1 on failure). `tests/run.sh` discovers and runs every `test_*` function in `tests/*_test.sh`.

- [ ] **Step 1: Write the assertion helpers**

Create `tests/lib/assert.sh`:

```bash
#!/usr/bin/env bash
# Tiny assertion helpers for Mneme's bash tests. Each prints FAIL and returns 1.
assert_contains() {
  case "$1" in *"$2"*) return 0;; *) echo "  FAIL: $3 (missing: $2)"; return 1;; esac
}
assert_not_contains() {
  case "$1" in *"$2"*) echo "  FAIL: $3 (unexpected: $2)"; return 1;; *) return 0;; esac
}
assert_eq() {
  [ "$1" = "$2" ] && return 0
  echo "  FAIL: $3 (got '$1', want '$2')"; return 1
}
assert_file() {
  [ -f "$1" ] && return 0
  echo "  FAIL: $2 (no file: $1)"; return 1
}
```

- [ ] **Step 2: Write the runner**

Create `tests/run.sh`:

```bash
#!/usr/bin/env bash
# Mneme test runner. Sources assert + every *_test.sh, runs each test_* function.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/tests/lib/assert.sh"
PASS=0; FAIL=0
for f in "$ROOT"/tests/*_test.sh; do
  [ -f "$f" ] || continue
  . "$f"
  for fn in $(declare -F | awk '{print $3}' | grep '^test_'); do
    if "$fn"; then echo "ok   - $fn"; PASS=$((PASS+1))
    else echo "NOT  - $fn"; FAIL=$((FAIL+1)); fi
    unset -f "$fn"
  done
done
echo "----"
echo "pass=$PASS fail=$FAIL"
[ "$FAIL" -eq 0 ]
```

- [ ] **Step 3: Write the failing loader smoke test**

Create `tests/loader_test.sh`:

```bash
#!/usr/bin/env bash
# Smoke test: load-cache.sh injects the protocol + the index, never log.md, and honors the cap.
test_loader_injects_protocol_and_index() {
  local root tmp out
  root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  tmp="$(mktemp -d)"; mkdir -p "$tmp/cache"
  printf '# Mneme cache\n\n- [Demo](fact-demo.md) — a throwaway line\n' > "$tmp/cache/INDEX.md"
  printf 'this log line must not be injected\n' > "$tmp/cache/log.md"
  out="$(MNEME_GLOBAL_DIR="$tmp/cache" bash "$root/plugins/mneme/hooks/scripts/load-cache.sh" \
        | python3 -c 'import json,sys;print(json.load(sys.stdin)["hookSpecificOutput"]["additionalContext"])')"
  rm -rf "$tmp"
  assert_contains "$out" "Mneme is active." "loader injects the protocol" || return 1
  assert_contains "$out" "[Demo](fact-demo.md)" "loader injects the index bullet" || return 1
  assert_not_contains "$out" "this log line must not be injected" "loader never injects log.md" || return 1
}

test_loader_honors_max_chars() {
  local root tmp out
  root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  tmp="$(mktemp -d)"; mkdir -p "$tmp/cache"
  printf '# Mneme cache\n\n- [Demo](fact-demo.md) — a throwaway line that is fairly long\n' > "$tmp/cache/INDEX.md"
  out="$(MNEME_GLOBAL_DIR="$tmp/cache" MNEME_MAX_CHARS=120 bash "$root/plugins/mneme/hooks/scripts/load-cache.sh" \
        | python3 -c 'import json,sys;print(json.load(sys.stdin)["hookSpecificOutput"]["additionalContext"])')"
  rm -rf "$tmp"
  assert_contains "$out" "Mneme index truncated" "loader truncates past MNEME_MAX_CHARS" || return 1
}
```

- [ ] **Step 4: Run the harness, expect PASS (it tests current, working code)**

Run: `bash tests/run.sh`
Expected: `ok - test_loader_injects_protocol_and_index`, `ok - test_loader_honors_max_chars`, `pass=2 fail=0`, exit 0.

- [ ] **Step 5: Commit**

```bash
chmod +x tests/run.sh
git add tests/
git commit -m "test: add bash harness + load-cache smoke baseline"
```

---

### Task 2: `lib/log.sh` — append-only log helper

**Files:**
- Create: `plugins/mneme/hooks/scripts/lib/log.sh`
- Test: `tests/lib_log_test.sh`

**Interfaces:**
- Produces: `mneme_log_append <cache_dir> <op> <slug> [note]` — appends `## [YYYY-MM-DD] <op> | <slug>` (plus ` — <note>` when a note is given) to `<cache_dir>/log.md`, creating it with a `# Mneme log` header if absent.

- [ ] **Step 1: Write the failing test**

Create `tests/lib_log_test.sh`:

```bash
#!/usr/bin/env bash
test_log_append_creates_and_appends() {
  local root tmp; root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  . "$root/plugins/mneme/hooks/scripts/lib/log.sh"
  tmp="$(mktemp -d)"
  mneme_log_append "$tmp" remember feedback-no-em-dash
  mneme_log_append "$tmp" prune old-note "duplicate"
  local body; body="$(cat "$tmp/log.md")"
  rm -rf "$tmp"
  assert_contains "$body" "# Mneme log" "log has a header" || return 1
  assert_contains "$body" "remember | feedback-no-em-dash" "log records the op + slug" || return 1
  assert_contains "$body" "prune | old-note — duplicate" "log records an optional note" || return 1
}
```

- [ ] **Step 2: Run, expect FAIL**

Run: `bash tests/run.sh`
Expected: `NOT - test_log_append_creates_and_appends` (file `lib/log.sh` does not exist yet), `fail>=1`, exit non-zero.

- [ ] **Step 3: Write the implementation**

Create `plugins/mneme/hooks/scripts/lib/log.sh`:

```bash
#!/usr/bin/env bash
# Mneme shared engine: append-only timeline. Never injected into a chat.
mneme_log_append() {
  local dir="$1" op="$2" slug="$3" note="${4:-}"
  local log="$dir/log.md" today
  [ -d "$dir" ] || mkdir -p "$dir"
  [ -f "$log" ] || printf '# Mneme log\n\n' > "$log"
  today="$(date '+%Y-%m-%d' 2>/dev/null || echo unknown)"
  if [ -n "$note" ]; then
    printf '## [%s] %s | %s — %s\n' "$today" "$op" "$slug" "$note" >> "$log"
  else
    printf '## [%s] %s | %s\n' "$today" "$op" "$slug" >> "$log"
  fi
}
```

- [ ] **Step 4: Run, expect PASS**

Run: `bash tests/run.sh`
Expected: `ok - test_log_append_creates_and_appends`, `fail=0`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add plugins/mneme/hooks/scripts/lib/log.sh tests/lib_log_test.sh
git commit -m "feat(lib): add log.sh append-only timeline helper"
```

---

### Task 3: `lib/md.sh` — frontmatter + index helpers

**Files:**
- Create: `plugins/mneme/hooks/scripts/lib/md.sh`
- Test: `tests/lib_md_test.sh`

**Interfaces:**
- Produces: `mneme_md_frontmatter_get <file> <key>` (prints the value); `mneme_md_index_upsert <cache_dir> <filename> <title> <description>` (adds or replaces the `- [title](filename) — description` line in `INDEX.md`); `mneme_md_index_remove <cache_dir> <filename>` (drops the line referencing that file).

- [ ] **Step 1: Write the failing test**

Create `tests/lib_md_test.sh`:

```bash
#!/usr/bin/env bash
test_md_frontmatter_get() {
  local root tmp; root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  . "$root/plugins/mneme/hooks/scripts/lib/md.sh"
  tmp="$(mktemp -d)"
  printf -- '---\nname: jerry-voice\ndescription: bullets, hint do not declare\ntype: preference\n---\n\nBody.\n' > "$tmp/n.md"
  local v; v="$(mneme_md_frontmatter_get "$tmp/n.md" name)"
  rm -rf "$tmp"
  assert_eq "$v" "jerry-voice" "frontmatter name parsed" || return 1
}

test_md_index_upsert_and_remove() {
  local root tmp; root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  . "$root/plugins/mneme/hooks/scripts/lib/md.sh"
  tmp="$(mktemp -d)"
  mneme_md_index_upsert "$tmp" "preference-jerry-voice.md" "Jerry voice" "bullets, not prose"
  mneme_md_index_upsert "$tmp" "preference-jerry-voice.md" "Jerry voice" "bullets; hint do not declare"
  local body; body="$(cat "$tmp/INDEX.md")"
  assert_contains "$body" "[Jerry voice](preference-jerry-voice.md) — bullets; hint do not declare" "upsert replaces, not duplicates" || { rm -rf "$tmp"; return 1; }
  assert_eq "$(grep -c 'preference-jerry-voice.md' "$tmp/INDEX.md")" "1" "exactly one index line for the file" || { rm -rf "$tmp"; return 1; }
  mneme_md_index_remove "$tmp" "preference-jerry-voice.md"
  assert_eq "$(grep -c 'preference-jerry-voice.md' "$tmp/INDEX.md")" "0" "remove drops the line" || { rm -rf "$tmp"; return 1; }
  rm -rf "$tmp"
}
```

- [ ] **Step 2: Run, expect FAIL**

Run: `bash tests/run.sh`
Expected: both `md` tests `NOT`, exit non-zero.

- [ ] **Step 3: Write the implementation**

Create `plugins/mneme/hooks/scripts/lib/md.sh`:

```bash
#!/usr/bin/env bash
# Mneme shared engine: frontmatter read + INDEX.md bookkeeping. Note bodies are authored by commands.
mneme_md_frontmatter_get() {
  awk -v key="$2" '
    NR==1 && $0=="---" {infm=1; next}
    infm && $0=="---" {exit}
    infm {
      i=index($0,":")
      if (i>0) {
        k=substr($0,1,i-1); v=substr($0,i+1)
        gsub(/^[ \t]+|[ \t]+$/,"",k); gsub(/^[ \t]+|[ \t]+$/,"",v)
        if (k==key) {print v; exit}
      }
    }' "$1" 2>/dev/null
}

mneme_md_index_upsert() {
  local dir="$1" file="$2" title="$3" desc="$4" index="$1/INDEX.md" tmp
  [ -d "$dir" ] || mkdir -p "$dir"
  [ -f "$index" ] || printf '# Mneme cache\n\n' > "$index"
  tmp="$(mktemp)"
  grep -vF "($file)" "$index" > "$tmp" 2>/dev/null || true
  printf -- '- [%s](%s) — %s\n' "$title" "$file" "$desc" >> "$tmp"
  mv "$tmp" "$index"
}

mneme_md_index_remove() {
  local dir="$1" file="$2" index="$1/INDEX.md" tmp
  [ -f "$index" ] || return 0
  tmp="$(mktemp)"
  grep -vF "($file)" "$index" > "$tmp" 2>/dev/null || true
  mv "$tmp" "$index"
}
```

Note: `upsert` uses `grep -vF "($file)"` to drop any prior line for the file before re-appending, so it both inserts and updates. The literal `(filename)` substring is how INDEX bullets reference their file.

- [ ] **Step 4: Run, expect PASS**

Run: `bash tests/run.sh`
Expected: both `md` tests `ok`, `fail=0`.

- [ ] **Step 5: Commit**

```bash
git add plugins/mneme/hooks/scripts/lib/md.sh tests/lib_md_test.sh
git commit -m "feat(lib): add md.sh frontmatter + INDEX upsert/remove helpers"
```

---

### Task 4: `lib/links.sh` — wikilink graph helpers

**Files:**
- Create: `plugins/mneme/hooks/scripts/lib/links.sh`
- Test: `tests/lib_links_test.sh`

**Interfaces:**
- Consumes: `mneme_md_frontmatter_get` from `lib/md.sh` (to map a note file to its `name:` slug).
- Produces: `mneme_links_in_note <file>` (prints each `[[slug]]` target, one per line); `mneme_links_add <file> <slug>` (idempotently adds `[[slug]]` to a `Related:` line); `mneme_links_inbound <cache_dir> <slug>` (prints files containing `[[slug]]`); `mneme_links_dead <cache_dir>` (prints link targets with no note whose `name:` matches); `mneme_links_orphans <cache_dir>` (prints note files with zero inbound links).

- [ ] **Step 1: Write the failing test**

Create `tests/lib_links_test.sh`:

```bash
#!/usr/bin/env bash
_links_fixture() {
  local d="$1"
  printf -- '---\nname: a\ndescription: note a\ntype: fact\n---\n\nSee [[b]].\n' > "$d/fact-a.md"
  printf -- '---\nname: b\ndescription: note b\ntype: fact\n---\n\nLone note. Points to [[ghost]].\n' > "$d/fact-b.md"
}

test_links_in_note_and_add() {
  local root tmp; root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  . "$root/plugins/mneme/hooks/scripts/lib/md.sh"
  . "$root/plugins/mneme/hooks/scripts/lib/links.sh"
  tmp="$(mktemp -d)"; _links_fixture "$tmp"
  assert_eq "$(mneme_links_in_note "$tmp/fact-a.md")" "b" "reads [[b]] from note a" || { rm -rf "$tmp"; return 1; }
  mneme_links_add "$tmp/fact-b.md" a
  mneme_links_add "$tmp/fact-b.md" a   # idempotent
  assert_eq "$(grep -c '\[\[a\]\]' "$tmp/fact-b.md")" "1" "add is idempotent" || { rm -rf "$tmp"; return 1; }
  rm -rf "$tmp"
}

test_links_inbound_dead_orphans() {
  local root tmp; root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  . "$root/plugins/mneme/hooks/scripts/lib/md.sh"
  . "$root/plugins/mneme/hooks/scripts/lib/links.sh"
  tmp="$(mktemp -d)"; _links_fixture "$tmp"
  assert_contains "$(mneme_links_inbound "$tmp" b)" "fact-a.md" "a links to b (inbound)" || { rm -rf "$tmp"; return 1; }
  assert_contains "$(mneme_links_dead "$tmp")" "ghost" "ghost is a dead link" || { rm -rf "$tmp"; return 1; }
  assert_contains "$(mneme_links_orphans "$tmp")" "fact-a.md" "a has no inbound links (orphan)" || { rm -rf "$tmp"; return 1; }
  rm -rf "$tmp"
}
```

- [ ] **Step 2: Run, expect FAIL**

Run: `bash tests/run.sh`
Expected: both `links` tests `NOT`, exit non-zero.

- [ ] **Step 3: Write the implementation**

Create `plugins/mneme/hooks/scripts/lib/links.sh`:

```bash
#!/usr/bin/env bash
# Mneme shared engine: [[wikilink]] graph. Depends on lib/md.sh for name: resolution.
mneme_links_in_note() {
  grep -oE '\[\[[A-Za-z0-9_-]+\]\]' "$1" 2>/dev/null | sed -E 's/\[\[(.*)\]\]/\1/' | sort -u
}

mneme_links_add() {
  local file="$1" slug="$2"
  grep -qE "\[\[${slug}\]\]" "$file" 2>/dev/null && return 0
  if grep -qE '^Related:' "$file" 2>/dev/null; then
    local tmp; tmp="$(mktemp)"
    sed -E "s|^(Related:.*)$|\1 [[${slug}]]|" "$file" > "$tmp" && mv "$tmp" "$file"
  else
    printf '\nRelated: [[%s]]\n' "$slug" >> "$file"
  fi
}

mneme_links_inbound() {
  local dir="$1" slug="$2"
  grep -lE "\[\[${slug}\]\]" "$dir"/*.md 2>/dev/null | while read -r f; do basename "$f"; done
}

# All slugs that are link targets but have no note whose name: matches.
mneme_links_dead() {
  local dir="$1" names targets
  names="$(for f in "$dir"/*.md; do [ -f "$f" ] && mneme_md_frontmatter_get "$f" name; done | sort -u)"
  targets="$(for f in "$dir"/*.md; do [ -f "$f" ] && mneme_links_in_note "$f"; done | sort -u)"
  comm -23 <(printf '%s\n' "$targets") <(printf '%s\n' "$names")
}

# Notes whose name: is never the target of any [[link]].
mneme_links_orphans() {
  local dir="$1" linked
  linked="$(for f in "$dir"/*.md; do [ -f "$f" ] && mneme_links_in_note "$f"; done | sort -u)"
  for f in "$dir"/*.md; do
    [ -f "$f" ] || continue
    local nm; nm="$(mneme_md_frontmatter_get "$f" name)"
    [ -n "$nm" ] || continue
    printf '%s\n' "$linked" | grep -qx "$nm" || basename "$f"
  done
}
```

- [ ] **Step 4: Run, expect PASS**

Run: `bash tests/run.sh`
Expected: both `links` tests `ok`, `fail=0`.

- [ ] **Step 5: Commit**

```bash
git add plugins/mneme/hooks/scripts/lib/links.sh tests/lib_links_test.sh
git commit -m "feat(lib): add links.sh wikilink graph helpers"
```

---

### Task 5: Relocate `protocol-snippet.md` into `assets/`

**Files:**
- Move: `plugins/mneme/hooks/scripts/protocol-snippet.md` → `plugins/mneme/assets/protocol-snippet.md`
- Modify: `plugins/mneme/hooks/scripts/load-cache.sh` (the `PROTOCOL_FILE` line)

**Interfaces:**
- Consumes: nothing new. The loader smoke test from Task 1 is the guard.

- [ ] **Step 1: Move the file with git**

```bash
mkdir -p plugins/mneme/assets
git mv plugins/mneme/hooks/scripts/protocol-snippet.md plugins/mneme/assets/protocol-snippet.md
```

- [ ] **Step 2: Update the loader's path**

In `plugins/mneme/hooks/scripts/load-cache.sh`, change:

```bash
PROTOCOL_FILE="$SCRIPT_DIR/protocol-snippet.md"
```

to:

```bash
PROTOCOL_FILE="$SCRIPT_DIR/../../assets/protocol-snippet.md"
```

(`load-cache.sh` is in `hooks/scripts/`; `assets/` is at the plugin root, so `../../assets/`.)

- [ ] **Step 3: Run the harness, expect PASS (proves the move didn't break injection)**

Run: `bash tests/run.sh`
Expected: `test_loader_injects_protocol_and_index` still `ok`, `fail=0`.

- [ ] **Step 4: Commit**

```bash
git add plugins/mneme/assets/protocol-snippet.md plugins/mneme/hooks/scripts/load-cache.sh
git commit -m "refactor: move protocol-snippet to assets/, update loader path"
```

---

### Task 6: Docs reorg (explainer move + design docs)

**Files:**
- Move: `docs/mneme-explainer.html` → `docs/explainer/index.html`
- Create: `docs/README.md`
- Create: `docs/design/architecture.md`
- Create: `docs/design/data-layout.md`

- [ ] **Step 1: Move the explainer**

```bash
mkdir -p docs/explainer
git mv docs/mneme-explainer.html docs/explainer/index.html
```

- [ ] **Step 2: Write `docs/README.md`**

```markdown
# Mneme docs

- [explainer/index.html](explainer/index.html) — the visual two-tier explainer.
- [design/architecture.md](design/architecture.md) — the two tiers + the shared spine.
- [design/data-layout.md](design/data-layout.md) — where memory, wiki, and spine live at runtime.
- [specs/](specs/) — dated design specs.
```

- [ ] **Step 3: Write `docs/design/architecture.md`**

```markdown
# Mneme architecture

Mneme maintains markdown that compounds. Two tiers sit on one engine, plus an optional spine.

- **Tier 1 — memory.** Lean, gate-kept, injected into every chat. Source: your chats. Lives in `cache/`.
- **Tier 2 — knowledge.** A per-corpus wiki read on demand, never injected. Source: your documents. Lives in `wiki/<corpus>/`.
- **Spine.** An optional cross-agent overlay keyed by `MNEME_SPINE_DIR`, off by default. Claude maintains it; other agents read it.

The code (this repo) is separate from the data (memory / wiki / spine, all outside the repo). Inside the code, a shared `hooks/scripts/lib/` (`log`, `md`, `links`) backs both tiers, so there is one implementation of the markdown / index / log / link primitives.

See `docs/specs/2026-06-25-mneme-gaps-and-folders-design.md` for the full design.
```

- [ ] **Step 4: Write `docs/design/data-layout.md`**

```markdown
# Mneme runtime data layout

Data lives outside the repo and is fully relocatable.

```
~/.claude/mneme/                  home (dirname of the global cache)
├── cache/                        Tier 1 · memory (always loaded, lean)
│   ├── INDEX.md                  the only thing injected
│   ├── log.md                    append-only timeline (NOT injected)
│   └── <type>-<slug>.md
├── inbox/                        distiller quarantine (/mneme:review)
├── wiki/<corpus>/                Tier 2 · knowledge (on demand, NEVER injected)
│   └── index.md · log.md · sources/ · pages/
└── config
```

Overlays: `<project>/.mneme/{cache,wiki}/` (project), and `MNEME_SPINE_DIR` (cross-agent spine, unset by default).

Environment variables: `MNEME_GLOBAL_DIR` (global cache), `MNEME_MAX_CHARS` (injected-context cap, default 16000), `MNEME_SPINE_DIR` (spine, off by default), `MNEME_WIKI_DIR` (wiki home override), plus the `MNEME_DISTILL_*` family.
```

- [ ] **Step 5: Commit**

```bash
git add docs/
git commit -m "docs: reorg into explainer/ + design/, add docs index"
```

---

### Task 7: `mneme.code-workspace` + Phase 0 checkpoint

**Files:**
- Create: `mneme.code-workspace`

- [ ] **Step 1: Write the workspace file**

Create `mneme.code-workspace`:

```json
{
  "folders": [
    { "name": "plugin", "path": "plugins/mneme" },
    { "name": "docs", "path": "docs" },
    { "name": "tests", "path": "tests" }
  ],
  "settings": {
    "files.watcherExclude": {
      "**/.git/**": true,
      "**/.DS_Store": true,
      "**/node_modules/**": true
    },
    "search.exclude": {
      "**/.git": true
    }
  }
}
```

- [ ] **Step 2: Final Phase 0 checkpoint — full harness green**

Run: `bash tests/run.sh`
Expected: every `test_*` line is `ok`, `pass=7 fail=0` (2 loader + 1 log + 2 md + 2 links), exit 0.

- [ ] **Step 3: Manual reload check (real session, against a throwaway cache)**

In a Claude Code session with the local plugin loaded (`/plugin marketplace add ~/Desktop/Claude/mneme` then `/plugin install mneme@mneme`, restart): confirm the Mneme cache still loads at the top of the chat and `/mneme:status` runs. This proves the reorg is invisible to the running plugin.

- [ ] **Step 4: Commit**

```bash
git add mneme.code-workspace
git commit -m "chore: add mneme.code-workspace with watcher excludes"
```

---

## Self-Review

**1. Spec coverage (Phase 0 scope):**
- Test harness first → Task 1. ✓
- `lib/` (`log`, `md`, `links`) with unit tests → Tasks 2–4. ✓
- Relocate `protocol-snippet` + update loader path → Task 5. ✓
- Move explainer, add `docs/design/` + `docs/README.md` → Task 6. ✓
- `mneme.code-workspace` → Task 7. ✓
- `tests/` at repo top level, loader ignores it → Task 1. ✓
- Backward compatibility (loader smoke green after the move) → Task 5 Step 3, Task 7 Step 2. ✓
- Out of Phase 0 (correctly deferred): the four memory features, `/ingest` + wiki, the spine overlay, README rewrites, version bump. These are Phases 1–4.

**2. Placeholder scan:** No TBD/TODO. Every code step has complete, runnable code. Expected outputs are concrete.

**3. Type/name consistency:** `mneme_log_append`, `mneme_md_frontmatter_get`, `mneme_md_index_upsert`, `mneme_md_index_remove`, `mneme_links_in_note`, `mneme_links_add`, `mneme_links_inbound`, `mneme_links_dead`, `mneme_links_orphans` are used identically in their tests and definitions. `links.sh` consuming `md.sh`'s `mneme_md_frontmatter_get` is declared in Task 4 Interfaces and both are sourced in that test. The loader path `../../assets/protocol-snippet.md` matches the move target in Task 5.

**Note on Step 2 of Task 7:** the asserted total `pass=7` is two loader + one log + two md + two links; if a function is added or split, update the number. The gate that matters is `fail=0`.
