#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/tests/assert.sh"

TMP="$(new_tmpdir)"
trap 'rm -rf "$TMP"' EXIT
cd "$TMP"

FAKE_ADAPTER_DIR="$TMP/fake-adapters"
MESSAGE_LOG="$TMP/fake-messages.log"
mkdir -p "$FAKE_ADAPTER_DIR"

/bin/cat > "$FAKE_ADAPTER_DIR/fake-alt" <<'ADAPTER'
#!/bin/zsh
set -euo pipefail

adapter_name="${0:t}"

case "${1:-}" in
  capture-focused)
    role="${2:-}"
    case "$role" in
      architect)
        print -r -- "ADL_ARCHITECT_ADAPTER='$adapter_name'"
        print -r -- "ADL_ARCHITECT_TERMINAL_ID='$adapter_name-architect-pane'"
        print -r -- "ADL_ARCHITECT_LABEL='$adapter_name architect pane'"
        ;;
      dev)
        print -r -- "ADL_DEV_ADAPTER='$adapter_name'"
        print -r -- "ADL_DEV_TERMINAL_ID='$adapter_name-dev-pane'"
        print -r -- "ADL_DEV_LABEL='$adapter_name dev pane'"
        ;;
      *)
        exit 3
        ;;
    esac
    ;;
  send)
    terminal_id="${2:-}"
    message="${3:-}"
    print -r -- "$adapter_name|$terminal_id|$message" >> "$ADL_MESSAGE_LOG"
    ;;
  *)
    exit 3
    ;;
esac
ADAPTER
chmod +x "$FAKE_ADAPTER_DIR/fake-alt"
/bin/cp "$FAKE_ADAPTER_DIR/fake-alt" "$FAKE_ADAPTER_DIR/fake-next"
chmod +x "$FAKE_ADAPTER_DIR/fake-next"

CONFIG_DIR="$TMP/configured-transport"
CONFIG_SKILLS="$TMP/config-skills"
mkdir -p "$CONFIG_DIR" "$CONFIG_SKILLS/adl"
/bin/cat > "$CONFIG_SKILLS/adl/.adl-config" <<'CONFIG'
ADL_TRANSPORT='fake-alt'
CONFIG
(
  cd "$CONFIG_DIR"
  unset ADL_TRANSPORT
  export ADL_CODEX_SKILLS_DIR="$CONFIG_SKILLS"
  export ADL_SCRIPT_ROOT="$FAKE_ADAPTER_DIR"
  export ADL_MESSAGE_LOG="$MESSAGE_LOG"

  config_start="$("$ROOT/scripts/adl" architect start)"
  assert_contains "$config_start" "ADL session ready" "installed config transport should start session"
  config_session="$(cat .adl/active-session)"
  assert_contains "$(cat ".adl/sessions/$config_session/session.env")" "ADL_ARCHITECT_ADAPTER='fake-alt'" "installed config should select fake-alt by default"

  config_doctor="$("$ROOT/scripts/adl" doctor)"
  assert_contains "$config_doctor" "transport.selected: fake-alt" "doctor should report installed config transport"
)

OVERRIDE_DIR="$TMP/override-transport"
mkdir -p "$OVERRIDE_DIR"
(
  cd "$OVERRIDE_DIR"
  export ADL_CODEX_SKILLS_DIR="$CONFIG_SKILLS"
  export ADL_SCRIPT_ROOT="$FAKE_ADAPTER_DIR"
  export ADL_MESSAGE_LOG="$MESSAGE_LOG"
  ADL_TRANSPORT=fake-next "$ROOT/scripts/adl" architect start >/dev/null
  override_session="$(cat .adl/active-session)"
  assert_contains "$(cat ".adl/sessions/$override_session/session.env")" "ADL_ARCHITECT_ADAPTER='fake-next'" "ADL_TRANSPORT env should override installed config"
)

