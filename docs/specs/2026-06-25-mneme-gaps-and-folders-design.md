# Mneme: gap-fill + folder optimisation (design)

- **Date:** 2026-06-25
- **Status:** Approved; tests-first folded in; proceeding to the implementation plan
- **Author:** Jerry (collab@aexagon.com)
- **Approach:** A — core-ready, not core-resident (full reorg + all gaps + a dormant shared-spine; nothing created or moved under `~/core`)

## 1. Context and goal

Mneme is a published Claude Code plugin (marketplace `Aexagon/mneme`) that loads a lean
markdown cache into every chat and learns across sessions. Karpathy's "LLM Wiki" gist
(`gist.github.com/karpathy/442a6bf555914893e9891c11519de94f`) describes the same pattern
at a second scale: an LLM-maintained knowledge base over a corpus of raw documents, read
on demand. Mapping the gist onto Mneme exposed concrete gaps.

This work closes all of them in one spec, and restructures the repo with folders, applying
Jerry's own `~/core` convention (separate identity / knowledge / work; legible to any tool;
VS Code multi-root workspaces with watcher excludes).

The unifying frame: **Mneme is the bookkeeper of the shared spine.** The memory tier is
cross-chat memory; the knowledge tier is the gist's wiki; the spine is the cross-agent
`shared/` layer. Claude (running the hooks) maintains all three; other agents read what
it maintains.

## 2. Scope

**In:** folder reorg (repo + runtime data layout); a shared engine `lib/`; four memory-tier
upgrades (`log.md`, cross-ref propagation, recall-files-back, `/lint`); the knowledge tier
(`/ingest` + a maintained wiki + `/recall --wiki` + wiki lint); a dormant cross-agent spine
(`MNEME_SPINE_DIR` overlay + pointer template); docs + a `.code-workspace`; version bump to
v0.3.0.

**Out (explicitly):** creating anything under `~/core`; moving the workspace; relocating any
existing cache data; editing other agents' real bootstrap files (we ship a template only);
embeddings or an external search engine (e.g. qmd) — left as a future seam.

## 3. Architecture

Two tiers on one engine, plus an optional spine.

- **Tier 1 — memory.** Lean, gate-kept, always injected. Source: chats. Lives in `cache/`.
- **Tier 2 — knowledge.** Per-corpus wiki, read on demand, never injected. Source: documents.
  Lives in `wiki/<corpus>/`.
- **Spine — cross-agent.** Optional overlay keyed by `MNEME_SPINE_DIR`; off by default.

Code (the repo) is separated from data (memory / wiki / spine, all outside the repo). Inside
the code, one shared `lib/` backs both tiers so there is a single implementation of the
markdown/index/log/link primitives.

## 4. Folder structure

### 4.1 Repo (code)

```
mneme/
├── README.md                         rewritten: two tiers, new commands, the spine
├── LICENSE
├── mneme.code-workspace              NEW · roots = plugin + docs; files.watcherExclude
├── .claude-plugin/marketplace.json   description updated
├── tests/                            NEW · lib unit tests + load-cache/distill smoke tests + fixtures
├── docs/
│   ├── README.md                     NEW · docs index
│   ├── explainer/index.html          moved from docs/mneme-explainer.html; tier-2 → live in Phase 4
│   ├── design/
│   │   ├── architecture.md           NEW · two tiers + spine
│   │   └── data-layout.md            NEW · runtime layout + env vars
│   └── specs/
│       ├── 2026-06-20-auto-distill-default.md
│       └── 2026-06-25-mneme-gaps-and-folders-design.md   (this file)
└── plugins/mneme/
    ├── .claude-plugin/plugin.json    version 0.2.0 → 0.3.0
    ├── README.md                     updated
    ├── commands/                     flat (subfolders would rename /mneme:x)
    │   ├── remember.md               + cross-ref propagation + log
    │   ├── recall.md                 + file-the-answer-back + --wiki query
    │   ├── status.md                 + log tail + spine/wiki awareness
    │   ├── review.md
    │   ├── loop.md
    │   ├── lint.md                   NEW
    │   └── ingest.md                 NEW
    ├── hooks/
    │   ├── hooks.json                paths updated for lib/ + assets/
    │   └── scripts/
    │       ├── lib/                  NEW · shared engine
    │       │   ├── log.sh
    │       │   ├── md.sh
    │       │   └── links.sh
    │       ├── load-cache.sh         + spine overlay + wiki notice; never injects log/wiki
    │       └── distill.sh            asset path updated
    ├── skills/
    │   ├── mneme-engine/SKILL.md     + log + cross-ref + lint protocol
    │   ├── mneme-wiki/SKILL.md       NEW · knowledge-tier protocol
    │   └── new-skill/SKILL.md
    └── assets/                       NEW
        ├── protocol-snippet.md       moved from hooks/scripts/
        └── spine-pointer.md          NEW · cross-agent bootstrap block
```

