#!/usr/bin/env bash
# Tests for the background distiller (hooks/scripts/distill.sh).
# Each test builds a temp MNEME_DIR, a fake transcript, and a canned stub response,
# then pipes hook JSON on stdin. The stub path is honored only under MNEME_TEST=1.

# Shared setup: sets ROOT, TMP, DISTILL; writes a transcript that clears the
# min-chars gate; leaves a stub for the caller to fill in. Callers set MNEME_TEST=1
# and MNEME_DISTILL_STUB when they want the canned response honored.
_distill_setup() {
  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  TMP="$(mktemp -d)"
  DISTILL="$ROOT/plugins/mneme/hooks/scripts/distill.sh"
  mkdir -p "$TMP/cache"
  # A transcript with enough content to pass the default min-chars gate.
  TRANSCRIPT="$TMP/transcript.jsonl"
  {
    printf '{"role":"user","content":"%s"}\n' "$(_distill_filler user)"
    printf '{"role":"assistant","content":"%s"}\n' "$(_distill_filler assistant)"
  } > "$TRANSCRIPT"
  STUB="$TMP/stub.json"
}

_distill_filler() {
  # Emit ~1000 chars so two messages clear the 1500-char default gate.
  local prefix="$1" i out=""
  for i in $(seq 1 60); do out="$out $prefix line $i talking about durable reusable learnings"; done
  printf '%s' "$out"
}

test_distill_happy_path() {
  _distill_setup
  cat > "$STUB" <<'JSON'
[{"name":"Use Ripgrep","description":"prefer rg over grep","type":"fact","body":"Prefer ripgrep for code search; it respects gitignore."}]
JSON
  env -u MNEME_DISTILL MNEME_GLOBAL_DIR="$TMP/cache" MNEME_TEST=1 \
    MNEME_DISTILL_STUB="$STUB" MNEME_DISTILL_QUIET=1 bash "$DISTILL" \
    <<< "$(printf '{"transcript_path":"%s"}' "$TRANSCRIPT")" >/dev/null 2>&1
  local note="$TMP/inbox/fact-use-ripgrep.md" rc=0
  assert_file "$note" "happy path writes fact-<slug>.md into inbox" || rc=1
  local out; out="$(cat "$note" 2>/dev/null)"
  assert_contains "$out" "name: use-ripgrep" "frontmatter has name" || rc=1
  assert_contains "$out" "description: prefer rg over grep" "frontmatter has description" || rc=1
  assert_contains "$out" "type: fact" "frontmatter has type" || rc=1
  assert_contains "$out" "source: auto" "frontmatter has source: auto" || rc=1
  assert_contains "$out" "Prefer ripgrep for code search" "body is written" || rc=1
  rm -rf "$TMP"
  return $rc
}

test_distill_traversal_blocked() {
  _distill_setup
  # Pre-create the trusted cache dir and record its contents.
  mkdir -p "$TMP/cache"
  local before after
  before="$(find "$TMP/cache" -type f 2>/dev/null | sort)"
  cat > "$STUB" <<'JSON'
[{"name":"evil","description":"path traversal","type":"../cache/fact-evil","body":"should not escape the inbox"}]
JSON
  env -u MNEME_DISTILL MNEME_GLOBAL_DIR="$TMP/cache" MNEME_TEST=1 \
    MNEME_DISTILL_STUB="$STUB" MNEME_DISTILL_QUIET=1 bash "$DISTILL" \
    <<< "$(printf '{"transcript_path":"%s"}' "$TRANSCRIPT")" >/dev/null 2>&1
  after="$(find "$TMP/cache" -type f 2>/dev/null | sort)"
  local rc=0
  assert_eq "$after" "$before" "cache dir is untouched by traversal attempt" || rc=1
  # A sanitized note (type coerced to fact) must land in the inbox instead.
  assert_file "$TMP/inbox/fact-evil.md" "sanitized note lands in inbox as fact-evil.md" || rc=1
  local out; out="$(cat "$TMP/inbox/fact-evil.md" 2>/dev/null)"
  assert_contains "$out" "type: fact" "coerced type is fact" || rc=1
  rm -rf "$TMP"
  return $rc
}