MISSING_CONFIG_DIR="$TMP/missing-config"
mkdir -p "$MISSING_CONFIG_DIR"
(
  cd "$MISSING_CONFIG_DIR"
  unset ADL_TRANSPORT
  export ADL_CODEX_SKILLS_DIR="$TMP/missing-skills"
  export ADL_SCRIPT_ROOT="$FAKE_ADAPTER_DIR"
  set +e
  "$ROOT/scripts/adl" architect start >out.txt 2>&1
  code="$?"
  set -e
  assert_eq "3" "$code" "missing installed config should fail with transport error"
  assert_contains "$(cat out.txt)" "ADL transport is not configured" "missing config should explain setup or override"
)

INSTALLED_HOME="$TMP/installed-home"
INSTALLED_WORK="$TMP/installed-work"
mkdir -p \
  "$INSTALLED_HOME/.codex/skills/adl/scripts" \
  "$INSTALLED_HOME/.claude/skills/adl/scripts" \
  "$INSTALLED_WORK/codex" \
  "$INSTALLED_WORK/claude"
/bin/cp "$ROOT/scripts/adl" "$INSTALLED_HOME/.codex/skills/adl/scripts/adl"
/bin/cp "$ROOT/scripts/adl" "$INSTALLED_HOME/.claude/skills/adl/scripts/adl"
chmod +x "$INSTALLED_HOME/.codex/skills/adl/scripts/adl" "$INSTALLED_HOME/.claude/skills/adl/scripts/adl"
/bin/cat > "$INSTALLED_HOME/.codex/skills/adl/.adl-config" <<'CONFIG'
ADL_TRANSPORT='fake-alt'
CONFIG
/bin/cat > "$INSTALLED_HOME/.claude/skills/adl/.adl-config" <<'CONFIG'
ADL_TRANSPORT='fake-next'
CONFIG
(
  cd "$INSTALLED_WORK/codex"
  unset ADL_TRANSPORT ADL_CODEX_SKILLS_DIR ADL_RUNTIME_ADL_DIR
  export HOME="$INSTALLED_HOME"
  export ADL_SCRIPT_ROOT="$FAKE_ADAPTER_DIR"
  export ADL_MESSAGE_LOG="$MESSAGE_LOG"

  "$INSTALLED_HOME/.codex/skills/adl/scripts/adl" architect start >/dev/null
  codex_session="$(cat .adl/active-session)"
  assert_contains "$(cat ".adl/sessions/$codex_session/session.env")" "ADL_ARCHITECT_ADAPTER='fake-alt'" "installed Codex CLI should use adjacent Codex config"
  codex_doctor="$("$INSTALLED_HOME/.codex/skills/adl/scripts/adl" doctor)"
  assert_contains "$codex_doctor" "transport.selected: fake-alt" "installed Codex doctor should report adjacent Codex config"
)
(
  cd "$INSTALLED_WORK/claude"
  unset ADL_TRANSPORT ADL_CODEX_SKILLS_DIR ADL_RUNTIME_ADL_DIR
  export HOME="$INSTALLED_HOME"
  export ADL_SCRIPT_ROOT="$FAKE_ADAPTER_DIR"
  export ADL_MESSAGE_LOG="$MESSAGE_LOG"

  "$INSTALLED_HOME/.claude/skills/adl/scripts/adl" architect start >/dev/null
  claude_session="$(cat .adl/active-session)"
  assert_contains "$(cat ".adl/sessions/$claude_session/session.env")" "ADL_ARCHITECT_ADAPTER='fake-next'" "installed Claude CLI should use adjacent Claude config"
  claude_doctor="$("$INSTALLED_HOME/.claude/skills/adl/scripts/adl" doctor)"
  assert_contains "$claude_doctor" "transport.selected: fake-next" "installed Claude doctor should report adjacent Claude config"
)

write_dev_prompt() {
  local path="$1"
  /bin/cat > "$path" <<'PROMPT'
Goal: Transport abstraction test
Slice: Use fake transport
Approved context: Test fixture only.
Acceptance criteria:
- Fake transport is selected.
In scope: ADL state and send routing.
Out of scope: Real terminal automation.
Expected evidence: session.env and fake message log.
PROMPT
}

