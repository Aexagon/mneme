#!/usr/bin/env bash
# Mneme — background distiller.
# Fires on SessionEnd. Reads the conversation transcript, asks Sonnet to extract
# durable, reusable notes (the relevance gate), and writes them as markdown into the
# INBOX (`~/.claude/mneme/inbox/`) for you to pull on your own schedule with
# /mneme:review. Inbox notes are NEVER injected into a chat until you promote them.
#
# Ships ON by default. Disable with `distill=off` in ~/.claude/mneme/config (or
# MNEME_DISTILL_ENABLED=0). Guarded against recursion so the headless model call it
# spawns can never re-trigger the distiller.
set -uo pipefail

# 1) Recursion guard — never run inside a distiller-spawned session.
[ -n "${MNEME_DISTILL:-}" ] && exit 0

GLOBAL_CACHE="${MNEME_GLOBAL_DIR:-$HOME/.claude/mneme/cache}"
MNEME_DIR="$(dirname "$GLOBAL_CACHE")"
INBOX_DIR="$MNEME_DIR/inbox"
LEGACY_PENDING="$GLOBAL_CACHE/_pending"
CONFIG="${MNEME_CONFIG:-$HOME/.claude/mneme/config}"
MODEL="${MNEME_DISTILL_MODEL:-claude-sonnet-4-6}"
MIN_CHARS="${MNEME_DISTILL_MIN_CHARS:-1500}"

# 2) One-time migration: fold the legacy pending tray (cache/_pending) into the inbox.
if [ -d "$LEGACY_PENDING" ]; then
  mkdir -p "$INBOX_DIR"
  find "$LEGACY_PENDING" -maxdepth 1 -type f -name '*.md' -exec mv -n {} "$INBOX_DIR/" \; 2>/dev/null || true
  rmdir "$LEGACY_PENDING" 2>/dev/null || true
fi

# 3) Enabled check — ON by default. Off only if the config says distill=off, or
#    MNEME_DISTILL_ENABLED is explicitly falsey. Env overrides config.
enabled=1
[ -f "$CONFIG" ] && grep -qiE '^[[:space:]]*distill[[:space:]]*=[[:space:]]*(off|0|false|no)[[:space:]]*$' "$CONFIG" && enabled=0
case "${MNEME_DISTILL_ENABLED:-}" in
  1|on|true|yes) enabled=1 ;;
  0|off|false|no) enabled=0 ;;
esac
[ "$enabled" = "1" ] || exit 0

# 4) Read the hook JSON from stdin and pull the transcript path.
HOOK_JSON="$(cat 2>/dev/null || true)"
TRANSCRIPT="$(printf '%s' "$HOOK_JSON" | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("transcript_path",""))
except Exception: print("")' 2>/dev/null || true)"
[ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ] || exit 0

# 5) Build the distiller prompt: a cleaned transcript excerpt + the current index
#    (for dedup). The min-session gate (arg 3) skips trivially short sessions, so a
#    default-on distiller never spawns a model call on a two-message chat.
PROMPT="$(python3 - "$TRANSCRIPT" "$GLOBAL_CACHE/INDEX.md" "$MIN_CHARS" <<'PY'
import json, sys
transcript, index_path, min_chars = sys.argv[1], sys.argv[2], int(sys.argv[3] or 0)
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
# Min-session gate: too little real conversation to be worth a model call.
if len(convo.strip()) < min_chars:
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

# 6) Ask the model (unless a test stub is supplied). MNEME_DISTILL=1 guards the child.
# The stub path injects a canned model response and is honored ONLY under test:
# both MNEME_TEST=1 AND MNEME_DISTILL_STUB (a readable file) must be set. This keeps
# the fake-response path from ever firing in a real session.
if [ "${MNEME_TEST:-}" = "1" ] && [ -n "${MNEME_DISTILL_STUB:-}" ] && [ -f "$MNEME_DISTILL_STUB" ]; then
  RESPONSE="$(cat "$MNEME_DISTILL_STUB")"
else
  command -v claude >/dev/null 2>&1 || exit 0
  RESPONSE="$(printf '%s' "$PROMPT" | MNEME_DISTILL=1 claude -p --model "$MODEL" 2>/dev/null || true)"
fi
[ -n "$RESPONSE" ] || exit 0

