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