test_distill_invalid_type_coerced() {
  _distill_setup
  cat > "$STUB" <<'JSON'
[{"name":"banana-note","description":"unknown type","type":"banana","body":"an unknown type should become fact"}]
JSON
  env -u MNEME_DISTILL MNEME_GLOBAL_DIR="$TMP/cache" MNEME_TEST=1 \
    MNEME_DISTILL_STUB="$STUB" MNEME_DISTILL_QUIET=1 bash "$DISTILL" \
    <<< "$(printf '{"transcript_path":"%s"}' "$TRANSCRIPT")" >/dev/null 2>&1
  local rc=0
  assert_file "$TMP/inbox/fact-banana-note.md" "invalid type coerced to fact- prefix" || rc=1
  rm -rf "$TMP"
  return $rc
}

test_distill_malformed_json_logs_parse_error() {
  _distill_setup
  printf 'not json [broken' > "$STUB"
  # Run WITHOUT MNEME_DISTILL_QUIET so the diagnostics line is written.
  env -u MNEME_DISTILL -u MNEME_DISTILL_QUIET MNEME_GLOBAL_DIR="$TMP/cache" \
    MNEME_TEST=1 MNEME_DISTILL_STUB="$STUB" bash "$DISTILL" \
    <<< "$(printf '{"transcript_path":"%s"}' "$TRANSCRIPT")" >/dev/null 2>&1
  local ec=$?
  local rc=0
  assert_eq "$ec" "0" "exit code 0 on malformed JSON" || rc=1
  local n; n="$(find "$TMP/inbox" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')"
  assert_eq "${n:-0}" "0" "inbox stays empty on malformed JSON" || rc=1
  local log; log="$(cat "$TMP/_distill.log" 2>/dev/null)"
  assert_contains "$log" "parse_error" "parse failure recorded in _distill.log" || rc=1
  rm -rf "$TMP"
  return $rc
}

test_distill_recursion_guard() {
  _distill_setup
  cat > "$STUB" <<'JSON'
[{"name":"x","description":"y","type":"fact","body":"should never be written under recursion guard"}]
JSON
  # MNEME_DISTILL=1 must short-circuit before anything is written.
  MNEME_DISTILL=1 MNEME_GLOBAL_DIR="$TMP/cache" MNEME_TEST=1 \
    MNEME_DISTILL_STUB="$STUB" MNEME_DISTILL_QUIET=1 bash "$DISTILL" \
    <<< "$(printf '{"transcript_path":"%s"}' "$TRANSCRIPT")" >/dev/null 2>&1
  local ec=$?
  local rc=0
  assert_eq "$ec" "0" "recursion guard exits 0" || rc=1
  local n; n="$(find "$TMP/inbox" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')"
  assert_eq "${n:-0}" "0" "inbox empty under recursion guard" || rc=1
  rm -rf "$TMP"
  return $rc
}

test_distill_stub_gated_by_mneme_test() {
  _distill_setup
  cat > "$STUB" <<'JSON'
[{"name":"ungated","description":"should not fire","type":"fact","body":"stub must be ignored without MNEME_TEST=1"}]
JSON
  # MNEME_DISTILL_STUB set but MNEME_TEST unset: the stub is NOT honored. With claude
  # off PATH and min-chars=1, the script falls through to `command -v claude` and exits.
  env -u MNEME_DISTILL -u MNEME_TEST MNEME_GLOBAL_DIR="$TMP/cache" \
    MNEME_DISTILL_STUB="$STUB" MNEME_DISTILL_MIN_CHARS=1 MNEME_DISTILL_QUIET=1 \
    PATH="/usr/bin:/bin" bash "$DISTILL" \
    <<< "$(printf '{"transcript_path":"%s"}' "$TRANSCRIPT")" >/dev/null 2>&1
  local ec=$?
  local rc=0
  assert_eq "$ec" "0" "exits 0 when stub is not honored and claude is absent" || rc=1
  local n; n="$(find "$TMP/inbox" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')"
  assert_eq "${n:-0}" "0" "stub ignored without MNEME_TEST: inbox empty" || rc=1
  rm -rf "$TMP"
  return $rc
}