write_dev_report() {
  local path="$1"
  /bin/cat > "$path" <<'REPORT'
# Dev Report

Status: DONE
Goal: Transport abstraction test
Slice: Use fake transport

## Acceptance Results
- Fake transport is selected. PASS - fake message log checked.

## Files Changed
None

## Verification
- Command: fake message log
- Result: PASS

## Deviations
None

## Residual Risks
None
REPORT
}

export ADL_TRANSPORT=fake-alt
export ADL_SCRIPT_ROOT="$FAKE_ADAPTER_DIR"
export ADL_MESSAGE_LOG="$MESSAGE_LOG"

start="$("$ROOT/scripts/adl" architect start)"
assert_contains "$start" "ADL session ready" "fake transport should start session"
session_id="$(cat .adl/active-session)"
pin="$(grep "^ADL_PIN=" ".adl/sessions/$session_id/session.env" | sed "s/ADL_PIN='//;s/'$//")"
assert_contains "$(cat ".adl/sessions/$session_id/session.env")" "ADL_ARCHITECT_ADAPTER='fake-alt'" "architect adapter should persist selected fake transport"
assert_contains "$(cat ".adl/sessions/$session_id/session.env")" "ADL_ARCHITECT_TERMINAL_ID='fake-alt-architect-pane'" "architect terminal id should come from fake transport"

doctor="$("$ROOT/scripts/adl" doctor)"
assert_contains "$doctor" "transport.selected: fake-alt" "doctor should report selected transport"
assert_contains "$doctor" "transport.adapter: executable ($FAKE_ADAPTER_DIR/fake-alt)" "doctor should report selected adapter path"

transport_doctor="$("$ROOT/scripts/adl" doctor transport dev)"
assert_contains "$transport_doctor" "ADL doctor transport" "generic transport doctor should run"
assert_contains "$transport_doctor" "transport: fake-alt" "generic transport doctor should use selected fake transport"
assert_contains "$transport_doctor" "ADL_DEV_TERMINAL_ID='fake-alt-dev-pane'" "generic transport doctor should capture through fake transport"

connect="$("$ROOT/scripts/adl" dev connect "$pin")"
assert_contains "$connect" "Architect notified" "dev connect should notify architect through fake transport"
assert_contains "$(cat ".adl/sessions/$session_id/session.env")" "ADL_DEV_ADAPTER='fake-alt'" "dev adapter should persist selected fake transport"
assert_contains "$(cat ".adl/sessions/$session_id/session.env")" "ADL_DEV_TERMINAL_ID='fake-alt-dev-pane'" "dev terminal id should come from fake transport"
assert_contains "$(cat "$MESSAGE_LOG")" "fake-alt|fake-alt-architect-pane|Dev connected and ready" "dev connect should send to architect through fake transport"

mkdir -p .adl/staging
write_dev_prompt .adl/staging/prompt.md
"$ROOT/scripts/adl" architect send-dev --prompt-file .adl/staging/prompt.md >/dev/null
assert_contains "$(cat "$MESSAGE_LOG")" "fake-alt|fake-alt-dev-pane|Architect's Request: read and execute" "send-dev should send to dev through fake transport"

write_dev_report ".adl/sessions/$session_id/runs/001/dev-report.md"
"$ROOT/scripts/adl" dev notify >/dev/null
assert_contains "$(cat "$MESSAGE_LOG")" "fake-alt|fake-alt-architect-pane|Developer's Report: read" "dev notify should send to architect through fake transport"

export ADL_TRANSPORT=fake-next
mkdir -p .adl/staging
write_dev_prompt .adl/staging/prompt2.md
"$ROOT/scripts/adl" architect send-dev --prompt-file .adl/staging/prompt2.md >/dev/null
assert_contains "$(cat "$MESSAGE_LOG")" "fake-alt|fake-alt-dev-pane|Architect's Request: read and execute .adl/sessions/$session_id/runs/002/dev-prompt.md" "handoff should use stored dev adapter after current transport changes"
assert_not_contains "$(cat "$MESSAGE_LOG")" "fake-next|fake-alt-dev-pane" "handoff should not send stored fake-alt dev pane through current fake-next adapter"

