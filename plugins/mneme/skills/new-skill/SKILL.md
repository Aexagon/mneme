---
name: new-skill
description: Scaffold a new skill for the Mneme bay (or for personal use) with skill-creator, then wire it to read/write the Mneme cache. Use when the user wants to add a skill to Mneme, build a new capability for the engine, or create a skill that learns into the cache.
---

# Add a skill to Mneme

Mneme's skill bay is just the plugin's `skills/` directory — any skill placed there is auto-discovered. This skill adds the Mneme conventions on top of normal skill creation.

## Steps

1. **Scaffold with skill-creator.** Invoke the `skill-creator` skill to design and write the new skill properly (name, trigger-rich description, structure, validation). Do not reinvent that process.

2. **Place it.**
   - To ship it with Mneme (shareable): `~/Desktop/Claude/mneme/plugins/mneme/skills/<skill-name>/SKILL.md`.
   - For a quick personal-only skill: `~/.claude/skills/<skill-name>/SKILL.md` is fine.

3. **Wire it to the cache (encouraged).** If the skill benefits from memory, follow the `mneme-engine` skill's "How a skill reads or writes the cache" section:
   - Read relevant notes from `~/.claude/mneme/cache/` (+ project overlay).
   - Write durable learnings back via `/mneme:remember` or the note schema.

4. **Description discipline.** The skill's `description` is how it gets discovered. Make it specific and trigger-rich, per skill-creator's guidance.

Keep skills small and single-purpose. A skill you can hold in your head is a skill that works.
