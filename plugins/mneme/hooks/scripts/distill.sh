#!/usr/bin/env bash
# Mneme — background distiller (Phase 6a).
# Fires on SessionEnd. Reads the conversation transcript, asks Sonnet to extract
# durable, reusable notes (the relevance gate), and writes them to a PENDING tray
# for you to review with /mneme:review.
#
# Ships OFF: runs only when explicitly enabled. Guarded against recursion so the
# headless model call it spawns can never re-trigger the distiller.
set -uo pipefail

# 1) Recursion guard — never run inside a distiller-spawned session.
[ -n "${MNEME_DISTILL:-}" ] && exit 0

GLOBAL_CACHE="${MNEME_GLOBAL_DIR:-$HOME/.claude/mneme/cache}"
PENDING_DIR="$GLOBAL_CACHE/_pending"
CONFIG="${MNEME_CONFIG:-$HOME/.claude/mneme/config}"
MODEL="${MNEME_DISTILL_MODEL:-claude-sonnet-4-6}"

# 2) Enabled check — OFF unless env var is set or the config says distill=on.
enabled=0
[ "${MNEME_DISTILL_ENABLED:-0}" = "1" ] && enabled=1
[ -f "$CONFIG" ] && grep -qiE '^[[:space:]]*distill[[:space:]]*=[[:space:]]*(on|1|true|yes)[[:space:]]*$' "$CONFIG" && enabled=1
[ "$enabled" = "1" ] || exit 0

# 3) Read the hook JSON from stdin and pull the transcript path.
HOOK_JSON="$(cat 2>/dev/null || true)"
TRANSCRIPT="$(printf '%s' "$HOOK_JSON" | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("transcript_path",""))
except Exception: print("")' 2>/dev/null || true)"
[ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ] || exit 0

# 4) Build the distiller prompt: a cleaned transcript excerpt + the current index (for dedup).
PROMPT="$(python3 - "$TRANSCRIPT" "$GLOBAL_CACHE/INDEX.md" <<'PY'
import json, sys
transcript, index_path = sys.argv[1], sys.argv[2]
MAX_CHARS = 40000  # bound cost: keep the most recent slice of long sessions

def read_text(p):
    try:
        with open(p, encoding="utf-8") as f:
            return f.read()
    except OSError:
        return ""

msgs = []
for line in read_text(transcript).splitlines():
    line = line.strip()
    if not line:
        continue
    try:
        obj = json.loads(line)
    except Exception:
        continue
    msg = obj.get("message") if isinstance(obj.get("message"), dict) else {}
    role = obj.get("role") or msg.get("role") or obj.get("type")
    content = obj.get("content")
    if content is None:
        content = msg.get("content")
    text = ""
    if isinstance(content, str):
        text = content
    elif isinstance(content, list):
        parts = [c.get("text", "") for c in content
                 if isinstance(c, dict) and c.get("type") in ("text", None) and c.get("text")]
        text = "\n".join(parts)
    if text and role in ("user", "assistant", "human"):
        msgs.append(f"{role.upper()}: {text}")

convo = "\n\n".join(msgs)
if len(convo) > MAX_CHARS:
    convo = convo[-MAX_CHARS:]
if not convo.strip():
    sys.exit(0)

index = read_text(index_path).strip()

print(f"""You are the Mneme distiller. Extract ONLY durable, reusable learnings from the conversation below.

The relevance gate: a learning qualifies ONLY if it is BOTH durable (still true next month) AND reusable in a DIFFERENT future chat (a stable fact, a preference, a repeatable pattern, a reference). Ignore anything tied to just this conversation. When in doubt, leave it out. A few high-quality notes beat many.

Do not duplicate what the cache already knows. Current index:
{index or '(empty)'}

Output ONLY a JSON array, nothing else (no prose, no code fences). Each element:
{{"name": "kebab-slug", "description": "one line", "type": "fact|preference|pattern|reference|project", "body": "the durable, reusable note"}}
Output [] if nothing passes the gate.

CONVERSATION:
{convo}
""")
PY
)"
[ -n "$PROMPT" ] || exit 0

# 5) Ask the model (unless a test stub is supplied). MNEME_DISTILL=1 guards the child.
if [ -n "${MNEME_DISTILL_STUB:-}" ] && [ -f "$MNEME_DISTILL_STUB" ]; then
  RESPONSE="$(cat "$MNEME_DISTILL_STUB")"
else
  command -v claude >/dev/null 2>&1 || exit 0
  RESPONSE="$(printf '%s' "$PROMPT" | MNEME_DISTILL=1 claude -p --model "$MODEL" 2>/dev/null || true)"
fi
[ -n "$RESPONSE" ] || exit 0

# 6) Parse the JSON array and write each proposed note into the PENDING tray.
# Response goes via a temp file (NOT stdin): the heredoc below already occupies
# python's stdin, so piping the response in would be silently discarded.
RESP_FILE="$(mktemp)"
printf '%s' "$RESPONSE" > "$RESP_FILE"
python3 - "$PENDING_DIR" "$RESP_FILE" <<'PY'
import json, sys, os, re
pending_dir, resp_file = sys.argv[1], sys.argv[2]
with open(resp_file, encoding="utf-8") as f:
    raw = f.read().strip()
raw = re.sub(r'^```(?:json)?|```$', '', raw, flags=re.MULTILINE).strip()
m = re.search(r'\[.*\]', raw, re.DOTALL)
if not m:
    sys.exit(0)
try:
    notes = json.loads(m.group(0))
except Exception:
    sys.exit(0)
if not isinstance(notes, list) or not notes:
    sys.exit(0)

def slug(s):
    return re.sub(r'[^a-z0-9]+', '-', (s or '').lower()).strip('-') or 'note'

os.makedirs(pending_dir, exist_ok=True)
for n in notes:
    if not isinstance(n, dict):
        continue
    body = (n.get("body") or "").strip()
    if not body:
        continue
    name = slug(n.get("name") or n.get("description"))
    desc = (n.get("description") or "").strip().replace("\n", " ")
    typ = (n.get("type") or "fact").strip()
    with open(os.path.join(pending_dir, f"{typ}-{name}.md"), "w", encoding="utf-8") as f:
        f.write(f"---\nname: {name}\ndescription: {desc}\ntype: {typ}\nsource: auto\n---\n\n{body}\n")
PY
rm -f "$RESP_FILE"
exit 0