write_dev_report ".adl/sessions/$session_id/runs/002/dev-report.md"
"$ROOT/scripts/adl" dev notify >/dev/null
assert_contains "$(cat "$MESSAGE_LOG")" "fake-alt|fake-alt-architect-pane|Developer's Report: read .adl/sessions/$session_id/runs/002/dev-report.md" "report notify should use stored architect adapter after current transport changes"
assert_not_contains "$(cat "$MESSAGE_LOG")" "fake-next|fake-alt-architect-pane" "report notify should not send stored fake-alt architect pane through current fake-next adapter"

reconnect="$("$ROOT/scripts/adl" architect reconnect)"
assert_contains "$reconnect" "Reconnected Architect transport" "architect reconnect should intentionally switch to current transport"
assert_contains "$(cat ".adl/sessions/$session_id/session.env")" "ADL_ARCHITECT_ADAPTER='fake-next'" "architect reconnect should persist current fake-next adapter"
assert_contains "$(cat ".adl/sessions/$session_id/session.env")" "ADL_ARCHITECT_TERMINAL_ID='fake-next-architect-pane'" "architect reconnect should persist fake-next terminal"

replace_connect="$("$ROOT/scripts/adl" dev connect "$pin" --replace)"
assert_contains "$replace_connect" "Connected to ADL session" "dev reconnect replace should intentionally switch to current transport"
assert_contains "$(cat ".adl/sessions/$session_id/session.env")" "ADL_DEV_ADAPTER='fake-next'" "dev reconnect should persist current fake-next adapter"
assert_contains "$(cat ".adl/sessions/$session_id/session.env")" "ADL_DEV_TERMINAL_ID='fake-next-dev-pane'" "dev reconnect should persist fake-next terminal"
assert_contains "$(cat "$MESSAGE_LOG")" "fake-next|fake-next-architect-pane|Dev connected and ready" "dev reconnect should notify through newly stored architect adapter"

UNSUPPORTED="$TMP/unsupported"
mkdir -p "$UNSUPPORTED"
(
  cd "$UNSUPPORTED"
  set +e
  ADL_TRANSPORT=unknown ADL_SCRIPT_ROOT="$FAKE_ADAPTER_DIR" "$ROOT/scripts/adl" architect start >out.txt 2>&1
  code="$?"
  set -e
  assert_eq "3" "$code" "unsupported transport should fail with transport error"
  assert_contains "$(cat out.txt)" "Unsupported ADL transport: unknown" "unsupported transport should explain supported transports"
  [[ ! -e .adl ]] || fail "unsupported transport should not create .adl state"
)

TMUX_DIR="$TMP/tmux-transport"
FAKE_TMUX_BIN="$TMP/tmux-bin"
TMUX_LOG="$TMP/tmux-integration.log"
mkdir -p "$TMUX_DIR" "$FAKE_TMUX_BIN"
/bin/cp "$ROOT/scripts/tmux" "$FAKE_ADAPTER_DIR/tmux"
chmod +x "$FAKE_ADAPTER_DIR/tmux"

/bin/cat > "$FAKE_TMUX_BIN/tmux" <<'TMUX'
#!/bin/zsh
set -euo pipefail

print -r -- "$*" >> "$ADL_TMUX_LOG"
case "${1:-}" in
  display-message)
    [[ "${2:-}" == "-p" && "${3:-}" == '#{pane_id}' ]] || exit 2
    case "${ADL_FAKE_TMUX_ROLE:-architect}" in
      architect) print -r -- "%architect" ;;
      dev) print -r -- "%dev" ;;
      *) print -r -- "%unknown" ;;
    esac
    ;;
  send-keys)
    exit 0
    ;;
  *)
    exit 2
    ;;
esac
TMUX
chmod +x "$FAKE_TMUX_BIN/tmux"

