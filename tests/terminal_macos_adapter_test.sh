#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/tests/assert.sh"

TMP="$(new_tmpdir)"
trap 'rm -rf "$TMP"' EXIT

FAKE_OSASCRIPT="$TMP/osascript"
OSASCRIPT_LOG="$TMP/osascript.log"

/bin/cat > "$FAKE_OSASCRIPT" <<'OSASCRIPT'
#!/bin/zsh
set -euo pipefail

script="$(cat)"
print -r -- "$script" >> "$ADL_OSASCRIPT_LOG"
if [[ "${ADL_FAKE_OSASCRIPT_FAIL:-0}" == "1" ]]; then
  print -r -- "forced osascript failure" >&2
  exit 1
fi
if [[ "$script" == *"return tty of selectedTab"* ]]; then
  print -r -- "${ADL_FAKE_TERMINAL_TTY:-/dev/ttys123}"
fi
OSASCRIPT
chmod +x "$FAKE_OSASCRIPT"

export ADL_TERMINAL_MACOS_TEST=1
export ADL_OSASCRIPT="$FAKE_OSASCRIPT"
export ADL_OSASCRIPT_LOG="$OSASCRIPT_LOG"

capture="$("$ROOT/scripts/terminal-macos" capture-focused architect)"
assert_contains "$capture" "ADL_ARCHITECT_ADAPTER='terminal-macos'" "Terminal capture should emit architect adapter"
assert_contains "$capture" "ADL_ARCHITECT_TERMINAL_ID='/dev/ttys123'" "Terminal capture should emit tty target id"

dev_capture="$(ADL_FAKE_TERMINAL_TTY="/dev/ttys777" "$ROOT/scripts/terminal-macos" capture-focused dev)"
assert_contains "$dev_capture" "ADL_DEV_ADAPTER='terminal-macos'" "Terminal capture should emit dev adapter"
assert_contains "$dev_capture" "ADL_DEV_TERMINAL_ID='/dev/ttys777'" "Terminal capture should emit role-specific tty"

"$ROOT/scripts/terminal-macos" send "/dev/ttys123" "Architect's Request: read file"
script_log="$(cat "$OSASCRIPT_LOG")"
assert_contains "$script_log" 'set targetTty to "/dev/ttys123"' "Terminal send should target stored tty"
assert_contains "$script_log" "set targetWindow to missing value" "Terminal send should track the target window"
assert_contains "$script_log" "set selected tab of targetWindow to targetTab" "Terminal send should focus target tab before submitting"
assert_contains "$script_log" "set index of targetWindow to 1" "Terminal send should bring target window forward"
assert_contains "$script_log" 'do script "Architect'\''s Request: read file" in targetTab' "Terminal send should write message in target tab"
assert_contains "$script_log" "tell application \"System Events\" to key code 36" "Terminal send should submit with a Return key event"

set +e
capture_fail="$(ADL_FAKE_OSASCRIPT_FAIL=1 "$ROOT/scripts/terminal-macos" capture-focused architect 2>&1)"
capture_fail_code="$?"
set -e
assert_eq "3" "$capture_fail_code" "Terminal capture should fail as transport error"
assert_contains "$capture_fail" "Terminal.app capture failed" "Terminal capture failure should be clear"

set +e
send_fail="$(ADL_FAKE_OSASCRIPT_FAIL=1 "$ROOT/scripts/terminal-macos" send "/dev/ttys123" "message" 2>&1)"
send_fail_code="$?"
set -e
assert_eq "3" "$send_fail_code" "Terminal send should fail as transport error"
assert_contains "$send_fail" "Terminal.app send failed" "Terminal send failure should be clear"

set +e
macos_fail="$(ADL_TERMINAL_MACOS_TEST=0 "$ROOT/scripts/terminal-macos" capture-focused architect 2>&1)"
macos_fail_code="$?"
set -e
if [[ "$(/usr/bin/uname -s)" != "Darwin" ]]; then
  assert_eq "3" "$macos_fail_code" "Terminal capture should fail off macOS"
  assert_contains "$macos_fail" "requires macOS Terminal.app" "non-macOS failure should be clear"
fi
