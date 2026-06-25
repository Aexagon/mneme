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
