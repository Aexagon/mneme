# Mneme Phase 2 — Knowledge tier Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Tier 2 — a per-corpus **wiki** (the gist's "LLM Wiki"): a knowledge base built from documents, read on demand, **never injected** into a chat — via a new `mneme-wiki` skill, a new `/mneme:ingest` command, `--wiki` query/audit modes on `/recall` and `/mneme:lint`, and a one-line loader notice that a wiki exists.

**Architecture:** Phase 2 of the spec at `docs/specs/2026-06-25-mneme-gaps-and-folders-design.md` §7–§8. The wiki reuses the same tested `lib/` engine (`log`, `links`, `md`) plus a new `lib/wiki.sh` for home/corpus resolution. A wiki corpus lives at `wiki/<corpus>/{index.md, log.md, sources/, pages/}`, a sibling of `cache/` (`dirname(global cache)/wiki`, override `MNEME_WIKI_DIR`). The loader gains a single size-gated line listing corpus names; it never reads wiki bodies or indexes. Command prompts run helpers under explicit `bash` (the zsh hardening from Phase 1.1).

**Tech Stack:** Bash 3.2, Python3 (loader), `markitdown` (rich-file → markdown, already a house convention), plain-bash test assertions.

## Global Constraints

- Approach A: nothing created under `~/core`; no cache data moved.
- Backward compatible: with no `wiki/` present, behavior is identical to today (the loader adds nothing).
- A wiki is **NEVER injected** — the loader emits at most one line naming the corpora; wiki `index.md`/`pages/` bodies never load. This is the single most important invariant; it gets its own loader test.
- The lean cache (`/remember`, `/recall`, `/status`) is unchanged. Plain `/recall` still only touches the cache.
- Commands stay flat under `commands/`; the one new command is `commands/ingest.md` → `/mneme:ingest`.
- Plugin version stays `0.2.0` (the bump to `0.3.0` is Phase 4). Do NOT edit `plugin.json`.
- Helper blocks in prompts run under a single explicit `bash <<'SH' … SH` heredoc, terminator flush-left (Phase 1.1 rule; the agent's shell is zsh).
- Wiki home: `${MNEME_WIKI_DIR:-$(dirname "<global-cache>")/wiki}`; project wiki: `<project>/.mneme/wiki/`.
- Work on the existing branch `phase-0-foundation`. Local commits only; do NOT push without Jerry's say-so.
- Throwaway dirs for all tests: `mktemp -d`; never touch `~/.claude/mneme`.
- `bash tests/run.sh` green at every task boundary (Phase 1 left it at `pass=16`).

## File Structure

- `plugins/mneme/hooks/scripts/lib/wiki.sh` — NEW: `mneme_wiki_home`, `mneme_wiki_names`.
- `plugins/mneme/hooks/scripts/load-cache.sh` — ADD the wiki notice (bash computes homes, python lists corpora).
- `plugins/mneme/skills/mneme-wiki/SKILL.md` — NEW: the knowledge-tier protocol.
- `plugins/mneme/commands/ingest.md` — NEW: `/mneme:ingest`.
- `plugins/mneme/commands/recall.md` — ADD a `--wiki` query branch.
- `plugins/mneme/commands/lint.md` — ADD a `--wiki` audit target.
- `plugins/mneme/skills/mneme-engine/SKILL.md` — document Tier 2 + add `/mneme:ingest` to the command list.
- `tests/lib_wiki_test.sh`, plus a wiki case in `tests/loader_test.sh` — NEW lib + loader tests.
- `tests/cmd_ingest_test.sh`, `tests/cmd_wiki_modes_test.sh`, `tests/skill_wiki_test.sh` — NEW wiring tests.

---

### Task 1: `lib/wiki.sh` — wiki home + corpus listing

**Files:**
- Create: `plugins/mneme/hooks/scripts/lib/wiki.sh`
- Test: `tests/lib_wiki_test.sh`

**Interfaces:**
- Produces: `mneme_wiki_home` — prints `$MNEME_WIKI_DIR` if set, else `dirname(${MNEME_GLOBAL_DIR:-$HOME/.claude/mneme/cache})/wiki`. `mneme_wiki_names <wiki_home>` — prints each corpus name (a subdir containing `index.md`), one per line; nothing if the home is absent.

- [ ] **Step 1: Write the failing test**

Create `tests/lib_wiki_test.sh`:

```bash
#!/usr/bin/env bash
test_wiki_home_resolves() {
  local root; root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  . "$root/plugins/mneme/hooks/scripts/lib/wiki.sh"
  assert_eq "$(MNEME_WIKI_DIR=/x/w mneme_wiki_home)" "/x/w" "explicit MNEME_WIKI_DIR wins" || return 1
  assert_eq "$(MNEME_WIKI_DIR= MNEME_GLOBAL_DIR=/a/b/cache mneme_wiki_home)" "/a/b/wiki" "derives sibling of the cache" || return 1
}

test_wiki_names_lists_corpora() {
  local root tmp; root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  . "$root/plugins/mneme/hooks/scripts/lib/wiki.sh"
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/alpha" "$tmp/beta" "$tmp/empty"
  printf '# a\n' > "$tmp/alpha/index.md"
  printf '# b\n' > "$tmp/beta/index.md"
  local out; out="$(mneme_wiki_names "$tmp")"
  rm -rf "$tmp"
  assert_contains "$out" "alpha" "lists a corpus with index.md" || return 1
  assert_contains "$out" "beta" "lists a second corpus" || return 1
  assert_not_contains "$out" "empty" "skips a dir with no index.md" || return 1
}
```

- [ ] **Step 2: Run, expect FAIL**

Run: `bash tests/run.sh`
Expected: both `wiki` tests `NOT`, exit non-zero.

- [ ] **Step 3: Implement**

Create `plugins/mneme/hooks/scripts/lib/wiki.sh`:

```bash
#!/usr/bin/env bash
# Mneme shared engine: wiki (Tier 2) home + corpus resolution. A corpus is a
# subdir of the wiki home that contains an index.md.
mneme_wiki_home() {
  if [ -n "${MNEME_WIKI_DIR:-}" ]; then
    printf '%s\n' "$MNEME_WIKI_DIR"; return
  fi
  local cache="${MNEME_GLOBAL_DIR:-$HOME/.claude/mneme/cache}"
  printf '%s\n' "$(dirname "$cache")/wiki"
}

mneme_wiki_names() {
  local home="$1" d
  [ -d "$home" ] || return 0
  for d in "$home"/*/; do
    [ -f "${d}index.md" ] && basename "$d"
  done
}
```

- [ ] **Step 4: Run, expect PASS**

Run: `bash tests/run.sh`
Expected: both `wiki` tests `ok`, `fail=0`.

- [ ] **Step 5: Commit**

```bash
git add plugins/mneme/hooks/scripts/lib/wiki.sh tests/lib_wiki_test.sh
git commit -m "feat(lib): add wiki.sh home + corpus listing"
```

---

### Task 2: Loader wiki notice (never inject wiki bodies)

**Files:**
- Modify: `plugins/mneme/hooks/scripts/load-cache.sh`
- Test: `tests/loader_test.sh`

**Interfaces:**
- Consumes: nothing new from the lib (the loader is python). Produces: when ≥1 corpus exists, one extra section `# Mneme wikis\n\nWikis: <names> — query with /recall --wiki <name>`, size-gated by the existing `MNEME_MAX_CHARS` truncation.

- [ ] **Step 1: Add the failing test**

Append to `tests/loader_test.sh`:

```bash
test_loader_announces_wiki_but_never_its_body() {
  local root tmp out
  root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  tmp="$(mktemp -d)"; mkdir -p "$tmp/cache" "$tmp/wiki/handbook"
  printf '# Mneme cache\n\n- [Demo](fact-demo.md) — x\n' > "$tmp/cache/INDEX.md"
  printf '# Handbook\n\nWIKI_BODY_MUST_NOT_LOAD\n' > "$tmp/wiki/handbook/index.md"
  out="$(MNEME_GLOBAL_DIR="$tmp/cache" bash "$root/plugins/mneme/hooks/scripts/load-cache.sh" \
        | python3 -c 'import json,sys;print(json.load(sys.stdin)["hookSpecificOutput"]["additionalContext"])')"
  rm -rf "$tmp"
  assert_contains "$out" "Wikis: handbook" "loader announces the corpus name" || return 1
  assert_not_contains "$out" "WIKI_BODY_MUST_NOT_LOAD" "loader never injects wiki bodies" || return 1
}
```

- [ ] **Step 2: Run, expect FAIL**

Run: `bash tests/run.sh`
Expected: `NOT - test_loader_announces_wiki_but_never_its_body`, exit non-zero. (The other loader tests still pass — they create no `wiki/`.)

- [ ] **Step 3: Implement — bash side**

In `plugins/mneme/hooks/scripts/load-cache.sh`, after this line:

```bash
PROTOCOL_FILE="$SCRIPT_DIR/../../assets/protocol-snippet.md"
```

add:

```bash
WIKI_HOME="${MNEME_WIKI_DIR:-$(dirname "$GLOBAL_CACHE")/wiki}"
PROJECT_WIKI="$PROJECT_ROOT/.mneme/wiki"
```

and change the python invocation line from:

```bash
  python3 - "$GLOBAL_CACHE" "$PROJECT_CACHE" "$PROTOCOL_FILE" <<'PY' || exit 0
```

to:

```bash
  python3 - "$GLOBAL_CACHE" "$PROJECT_CACHE" "$PROTOCOL_FILE" "$WIKI_HOME" "$PROJECT_WIKI" <<'PY' || exit 0
```

- [ ] **Step 4: Implement — python side**

In the same heredoc, find:

```python
pi = strip_h1(read(os.path.join(project_cache, "INDEX.md")))
if pi:
    parts.append("# Mneme cache (this project)\n\n" + pi)

context = "\n\n---\n\n".join(parts)
```

Replace it with:

```python
pi = strip_h1(read(os.path.join(project_cache, "INDEX.md")))
if pi:
    parts.append("# Mneme cache (this project)\n\n" + pi)

# Tier 2 notice only: name the corpora, never read their bodies/indexes.
def wiki_names(home):
    out = []
    try:
        for n in sorted(os.listdir(home)):
            if os.path.isfile(os.path.join(home, n, "index.md")):
                out.append(n)
    except OSError:
        pass
    return out
wiki_home, project_wiki = sys.argv[4], sys.argv[5]
corpora = wiki_names(wiki_home) + wiki_names(project_wiki)
if corpora:
    parts.append("# Mneme wikis\n\nWikis: " + ", ".join(corpora) + " — query with /recall --wiki <name>")

context = "\n\n---\n\n".join(parts)
```

- [ ] **Step 5: Run, expect PASS (and every prior loader test still green)**

Run: `bash tests/run.sh`
Expected: `ok - test_loader_announces_wiki_but_never_its_body`, and `test_loader_injects_protocol_and_index` / `test_loader_honors_max_chars` still `ok`. `fail=0`.

- [ ] **Step 6: Commit**

```bash
git add plugins/mneme/hooks/scripts/load-cache.sh tests/loader_test.sh
git commit -m "feat(loader): announce wikis in one line, never inject their bodies"
```

---

### Task 3: `mneme-wiki` skill (the knowledge-tier protocol)

**Files:**
- Create: `plugins/mneme/skills/mneme-wiki/SKILL.md`
- Test: `tests/skill_wiki_test.sh`

- [ ] **Step 1: Add the failing wiring test**

Create `tests/skill_wiki_test.sh`:

```bash
#!/usr/bin/env bash
test_wiki_skill_documents_the_tier() {
  local root; root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  local f="$root/plugins/mneme/skills/mneme-wiki/SKILL.md"
  assert_file "$f" "mneme-wiki skill exists" || return 1
  local body; body="$(cat "$f")"
  assert_contains "$body" "never injected" "states wikis are never injected" || return 1
  assert_contains "$body" "/mneme:ingest" "points at the ingest command" || return 1
  assert_contains "$body" "pages/" "documents the corpus layout" || return 1
}
```

- [ ] **Step 2: Run, expect FAIL**

Run: `bash tests/run.sh`
Expected: `NOT - test_wiki_skill_documents_the_tier`, exit non-zero.

- [ ] **Step 3: Create the skill**

Create `plugins/mneme/skills/mneme-wiki/SKILL.md`:

```markdown
---
name: mneme-wiki
description: The Mneme knowledge tier (Tier 2) — a per-corpus wiki built from documents, read on demand and never injected into a chat. Use when ingesting a source into a wiki, querying a wiki, or auditing one. Distinct from the lean cache (Tier 1).
---

# Mneme wiki — the knowledge tier

The cache (Tier 1) is lean and injected into every chat. A **wiki** (Tier 2) is the opposite: a per-corpus knowledge base built from your documents, read **on demand** and **never injected**. So a wiki can be large — 10–15 pages per source is fine. This is the gist's "LLM Wiki": maintained markdown over raw documents.

## Where a wiki lives

- Home: `dirname(<global cache>)/wiki/` (a sibling of `cache/`), override `MNEME_WIKI_DIR`. Project overlay: `<project>/.mneme/wiki/`.
- One **corpus** per subdir: `wiki/<corpus>/`
  - `index.md` — the corpus table of contents (Pages / Entities / Concepts). Hand-maintained.
  - `pages/<slug>.md` — summary, entity, and concept pages. Frontmatter like a cache note, but bodies may be long. Cross-link with `[[slug]]`.
  - `sources/` — the raw (and `markitdown`-converted) source files.
  - `log.md` — append-only timeline (`ingest`, `recall-filed`, `lint-fix`), via `lib/log.sh`. Never injected.

## The loop

1. **Ingest** — `/mneme:ingest <source> [--wiki <name>]` brings a document in, summarizes it into pages, and updates `index.md`.
2. **Query** — `/mneme:recall "<q>" --wiki <name>` reads `index.md` first, then the relevant pages, and answers with citations. Plain `/recall` never touches a wiki.
3. **Audit** — `/mneme:lint --wiki <name>` runs the link checks (dead `[[links]]`, orphans) over the corpus's pages.

## Shared engine

A wiki reuses `lib/` (the same as the cache): `log.sh` for `log.md`, `links.sh` for `[[link]]` graphs between pages, `md.sh` for frontmatter, `wiki.sh` for home/corpus resolution. Run helpers under explicit `bash` (the agent's shell may be zsh). The cache and the wiki are two tiers on one engine.

## The invariant

A wiki is **never injected**. The SessionStart loader emits at most one line naming the corpora (`Wikis: <names> — query with /recall --wiki <name>`); it never reads a wiki's `index.md` or pages. Knowledge enters a chat only when you query it.
```

- [ ] **Step 4: Run, expect PASS**

Run: `bash tests/run.sh`
Expected: `ok - test_wiki_skill_documents_the_tier`, `fail=0`.

- [ ] **Step 5: Commit**

```bash
git add plugins/mneme/skills/mneme-wiki/SKILL.md tests/skill_wiki_test.sh
git commit -m "feat(wiki): add mneme-wiki skill — the knowledge-tier protocol"
```

---

### Task 4: `/mneme:ingest` command

**Files:**
- Create: `plugins/mneme/commands/ingest.md`
- Test: `tests/cmd_ingest_test.sh`

**Interfaces:**
- Consumes: `mneme_wiki_home` (wiki.sh), `mneme_log_append` (log.sh), `markitdown`.

- [ ] **Step 1: Add the failing wiring test**

Create `tests/cmd_ingest_test.sh`:

```bash
#!/usr/bin/env bash
test_ingest_command_exists_and_wires() {
  local root; root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  local f="$root/plugins/mneme/commands/ingest.md"
  assert_file "$f" "ingest command exists" || return 1
  local body; body="$(cat "$f")"
  assert_contains "$body" "markitdown" "ingest converts rich files with markitdown" || return 1
  assert_contains "$body" "mneme_wiki_home" "ingest resolves the wiki home" || return 1
  assert_contains "$body" "pages/" "ingest writes summary pages" || return 1
  assert_contains "$body" "ingest" "ingest logs with the ingest op" || return 1
  assert_contains "$body" "bash <<'" "ingest runs helpers under explicit bash" || return 1
}
```

- [ ] **Step 2: Run, expect FAIL**

Run: `bash tests/run.sh`
Expected: `NOT - test_ingest_command_exists_and_wires`, exit non-zero.

- [ ] **Step 3: Create the command**

Create `plugins/mneme/commands/ingest.md`:

```markdown
---
description: Ingest a source (file or URL) into a Mneme wiki — a per-corpus knowledge base read on demand, never injected
argument-hint: "<source> [--wiki <name>] [--project]"
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, WebFetch
---

You are running `/mneme:ingest`. Add a source to a **wiki** (Tier 2 knowledge): a per-corpus markdown knowledge base, read on demand and NEVER injected into a chat. Unlike the lean cache, a wiki can be large. Governed by the `mneme-wiki` skill.

Args: $ARGUMENTS

1. **Parse args.** `<source>` is a file path or URL. `--wiki <name>` names the corpus (default `general`). `--project` targets the project wiki `./.mneme/wiki/` instead of the global wiki home.

2. **Make the corpus** (helpers are bash; your default shell may be zsh, so invoke bash explicitly, closing `SH` flush-left). For `--project`, replace the home with `./.mneme/wiki`:

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
```

- [ ] **Step 4: Run, expect PASS**

Run: `bash tests/run.sh`
Expected: `ok - test_ingest_command_exists_and_wires`, `fail=0`.

- [ ] **Step 5: Commit**

```bash
git add plugins/mneme/commands/ingest.md tests/cmd_ingest_test.sh
git commit -m "feat(ingest): add /mneme:ingest — document into a wiki corpus"
```

---

### Task 5: `--wiki` modes on `/recall` and `/mneme:lint`

**Files:**
- Modify: `plugins/mneme/commands/recall.md`
- Modify: `plugins/mneme/commands/lint.md`
- Test: `tests/cmd_wiki_modes_test.sh`

**Interfaces:**
- Consumes: `mneme_wiki_home` (wiki.sh) in both prompts.

- [ ] **Step 1: Add the failing wiring tests**

Create `tests/cmd_wiki_modes_test.sh`:

```bash
#!/usr/bin/env bash
test_recall_has_wiki_branch() {
  local root; root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  local body; body="$(cat "$root/plugins/mneme/commands/recall.md")"
  assert_contains "$body" "--wiki" "recall has a --wiki query branch" || return 1
  assert_contains "$body" "mneme_wiki_home" "recall resolves the wiki home" || return 1
}

test_lint_has_wiki_target() {
  local root; root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  local body; body="$(cat "$root/plugins/mneme/commands/lint.md")"
  assert_contains "$body" "--wiki" "lint can target a wiki corpus" || return 1
  assert_contains "$body" "mneme_wiki_home" "lint resolves the wiki home" || return 1
}
```

- [ ] **Step 2: Run, expect FAIL**

Run: `bash tests/run.sh`
Expected: both `wiki_modes` tests `NOT`, exit non-zero.

- [ ] **Step 3: Edit `recall.md`** — add a wiki branch at the top of the steps.

In `plugins/mneme/commands/recall.md`, find:

```markdown
Steps:

1. Search both caches for the query (case-insensitive), across note bodies and descriptions:
```

Insert this between `Steps:` and `1.`:

```markdown
**Wiki mode.** If the args contain `--wiki <name>`, do NOT search the lean cache. Instead query that corpus: resolve the home under bash (closing `SH` flush-left), then read `index.md` first and the relevant `pages/`, answer with citations to the page paths, and stop. You may offer to file the answer back as a new page in that corpus (`mneme_log_append "<corpus>" recall-filed "<slug>"`). Otherwise (no `--wiki`), do the cache search below.

```bash
bash <<'SH'
mneme_lib="${CLAUDE_PLUGIN_ROOT:-}/hooks/scripts/lib"
[ -f "$mneme_lib/log.sh" ] || mneme_lib="$(dirname "$(find "$HOME/.claude/plugins" -path '*/mneme/hooks/scripts/lib/log.sh' 2>/dev/null | head -1)")"
. "$mneme_lib/wiki.sh"; echo "corpus: $(mneme_wiki_home)/<name>"
SH
```

```

- [ ] **Step 4: Edit `lint.md`** — extend the scope step to accept `--wiki`.

In `plugins/mneme/commands/lint.md`, find:

```markdown
1. **Scope.** Default target is the global cache `~/.claude/mneme/cache/` (i.e. `$HOME/.claude/mneme/cache/`). If the args contain `--project`, target `./.mneme/cache/` instead. (Wiki and spine targets arrive with those tiers in later phases.)
```

Replace it with:

```markdown
1. **Scope.** Default target is the global cache `~/.claude/mneme/cache/` (i.e. `$HOME/.claude/mneme/cache/`). If the args contain `--project`, target `./.mneme/cache/`. If they contain `--wiki <name>`, target that corpus's pages: resolve `<cache-dir>` to `"$(mneme_wiki_home)/<name>/pages"` (source `lib/wiki.sh` in the bash block below). For a wiki, run the dead-link and orphan checks over the pages; skip the INDEX-drift check (a wiki `index.md` is hand-authored, not the lean cache format). (The spine target arrives in Phase 3.)
```

- [ ] **Step 5: Run, expect PASS**

Run: `bash tests/run.sh`
Expected: both `wiki_modes` tests `ok`, `fail=0`.

- [ ] **Step 6: Commit**

```bash
git add plugins/mneme/commands/recall.md plugins/mneme/commands/lint.md tests/cmd_wiki_modes_test.sh
git commit -m "feat(recall,lint): add --wiki query and audit modes"
```

---

### Task 6: Document Tier 2 in `mneme-engine` + Phase 2 checkpoint

**Files:**
- Modify: `plugins/mneme/skills/mneme-engine/SKILL.md`
- Test: `tests/skill_engine_test.sh` (extend)

- [ ] **Step 1: Add the failing assertion**

In `tests/skill_engine_test.sh`, inside `test_engine_documents_phase1`, add before the final `}` of the function (after the existing `assert_contains ... "Cross-ref" ...` line):

```bash
  assert_contains "$body" "Tier 2" "engine names the knowledge tier" || return 1
  assert_contains "$body" "/mneme:ingest" "engine lists the ingest command" || return 1
```

- [ ] **Step 2: Run, expect FAIL**

Run: `bash tests/run.sh`
Expected: `NOT - test_engine_documents_phase1`, exit non-zero.

- [ ] **Step 3: Edit `SKILL.md`** — add a tiers section.

In `plugins/mneme/skills/mneme-engine/SKILL.md`, find:

```markdown
## The loop engine
```

Insert this new section immediately BEFORE it:

```markdown
## Two tiers: cache and wiki

Mneme has two tiers on one engine. **Tier 1 — the cache** (everything above): lean, gate-kept, injected into every chat. **Tier 2 — a wiki**: a per-corpus knowledge base built from documents, read on demand and **never injected** (the loader only names the corpora). A wiki can be large; the cache must stay lean. Build one with `/mneme:ingest <source> --wiki <name>`, query it with `/mneme:recall "<q>" --wiki <name>`, audit it with `/mneme:lint --wiki <name>`. Governed by the `mneme-wiki` skill.
```

- [ ] **Step 4: Edit the command list** — add `/mneme:ingest`.

In the `## Commands` section, find:

```markdown
- `/mneme:lint [--project]` — read-only audit (dead links, orphans, INDEX drift, contradictions); fixes on confirmation.
```

Insert immediately after it:

```markdown
- `/mneme:ingest <source> [--wiki <name>] [--project]` — ingest a document into a wiki (Tier 2 knowledge, never injected).
```

- [ ] **Step 5: Run — full Phase 2 checkpoint**

Run: `bash tests/run.sh`
Expected: every `test_*` is `ok`. Phase 2 adds 7 functions (wiki_home, wiki_names, loader-wiki, wiki-skill, ingest, recall-wiki, lint-wiki) to the 16 from Phase 1 → `pass=23 fail=0`, exit 0. The gate that matters is `fail=0`.

- [ ] **Step 6: Manual smoke (real session, throwaway wiki)**

With the plugin loaded, against a throwaway `MNEME_GLOBAL_DIR`: `/mneme:ingest <some.md> --wiki test` (confirm `wiki/test/{index.md,pages/,sources/}` appear and a `log.md` line), restart and confirm the SessionStart context shows a single `Wikis: test …` line (and NOT any page content), then `/mneme:recall "<q>" --wiki test` returns a cited answer. This proves the tier is built, announced-not-injected, and queryable.

- [ ] **Step 7: Commit**

```bash
git add plugins/mneme/skills/mneme-engine/SKILL.md tests/skill_engine_test.sh
git commit -m "docs(engine): document Tier 2 (the wiki) and /mneme:ingest"
```

---

## Self-Review

**1. Spec coverage (Phase 2 scope, spec §7–§8 + §11):**
- `lib/wiki.sh` home + corpus resolution → Task 1. ✓
- Loader one-line wiki notice, size-gated, bodies never injected → Task 2 (with the invariant as its own test). ✓
- `mneme-wiki` skill (layout, ingest/query/audit, shared engine, the never-injected invariant) → Task 3. ✓
- `/mneme:ingest` (source resolve, markitdown for rich files, sources/ + pages/, index update, log) → Task 4. ✓
- `/recall --wiki` (index-first then pages, cite, optional file-back) → Task 5. ✓
- `/mneme:lint --wiki` (link checks over the corpus pages) → Task 5. ✓
- Engine doc + command list → Task 6. ✓
- Deferred: `--spine` (Phase 3); README rewrites + version bump + explainer tier-2-live (Phase 4); embeddings/external search (future seam, spec §13).

**2. Placeholder scan:** No TBD/TODO. Lib + loader steps are complete runnable code; prompts show full content. Placeholders like `<name>`, `<slug>`, `<corpus>` are author-substituted values inside quoted heredocs (same pattern as Phase 1), not plan gaps.

**3. Type/name consistency:** `mneme_wiki_home`, `mneme_wiki_names`, `mneme_log_append` (op `ingest`/`recall-filed`/`lint-fix`) are used identically across `wiki.sh`, the loader, ingest/recall/lint, and the skill docs. The loader's python `wiki_names` mirrors the bash `mneme_wiki_names` contract (a corpus = a subdir with `index.md`). Wiki home derivation is the same expression in `wiki.sh` (`mneme_wiki_home`) and the loader bash (`${MNEME_WIKI_DIR:-$(dirname "$GLOBAL_CACHE")/wiki}`).

**Note on Step 5 of Task 6:** `pass=23` = 16 (Phase 1) + 7 Phase 2 functions (2 in `lib_wiki_test.sh`, 1 in `loader_test.sh`, 1 in `skill_wiki_test.sh`, 1 in `cmd_ingest_test.sh`, 2 in `cmd_wiki_modes_test.sh`) — note `test_engine_documents_phase1` is extended, not added. The gate that matters is `fail=0`.
```