### 4.2 Runtime data (outside the repo; mirrors `~/core` memory / knowledge / spine)

```
~/.claude/mneme/                      home = dirname of the global cache
├── cache/                            TIER 1 · memory (always loaded, lean)
│   ├── INDEX.md
│   ├── log.md                        NEW · append-only, NOT injected
│   └── <type>-<slug>.md
├── inbox/                            distiller quarantine (/review)
├── wiki/                             TIER 2 · knowledge (on demand, NEVER injected)
│   └── <corpus>/  { index.md · log.md · sources/ · pages/ }
└── config

<project>/.mneme/{cache,wiki}/        project overlay (same shape)

MNEME_SPINE_DIR → ~/core/shared/      cross-agent spine — unset by default
```

## 5. The shared engine (`hooks/scripts/lib/`)

POSIX-ish bash, sourced by scripts and invoked by command prompts.

- **`log.sh`** — `mneme_log_append <cache_dir> <op> <slug> [note]`
  appends `## [YYYY-MM-DD] <op> | <slug>[ — note]` to `<cache_dir>/log.md` (creates with a
  `# Mneme log` header if absent). `op ∈ {remember, promote, prune, recall-filed, lint-fix, ingest}`.
- **`md.sh`** — `mneme_md_frontmatter_get <file> <key>`,
  `mneme_md_index_upsert <cache_dir> <file> <title> <description>`,
  `mneme_md_index_remove <cache_dir> <file>`. Mechanical INDEX.md bookkeeping; note bodies
  are still authored by the command prompts.
- **`links.sh`** — `mneme_links_in_note <file>`, `mneme_links_inbound <cache_dir> <slug>`,
  `mneme_links_add <file> <slug>` (idempotent; appends to a `Related:` line),
  `mneme_links_orphans <cache_dir>`, `mneme_links_dead <cache_dir>`.

These give cross-ref and lint their mechanical backbone; semantic judgments stay with the agent.

## 6. Memory-tier mechanisms

1. **`log.md`.** Each cache dir gets one, written via `log.sh` from remember/review/status/recall/lint.
   Never injected. `/status` shows the last 5 (`grep "^## \[" log.md | tail -5`).
2. **Cross-ref on `/remember`.** After writing + indexing a note, find the top related notes
   (term/type overlap) and add reciprocal `[[links]]` both directions via `links.sh`. Capped at
   **≤3** touched notes. Log the save.
3. **Recall files back.** When `/recall` synthesizes across ≥2 notes, it ends by offering to save
   the synthesis as a new note (type usually `reference`/`pattern`), cross-referenced to sources.
   Opt-in; recall stays read-only unless confirmed.
4. **`/mneme:lint`.** New command. Read-only report; fixes on confirm only. Target: cache (default),
   `--project`, `--wiki <name>`, or `--spine`. Checks: contradictions, orphan notes, dead `[[links]]`,
   concepts referenced but lacking a note, stale claims, INDEX-vs-files drift. `/status` keeps its
   lighter prune and points here.

## 7. Knowledge-tier mechanisms

- **`/mneme:ingest <source> [--wiki <name>] [--project]`.** The gist's Ingest:
  1. Resolve source (file or URL). Rich files (PDF/DOCX/PPTX/...) go through `markitdown` first;
     raw + converted land in `wiki/<name>/sources/`.
  2. Read, discuss takeaways, write a summary page in `pages/`, update/create entity & concept pages,
     update `index.md`, append to `log.md`. 10–15 pages per source is fine (the wiki never loads).
  3. Governed by `mneme-wiki/SKILL.md`, using the same `lib/`.
- **Wiki layout (per corpus):** `wiki/<corpus>/{ index.md, log.md, sources/, pages/ }`. Wiki home is a
  sibling of `cache/` (derived as `dirname(global cache)/wiki`; override `MNEME_WIKI_DIR`).
- **Query:** `/recall "<q>" --wiki <name>` reads index-first then pages, cites, and can file the answer
  back as a new wiki page. Plain `/recall` still only touches the lean cache.
