# Mneme architecture

Mneme maintains markdown that compounds. Two tiers sit on one engine, plus an optional spine.

- **Tier 1 — memory.** Lean, gate-kept, injected into every chat. Source: your chats. Lives in `cache/`.
- **Tier 2 — knowledge.** A per-corpus wiki read on demand, never injected. Source: your documents. Lives in `wiki/<corpus>/`.
- **Spine.** An optional cross-agent overlay keyed by `MNEME_SPINE_DIR`, off by default. Claude maintains it; other agents read it.

The code (this repo) is separate from the data (memory / wiki / spine, all outside the repo). Inside the code, a shared `hooks/scripts/lib/` (`log`, `md`, `links`) backs both tiers, so there is one implementation of the markdown / index / log / link primitives.

See `docs/specs/2026-06-25-mneme-gaps-and-folders-design.md` for the full design.