(
  cd "$TMUX_DIR"
  export ADL_TRANSPORT=tmux
  export ADL_SCRIPT_ROOT="$FAKE_ADAPTER_DIR"
  export ADL_TMUX_LOG="$TMUX_LOG"
  export PATH="$FAKE_TMUX_BIN:$PATH"
  export TMUX="/tmp/fake-tmux,123,0"

  start="$(ADL_FAKE_TMUX_ROLE=architect "$ROOT/scripts/adl" architect start)"
  pin="$(print -r -- "$start" | awk '/^Pin: / { print $2 }')"
  session_id="$(cat .adl/active-session)"
  assert_contains "$(cat ".adl/sessions/$session_id/session.env")" "ADL_ARCHITECT_ADAPTER='tmux'" "tmux integration should persist architect adapter"
  assert_contains "$(cat ".adl/sessions/$session_id/session.env")" "ADL_ARCHITECT_TERMINAL_ID='%architect'" "tmux integration should persist architect pane id"

  ADL_FAKE_TMUX_ROLE=dev "$ROOT/scripts/adl" dev connect "$pin" >/dev/null
  assert_contains "$(cat ".adl/sessions/$session_id/session.env")" "ADL_DEV_ADAPTER='tmux'" "tmux integration should persist dev adapter"
  assert_contains "$(cat ".adl/sessions/$session_id/session.env")" "ADL_DEV_TERMINAL_ID='%dev'" "tmux integration should persist dev pane id"

  mkdir -p .adl/staging
  write_dev_prompt .adl/staging/tmux-prompt.md
  "$ROOT/scripts/adl" architect send-dev --prompt-file .adl/staging/tmux-prompt.md >/dev/null
  assert_contains "$(cat "$TMUX_LOG")" "send-keys -t %dev Architect's Request: read and execute" "tmux integration should send handoff to dev pane"

  write_dev_report ".adl/sessions/$session_id/runs/001/dev-report.md"
  "$ROOT/scripts/adl" dev notify >/dev/null
  assert_contains "$(cat "$TMUX_LOG")" "send-keys -t %architect Developer's Report: read" "tmux integration should send report to architect pane"
)

TERMINAL_DIR="$TMP/terminal-transport"
TERMINAL_OSASCRIPT="$TMP/terminal-osascript"
TERMINAL_OSASCRIPT_LOG="$TMP/terminal-osascript.log"
mkdir -p "$TERMINAL_DIR"
/bin/cp "$ROOT/scripts/terminal-macos" "$FAKE_ADAPTER_DIR/terminal-macos"
chmod +x "$FAKE_ADAPTER_DIR/terminal-macos"

/bin/cat > "$TERMINAL_OSASCRIPT" <<'OSASCRIPT'
#!/bin/zsh
set -euo pipefail

script="$(cat)"
print -r -- "$script" >> "$ADL_OSASCRIPT_LOG"
if [[ "$script" == *"return tty of selectedTab"* ]]; then
  case "${ADL_FAKE_TERMINAL_ROLE:-architect}" in
    architect) print -r -- "/dev/ttys-architect" ;;
    dev) print -r -- "/dev/ttys-dev" ;;
    *) print -r -- "/dev/ttys-unknown" ;;
  esac
fi
OSASCRIPT
chmod +x "$TERMINAL_OSASCRIPT"

