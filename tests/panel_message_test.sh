#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/tests/assert.sh"

TMP="$(new_tmpdir)"
trap 'rm -rf "$TMP"' EXIT
cd "$TMP"

FAKE_ADAPTER_DIR="$TMP/fake-adapter"
MESSAGE_LOG="$TMP/messages.log"
mkdir -p "$FAKE_ADAPTER_DIR"
/bin/cat > "$FAKE_ADAPTER_DIR/ghostty-macos" <<'ADAPTER'
#!/bin/zsh
set -euo pipefail

case "${1:-}" in
  capture-focused)
    role="${2:-}"
    case "$role" in
      architect)
        print -r -- "ADL_ARCHITECT_ADAPTER='ghostty-macos'"
        print -r -- "ADL_ARCHITECT_TERMINAL_ID='fake-architect-terminal'"
        ;;
      dev)
        print -r -- "ADL_DEV_ADAPTER='ghostty-macos'"
        print -r -- "ADL_DEV_TERMINAL_ID='fake-dev-terminal'"
        ;;
      *)
        exit 3
        ;;
    esac
    ;;
  send)
    terminal_id="${2:-}"
    message="${3:-}"
    [[ "$message" != *"\\n"* ]] || {
      print -r -- "literal newline escape found in panel message: $message" >&2
      exit 3
    }
    print -r -- "$terminal_id|$message" >> "$ADL_MESSAGE_LOG"
    ;;
  *)
    exit 3
    ;;
esac
ADAPTER
chmod +x "$FAKE_ADAPTER_DIR/ghostty-macos"

export ADL_SCRIPT_ROOT="$FAKE_ADAPTER_DIR"
export ADL_MESSAGE_LOG="$MESSAGE_LOG"

write_dev_prompt() {
  local path="$1"
  /bin/cat > "$path" <<'PROMPT'
Goal: Panel message test
Slice: Send one request
Approved context: Test fixture only.
Acceptance criteria:
- Panel message stays one line.
In scope: Message text.
Out of scope: Real terminal automation.
Expected evidence: Message log.
PROMPT
}

write_dev_report() {
  local path="$1"
  /bin/cat > "$path" <<'REPORT'
# Dev Report

Status: DONE
Goal: Panel message test
Slice: Send one request

## Acceptance Results
- Panel message stays one line. PASS - message log checked.

## Files Changed
None

## Verification
- Command: message log
- Result: PASS

## Deviations
None

## Residual Risks
None
REPORT
}

start="$("$ROOT/scripts/adl" architect start)"
pin="$(print -r -- "$start" | awk '/^Pin: / { print $2 }')"
adl_status="$("$ROOT/scripts/adl" status)"
assert_contains "$adl_status" "Connect Dev with \$adl-connect $pin." "source/codex status should use dollar skill invocation"

CLAUDE_ADL="$TMP/.claude/skills/adl/scripts/adl"
mkdir -p "$CLAUDE_ADL:h"
/bin/cp "$ROOT/scripts/adl" "$CLAUDE_ADL"
chmod +x "$CLAUDE_ADL"
claude_status="$("$CLAUDE_ADL" status)"
assert_contains "$claude_status" "Connect Dev with /adl-connect $pin." "claude-installed status should use slash skill invocation"

NO_SESSION_DIR="$TMP/no-session"
mkdir -p "$NO_SESSION_DIR/.claude/skills/adl/scripts"
/bin/cp "$ROOT/scripts/adl" "$NO_SESSION_DIR/.claude/skills/adl/scripts/adl"
chmod +x "$NO_SESSION_DIR/.claude/skills/adl/scripts/adl"
set +e
claude_notify_error="$(cd "$NO_SESSION_DIR" && "$NO_SESSION_DIR/.claude/skills/adl/scripts/adl" dev notify 2>&1)"
claude_notify_code="$?"
set -e
assert_eq "1" "$claude_notify_code" "claude dev notify without session should fail"
assert_contains "$claude_notify_error" "No active ADL session. Invoke /adl first." "claude no-session error should use slash skill invocation"
assert_not_contains "$claude_notify_error" "Invoke \$adl first" "claude no-session error should not use Codex dollar skill invocation"

connect="$("$ROOT/scripts/adl" dev connect "$pin")"
assert_contains "$connect" "Architect notified: Dev connected and ready." "connect should send ready panel message"

mkdir -p .adl/staging
write_dev_prompt .adl/staging/prompt.md
send="$("$ROOT/scripts/adl" architect send-dev --prompt-file .adl/staging/prompt.md)"
assert_contains "$send" "Passing this to the developer" "send-dev should send architect request panel message"

session_id="$(cat .adl/active-session)"
write_dev_report ".adl/sessions/$session_id/runs/001/dev-report.md"
notify="$("$ROOT/scripts/adl" dev notify)"
assert_contains "$notify" "Developer's Report sent" "notify should send report panel message"

messages="$(cat "$MESSAGE_LOG")"
assert_contains "$messages" "Dev connected and ready. Send the first handoff." "ready message should be one line"
assert_contains "$messages" "Architect's Request: read and execute .adl/sessions/" "request message should be one line"
assert_contains "$messages" "$ROOT/scripts/adl dev notify" "request message should use active CLI path"
assert_contains "$messages" "Developer's Report: read .adl/sessions/" "report message should be one line"
assert_contains "$messages" "goal, approved context, acceptance criteria, and repo state" "report message should nudge goal and acceptance review"

CLAUDE_PANEL="$TMP/.claude-panel"
mkdir -p "$CLAUDE_PANEL/.claude/skills/adl/scripts"
/bin/cp "$ROOT/scripts/adl" "$CLAUDE_PANEL/.claude/skills/adl/scripts/adl"
chmod +x "$CLAUDE_PANEL/.claude/skills/adl/scripts/adl"
(
  cd "$CLAUDE_PANEL"
  export ADL_SCRIPT_ROOT="$FAKE_ADAPTER_DIR"
  export ADL_MESSAGE_LOG="$MESSAGE_LOG"
  claude_start="$("$CLAUDE_PANEL/.claude/skills/adl/scripts/adl" architect start)"
  claude_pin="$(print -r -- "$claude_start" | awk '/^Pin: / { print $2 }')"
  "$CLAUDE_PANEL/.claude/skills/adl/scripts/adl" dev connect "$claude_pin" >/dev/null
  mkdir -p .adl/staging
  write_dev_prompt .adl/staging/prompt.md
  "$CLAUDE_PANEL/.claude/skills/adl/scripts/adl" architect send-dev --prompt-file .adl/staging/prompt.md >/dev/null
)
messages="$(cat "$MESSAGE_LOG")"
assert_contains "$messages" "${CLAUDE_PANEL:A}/.claude/skills/adl/scripts/adl dev notify" "claude request message should use claude CLI path"