- **Lint:** `/mneme:lint --wiki <name>` reuses the audit engine on a corpus.
- **Loader:** if any wiki exists, `load-cache.sh` injects at most one line
  (`Wikis: <names> — query with /recall --wiki <name>`), size-gated. Wiki bodies/indexes never load.

## 8. The spine (cross-agent, core-ready)

- **`MNEME_SPINE_DIR`** (new, unset by default). When set (e.g. `~/core/shared/`), `load-cache.sh`
  appends a `# Mneme spine (shared)` section from `$MNEME_SPINE_DIR/INDEX.md`, ordered
  protocol → global → **spine** → project → wiki-notice, under the same `MNEME_MAX_CHARS` cap.
- **`--spine` flag** on `/remember` and `/lint` targets the spine dir.
- **`assets/spine-pointer.md`** — copy-paste block for other agents' `AGENTS.md` / `HERMES.md` /
  `CODEX.md`: "Before anything, read `~/core/shared/INDEX.md` and the linked notes." Mneme maintains
  the spine; other agents read it.
- Creates nothing, moves nothing. Activation is documented (set the env var, point it at
  `~/core/shared/` when that exists). Fully reversible (unset the var).

## 9. Backward compatibility

With no env vars set and no `log.md`/wiki created, behavior is identical to today. `log.md` and wikis
are created lazily on first use. New commands are additive. The reorg updates internal paths atomically
(`hooks.json`, `load-cache.sh`, `distill.sh`), so an installed copy updates cleanly. Existing caches at
`~/.claude/mneme/` are untouched by the reorg (data lives outside the repo).

## 10. Testing

**Test-first.** `tests/run.sh` is the first artifact built in Phase 0, before the reorg moves a single
file, so there is a green baseline to protect. Each later phase adds its tests alongside (ideally before)
its code, and `bash tests/run.sh` must stay green at every phase boundary.

- **`lib/` units:** `log.sh`, `links.sh`, `md.sh` (append a log line; add/detect/list links; find
  orphans/dead links; index upsert/remove). Plain-bash assertions, `bats` if available.
- **`load-cache.sh` smoke:** temp cache → assert injected JSON sections, `MNEME_MAX_CHARS` truncation,
  spine included only when `MNEME_SPINE_DIR` set, `log.md`/wiki never present.
- **`distill.sh`:** via `MNEME_DISTILL_STUB`, assert `source: auto` inbox notes.
- **Commands:** repeatable manual smoke run against a seeded fixture cache after install.
- Lives in top-level `tests/` (loader ignores it).

## 11. Build sequence (backward-compatible after every phase)

- **Phase 0 — Test harness + reorg + `lib/`.** FIRST write `tests/run.sh` (smoke-tests the current
  `load-cache.sh` and `distill.sh` against a throwaway `MNEME_GLOBAL_DIR`), establishing a green baseline
  before anything moves. Then build `log/md/links` with their unit tests, move files, update `hooks.json`
  + `load-cache` paths, relocate `protocol-snippet` and the explainer, add `docs/design/` +
  `mneme.code-workspace`. Checkpoint: `bash tests/run.sh` green and every existing command still works.
- **Phase 1 — Memory upgrades.** `log.md` wiring, cross-ref on remember, recall-files-back, `/lint`.
- **Phase 2 — Knowledge tier.** `mneme-wiki` skill, `/ingest`, `/recall --wiki`, `/lint --wiki`, loader
  wiki notice.
- **Phase 3 — Spine.** `MNEME_SPINE_DIR` overlay, `--spine` flags, `spine-pointer.md`, activation docs.
- **Phase 4 — Docs + version.** Rewrite both READMEs, write `docs/design/`, bump plugin to v0.3.0 +
  marketplace description, flip the explainer's tier-2 panel to live.

## 12. Decisions of record

- Approach **A** (core-ready, not resident): no `~/core` created, no data moved.
- `/mneme:lint` is its own command, not folded into `/status`.
- Recall files back by **offer**, not auto-save (keeps recall read-only by default).
- Wiki query is `/recall --wiki`, not a separate `/mneme:ask`.
- Cross-ref capped at **≤3** notes per save (protects the lean cache).
- Commands stay **flat** (preserve `/mneme:<x>` names).
- Spec lives in this repo's `docs/specs/` (not the skill default path).
- **No auto-commit:** the spec and all changes are committed only on Jerry's say-so.

## 13. Future seams (not now)

External search (qmd) or embeddings over large wikis; activating `~/core` and relocating the spine;
batch ingest; Obsidian/`pull my notes` as a wiki source; other agents' real bootstrap edits.