# 7) Parse the JSON array and write each proposed note into the INBOX as markdown.
# Response goes via a temp file (NOT stdin): the heredoc below already occupies
# python's stdin, so piping the response in would be silently discarded.
RESP_FILE="$(mktemp)"
printf '%s' "$RESPONSE" > "$RESP_FILE"
# The python step writes one status token (arg 3) to a file: "wrote=N" on success
# (N notes written, possibly 0) or "parse_error" when no JSON array could be
# recovered. Bash reads it below for the diagnostics log so a silent parse failure
# is answerable. A status file (not stdout capture) keeps the heredoc off a command
# substitution, which would mis-parse the bracket/quote characters in the script.
STATUS_FILE="$(mktemp)"
python3 - "$INBOX_DIR" "$RESP_FILE" "$STATUS_FILE" <<'PY'
import json, sys, os, re, tempfile
inbox_dir, resp_file, status_file = sys.argv[1], sys.argv[2], sys.argv[3]

# Types the distiller's own prompt requests. Anything else is coerced to "fact".
ALLOWED_TYPES = {"fact", "preference", "pattern", "reference", "project"}

def status(tok):
    with open(status_file, "w", encoding="utf-8") as f:
        f.write(tok)

with open(resp_file, encoding="utf-8") as f:
    raw = f.read().strip()
raw = re.sub(r'^```(?:json)?|```$', '', raw, flags=re.MULTILINE).strip()

def extract_array(text):
    # Prefer a clean parse of the whole response.
    try:
        val = json.loads(text)
        if isinstance(val, list):
            return val
    except Exception:
        pass
    # Otherwise scan each open bracket and let the decoder find the first valid JSON
    # array, rather than a greedy first-open .. last-close span that breaks on any
    # trailing text.
    dec = json.JSONDecoder()
    for i, ch in enumerate(text):
        if ch != "[":
            continue
        try:
            val, _ = dec.raw_decode(text, i)
        except ValueError:
            continue
        if isinstance(val, list):
            return val
    return None

notes = extract_array(raw)
if notes is None:
    status("parse_error")
    sys.exit(0)
if not notes:
    status("wrote=0")
    sys.exit(0)

def slug(s):
    return re.sub(r'[^a-z0-9]+', '-', (s or '').lower()).strip('-') or 'note'

os.makedirs(inbox_dir, exist_ok=True)
inbox_real = os.path.realpath(inbox_dir)
wrote = 0
for n in notes:
    if not isinstance(n, dict):
        continue
    body = (n.get("body") or "").strip()
    if not body:
        continue
    name = slug(n.get("name") or n.get("description"))
    desc = (n.get("description") or "").strip().replace("\n", " ")
    # Path-traversal defense: whitelist the type, then slug it (belt), then verify
    # the resolved path stays inside the inbox (braces). A response with e.g.
    # a type of ../cache/fact-x must never escape the review-gated inbox.
    typ = (n.get("type") or "fact").strip()
    if typ not in ALLOWED_TYPES:
        typ = "fact"
    typ = slug(typ)
    dest = os.path.join(inbox_dir, f"{typ}-{name}.md")
    dest_real = os.path.realpath(dest)
    if dest_real != inbox_real and not dest_real.startswith(inbox_real + os.sep):
        continue
    content = f"---\nname: {name}\ndescription: {desc}\ntype: {typ}\nsource: auto\n---\n\n{body}\n"
    # Atomic write: temp file IN the inbox, then rename into place.
    fd, tmp = tempfile.mkstemp(dir=inbox_dir, suffix=".tmp")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(content)
        os.replace(tmp, dest)
    except Exception:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        continue
    wrote += 1

status(f"wrote={wrote}")
PY
DISTILL_STATUS="$(cat "$STATUS_FILE" 2>/dev/null || true)"
rm -f "$RESP_FILE" "$STATUS_FILE"

# Diagnostics (local only): a background process that fails silently is a trap.
# One line per enabled run so "why did nothing get captured?" is answerable
# (e.g. an auth error shows up in the head snippet). Disable with MNEME_DISTILL_QUIET=1.
if [ "${MNEME_DISTILL_QUIET:-0}" != "1" ]; then
  LOG="$MNEME_DIR/_distill.log"
  NOW="$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo now)"
  INBOX_N="$(find "$INBOX_DIR" -maxdepth 1 -name '*.md' ! -name '_*' 2>/dev/null | wc -l | tr -d ' ')"
  HEAD="$(printf '%s' "$RESPONSE" | tr '\n\t' '  ' | cut -c1-160)"
  printf '%s  resp_len=%s  status=%s  inbox_now=%s  head=%s\n' "$NOW" "${#RESPONSE}" "${DISTILL_STATUS:-none}" "$INBOX_N" "$HEAD" >> "$LOG" 2>/dev/null || true
fi
exit 0