(
  cd "$TERMINAL_DIR"
  export ADL_TRANSPORT=terminal-macos
  export ADL_SCRIPT_ROOT="$FAKE_ADAPTER_DIR"
  export ADL_TERMINAL_MACOS_TEST=1
  export ADL_OSASCRIPT="$TERMINAL_OSASCRIPT"
  export ADL_OSASCRIPT_LOG="$TERMINAL_OSASCRIPT_LOG"

  start="$(ADL_FAKE_TERMINAL_ROLE=architect "$ROOT/scripts/adl" architect start)"
  pin="$(print -r -- "$start" | awk '/^Pin: / { print $2 }')"
  session_id="$(cat .adl/active-session)"
  assert_contains "$(cat ".adl/sessions/$session_id/session.env")" "ADL_ARCHITECT_ADAPTER='terminal-macos'" "Terminal integration should persist architect adapter"
  assert_contains "$(cat ".adl/sessions/$session_id/session.env")" "ADL_ARCHITECT_TERMINAL_ID='/dev/ttys-architect'" "Terminal integration should persist architect tty"

  ADL_FAKE_TERMINAL_ROLE=dev "$ROOT/scripts/adl" dev connect "$pin" >/dev/null
  assert_contains "$(cat ".adl/sessions/$session_id/session.env")" "ADL_DEV_ADAPTER='terminal-macos'" "Terminal integration should persist dev adapter"
  assert_contains "$(cat ".adl/sessions/$session_id/session.env")" "ADL_DEV_TERMINAL_ID='/dev/ttys-dev'" "Terminal integration should persist dev tty"

  mkdir -p .adl/staging
  write_dev_prompt .adl/staging/terminal-prompt.md
  "$ROOT/scripts/adl" architect send-dev --prompt-file .adl/staging/terminal-prompt.md >/dev/null
  assert_contains "$(cat "$TERMINAL_OSASCRIPT_LOG")" 'set targetTty to "/dev/ttys-dev"' "Terminal integration should send handoff to stored dev tty"

  write_dev_report ".adl/sessions/$session_id/runs/001/dev-report.md"
  "$ROOT/scripts/adl" dev notify >/dev/null
  assert_contains "$(cat "$TERMINAL_OSASCRIPT_LOG")" 'set targetTty to "/dev/ttys-architect"' "Terminal integration should send report to stored architect tty"
)

MIXED_DIR="$TMP/mixed-transport"
MIXED_ADAPTER_DIR="$TMP/mixed-adapters"
MIXED_GHOSTTY_LOG="$TMP/mixed-ghostty.log"
MIXED_OSASCRIPT="$TMP/mixed-osascript"
MIXED_OSASCRIPT_LOG="$TMP/mixed-osascript.log"
mkdir -p "$MIXED_DIR" "$MIXED_ADAPTER_DIR"

/bin/cat > "$MIXED_ADAPTER_DIR/ghostty-macos" <<'GHOSTTY'
#!/bin/zsh
set -euo pipefail

case "${1:-}" in
  capture-focused)
    role="${2:-}"
    case "$role" in
      architect)
        print -r -- "ADL_ARCHITECT_ADAPTER='ghostty-macos'"
        print -r -- "ADL_ARCHITECT_TERMINAL_ID='mixed-ghostty-architect'"
        print -r -- "ADL_ARCHITECT_LABEL='Mixed Ghostty architect'"
        ;;
      dev)
        print -r -- "ADL_DEV_ADAPTER='ghostty-macos'"
        print -r -- "ADL_DEV_TERMINAL_ID='mixed-ghostty-dev'"
        print -r -- "ADL_DEV_LABEL='Mixed Ghostty dev'"
        ;;
      *)
        exit 3
        ;;
    esac
    ;;
  send)
    print -r -- "${2:-}|${3:-}" >> "$ADL_MIXED_GHOSTTY_LOG"
    ;;
  *)
    exit 3
    ;;
esac
GHOSTTY
chmod +x "$MIXED_ADAPTER_DIR/ghostty-macos"
/bin/cp "$ROOT/scripts/terminal-macos" "$MIXED_ADAPTER_DIR/terminal-macos"
chmod +x "$MIXED_ADAPTER_DIR/terminal-macos"

/bin/cat > "$MIXED_OSASCRIPT" <<'OSASCRIPT'
#!/bin/zsh
set -euo pipefail

script="$(cat)"
print -r -- "$script" >> "$ADL_OSASCRIPT_LOG"
if [[ "$script" == *"return tty of selectedTab"* ]]; then
  print -r -- "/dev/ttys-mixed-dev"
