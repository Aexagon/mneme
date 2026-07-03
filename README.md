# Mneme

**Mneme gives Claude a memory that carries across chats.** Normally every conversation starts from a blank slate — Claude forgets your preferences, your business, the way you like things done. With Mneme installed, Claude quietly remembers the durable things you tell it and picks them up in every new chat, so you stop repeating yourself.

You don't have to learn anything. Just talk to Claude the way you already do.

> **New here?** Open [`docs/explainer/guide.html`](docs/explainer/guide.html) in your browser — a one-page, plain-language guide to what Mneme does, how to use it, and how to install it. It's written for someone who has never installed a plugin.

## Install

Paste these two lines into Claude Code, one at a time:

```
/plugin marketplace add Aexagon/mneme
/plugin install mneme@mneme
```

Then restart the session. That's it — you'll see a short "Mneme is active" note at the top of your chats. From then on it just works in the background. There is nothing to configure and nothing to remember.

## How to use it

Talk to Claude normally. Mneme listens for a few natural things and handles them for you:

- **Tell it to remember.** "Remember that I prefer short bullet-point replies." "For future reference, my company is called Acme." Claude saves it and says "Got it — I'll remember that." Next chat, it already knows.
- **Ask what it knows.** "What do you know about my business?" Claude checks its memory and tells you.
- **Ask it to forget.** "Forget what I told you about the old logo." Claude removes it.
- **Ask it to tidy up.** "Clean up your memory." Claude prunes duplicates and out-of-date notes (it'll check with you before deleting anything).

Claude also quietly notes useful things as you work, and every so often it'll offer to fold them into memory — just say yes to the ones you want. You never have to manage any of this yourself.

That's the whole thing. Everything below is for the curious and for power users.

---

## Under the hood

<details>
<summary>How Mneme actually works (optional reading)</summary>

Mneme is a self-improving engine for Claude Code. A persistent cache loads into every chat, and each chat can write durable learnings back to it so the next chat starts ahead. For the full plain-language walkthrough, open `docs/explainer/index.html` in your browser.

### What you get

- **A cache that lives in all chats.** A SessionStart hook loads a global cache (and an optional per-project overlay) into every conversation.
- **A learning loop.** Save durable, reusable learnings as you work or on command, and the next chat starts ahead.
- **A knowledge tier (wiki).** Ingest whole documents into a per-topic wiki and query it on demand — it never gets injected wholesale, so it can be as big as you need.
- **A skill bay.** Drop skills in and they are auto-discovered; skills can read and write the same cache.

### Two tiers: memory and knowledge

Mneme keeps two different kinds of information, on purpose, so neither one bloats the other:

- **Tier 1 — memory (the cache).** Small, durable notes — facts, preferences, patterns. Kept lean on purpose and **injected into every chat** via `INDEX.md`, so Claude always has it without asking.
- **Tier 2 — knowledge (the wiki).** Whole documents you `/mneme:ingest` into a named corpus (a handbook, a policy doc, a project spec). It can be as large as you need, and is **read on demand** with `/mneme:recall --wiki <name>` — it is never dumped into a chat wholesale, only named so you know it is there.

Rule of thumb: save a one-line fact or preference to the cache; ingest a whole document into a wiki.

### How it stays healthy

- **Code** lives in the plugin. **Data** (the cache) lives outside it, at `~/.claude/mneme/cache/` (global) and `<project>/.mneme/cache/` (project overlay), so updating the plugin never wipes your memory.
- The cache is small atomic notes plus a lean `INDEX.md`. The index is injected into every chat, so it is kept short by design; note bodies are read on demand.
- Two rules keep it healthy: (1) the **relevance gate** — only save what would help a *different future chat*, durable AND reusable; (2) the **lean index** — one fact per file, keep `INDEX.md` short or it stops loading.

### Automatic capture (on by default)

A background distiller catches learnings on sessions where nobody saved anything. It ships **on**; disable with `echo 'distill=off' >> ~/.claude/mneme/config`.

- Fires on **SessionEnd**, reads the transcript, and asks **Sonnet 5** (`claude-sonnet-5`) to extract only durable, reusable notes — the smallest model that applies the relevance gate reliably (Haiku was tested and under-captures). Override with `MNEME_DISTILL_MODEL` (same relevance gate, deduped against the index). Trivially short sessions are skipped (no model call).
- It **captures to an inbox, and gets folded in on demand:** notes land as markdown in `~/.claude/mneme/inbox/` and are never injected into chats. Claude will offer to fold them into memory during normal conversation; power users can also run `/mneme:review`, or just open the folder and promote what they want.
- A recursion guard stops the headless model call from re-triggering the distiller.

</details>

<details>
<summary>Commands (optional — for power users)</summary>

Everything below happens automatically from plain conversation. These commands are just explicit shortcuts for the same operations.

- `/mneme:remember "<learning>" [--project]` — save a durable, reusable learning.
- `/mneme:recall "<query>"` — search the cache. Add `--wiki <name>` to query a knowledge-tier corpus instead (e.g. `/mneme:recall "refund policy" --wiki handbook`).
- `/mneme:status [prune]` — status, health, and pruning.
- `/mneme:review` — pull the inbox: review notes the auto-distiller proposed.
- `/mneme:lint [--project | --wiki <name>]` — read-only audit for dead links, orphan notes, and index drift; fixes only on confirmation.
- `/mneme:ingest <source> [--wiki <name>] [--project]` — ingest a file or URL into a wiki (Tier 2 knowledge).
- `/mneme:loop "<goal>" --done "<criterion>"` — drive a goal to completion, verifying each pass.

### The loop engine

Memory is the outer loop (every new chat starts smarter). `/mneme:loop` is the inner loop: it drives one goal to completion in the current chat.

```
/mneme:loop "make the test suite green" --done "npm test exits 0" --max 8
```

It primes from the cache, then runs plan -> act -> verify -> repeat against the success criterion YOU state, capturing learnings each pass. It stops honestly: success (verified against your criterion), stuck (no progress, it asks rather than spins), or incomplete (hit the cap, reports what is left). Because each pass reads and writes the cache, the same goal run twice gets faster, and future tasks inherit what it learned.

See the `mneme-engine` skill for the full protocol.

</details>

<details>
<summary>Layout</summary>

```
mneme/                                  (git repo = marketplace)
  .claude-plugin/marketplace.json
  docs/explainer/                       guide.html (client one-pager) + index.html (full manual)
  plugins/mneme/
    .claude-plugin/plugin.json
    hooks/         hooks.json + scripts/ (load-cache.sh, distill.sh)
    assets/        protocol-snippet.md
    commands/      remember.md, recall.md, status.md, review.md, lint.md, ingest.md, loop.md
    skills/        mneme-engine/, mneme-wiki/, new-skill/
    README.md
```

</details>
