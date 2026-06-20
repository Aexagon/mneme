# Mneme auto-distill v2 — capture automatically, pull on demand

- Date: 2026-06-20
- Status: approved (Jerry, 2026-06-20)

## Goal

Make Mneme's background distiller **ON by default**, while keeping auto-captured
notes out of the trusted, always-loaded cache until the user pulls them.

## Behavior

- The `SessionEnd` distiller runs by default. Disable with `distill=off` in
  `~/.claude/mneme/config` (or `MNEME_DISTILL_ENABLED=0`). Env overrides config.
- Auto-captured notes are **quarantined**: the `SessionStart` loader only ever reads
  `cache/*.md` + `cache/INDEX.md`. The inbox is never injected into a chat.
- Notes land as one-per-file markdown in `~/.claude/mneme/inbox/` (a sibling of
  `cache/`, meant to be browsed). The legacy `cache/_pending/` tray is migrated into
  `inbox/` on first run.
- The user "pulls" the inbox on their own schedule: `/mneme:review` (assisted —
  keep/discard, dedupe + promote into the live cache), or open the folder directly.

## Guards (ON-by-default spends tokens)

1. `SessionEnd` hook timeout raised 10s → 120s (kept `async`) so the headless Sonnet
   call can finish. Without this, default-on is a silent no-op.
2. Min-session gate: skip the model call when the cleaned transcript is under ~1500
   chars (override `MNEME_DISTILL_MIN_CHARS`). No model call on trivial chats.
3. Recursion guard unchanged: the headless child runs with `MNEME_DISTILL=1`; the
   distiller exits immediately when it sees that var.

## Cost

Each non-trivial session close ≈ one headless Sonnet call over ≤40k chars of
transcript. Mitigations: the min-session gate, an easy `distill=off`, and explicit
docs that it is on.

## Files

- `hooks/hooks.json` — `SessionEnd` timeout 10 → 120.
- `hooks/scripts/distill.sh` — invert enabled default; `inbox/` path + `_pending/`
  migration; min-session gate.
- `commands/review.md`, `commands/status.md` — read `inbox/`; status reports auto=ON
  + inbox count + the `distill=off` opt-out.
- `skills/mneme-engine/SKILL.md`, `README.md`, `plugins/mneme/README.md` — document
  auto-on + inbox + pull-on-demand; config note flips to "disable with distill=off".
- `hooks/scripts/load-cache.sh` — unchanged (never read the tray; inbox is a sibling
  of `cache/`, outside the loader's view).

## Test (no real tokens)

Drive `distill.sh` with `MNEME_DISTILL_STUB` (a canned JSON array) + a synthetic
transcript and assert:
- notes land in `inbox/` (not in `cache/`),
- the recursion guard exits immediately when `MNEME_DISTILL=1`,
- the min-session gate skips a short transcript (no inbox writes),
- legacy `cache/_pending/` notes migrate into `inbox/`,
- the `SessionStart` loader still does NOT inject inbox notes.