fi
OSASCRIPT
chmod +x "$MIXED_OSASCRIPT"

(
  cd "$MIXED_DIR"
  export ADL_SCRIPT_ROOT="$MIXED_ADAPTER_DIR"
  export ADL_MIXED_GHOSTTY_LOG="$MIXED_GHOSTTY_LOG"
  export ADL_TERMINAL_MACOS_TEST=1
  export ADL_OSASCRIPT="$MIXED_OSASCRIPT"
  export ADL_OSASCRIPT_LOG="$MIXED_OSASCRIPT_LOG"

  start="$(ADL_TRANSPORT=ghostty-macos "$ROOT/scripts/adl" architect start)"
  pin="$(print -r -- "$start" | awk '/^Pin: / { print $2 }')"
  session_id="$(cat .adl/active-session)"
  assert_contains "$(cat ".adl/sessions/$session_id/session.env")" "ADL_ARCHITECT_ADAPTER='ghostty-macos'" "mixed transport should store Ghostty architect adapter"
  assert_contains "$(cat ".adl/sessions/$session_id/session.env")" "ADL_ARCHITECT_TERMINAL='ghostty'" "mixed transport should store architect terminal metadata"
  assert_contains "$(cat ".adl/sessions/$session_id/session.env")" "ADL_ARCHITECT_LABEL='Mixed Ghostty architect'" "mixed transport should store architect label"

  ADL_TRANSPORT=terminal-macos "$ROOT/scripts/adl" dev connect "$pin" >/dev/null
  assert_contains "$(cat ".adl/sessions/$session_id/session.env")" "ADL_DEV_ADAPTER='terminal-macos'" "mixed transport should store Terminal.app dev adapter"
  assert_contains "$(cat ".adl/sessions/$session_id/session.env")" "ADL_DEV_TERMINAL='terminal-app'" "mixed transport should store dev terminal metadata"
  assert_contains "$(cat ".adl/sessions/$session_id/session.env")" "ADL_DEV_TERMINAL_ID='/dev/ttys-mixed-dev'" "mixed transport should store dev tty"
  assert_contains "$(cat "$MIXED_GHOSTTY_LOG")" "mixed-ghostty-architect|Dev connected and ready" "dev connect should notify through stored Ghostty architect adapter"

  mkdir -p .adl/staging
  write_dev_prompt .adl/staging/mixed-prompt.md
  "$ROOT/scripts/adl" architect send-dev --prompt-file .adl/staging/mixed-prompt.md >/dev/null
  assert_contains "$(cat "$MIXED_OSASCRIPT_LOG")" 'set targetTty to "/dev/ttys-mixed-dev"' "mixed handoff should send through stored Terminal.app dev adapter"

  write_dev_report ".adl/sessions/$session_id/runs/001/dev-report.md"
  "$ROOT/scripts/adl" dev notify >/dev/null
  assert_contains "$(cat "$MIXED_GHOSTTY_LOG")" "mixed-ghostty-architect|Developer's Report: read" "mixed report should send through stored Ghostty architect adapter"
)

AUTO_DIR="$TMP/auto-detect"
mkdir -p "$AUTO_DIR"
(
  cd "$AUTO_DIR"
  env -i \
    PATH="$PATH" \
    HOME="$HOME" \
    ADL_TRANSPORT=auto \
    ADL_SCRIPT_ROOT="$FAKE_ADAPTER_DIR" \
    ADL_TERMINAL_MACOS_TEST=1 \
    ADL_OSASCRIPT="$TERMINAL_OSASCRIPT" \
    ADL_OSASCRIPT_LOG="$TERMINAL_OSASCRIPT_LOG" \
    TERM_PROGRAM=Apple_Terminal \
    "$ROOT/scripts/adl" architect start >/dev/null
  auto_session="$(cat .adl/active-session)"
  assert_contains "$(cat ".adl/sessions/$auto_session/session.env")" "ADL_ARCHITECT_ADAPTER='terminal-macos'" "auto detection should select Terminal.app from TERM_PROGRAM"
)
