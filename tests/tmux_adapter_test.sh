#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/tests/assert.sh"

TMP="$(new_tmpdir)"
trap 'rm -rf "$TMP"' EXIT

FAKE_BIN="$TMP/bin"
TMUX_LOG="$TMP/tmux.log"
mkdir -p "$FAKE_BIN"

/bin/cat > "$FAKE_BIN/tmux" <<'TMUX'
#!/bin/zsh
set -euo pipefail

print -r -- "$*" >> "$ADL_TMUX_LOG"
case "${1:-}" in
  display-message)
    [[ "${2:-}" == "-p" && "${3:-}" == '#{pane_id}' ]] || exit 2
    print -r -- "${ADL_FAKE_TMUX_PANE_ID:-%42}"
    ;;
  send-keys)
    exit 0
    ;;
  *)
    exit 2
    ;;
esac
TMUX
chmod +x "$FAKE_BIN/tmux"

export PATH="$FAKE_BIN:$PATH"
export ADL_TMUX_LOG="$TMUX_LOG"
export TMUX="/tmp/fake-tmux,123,0"

capture="$("$ROOT/scripts/tmux" capture-focused architect)"
assert_contains "$capture" "ADL_ARCHITECT_ADAPTER='tmux'" "tmux capture should emit architect adapter"
assert_contains "$capture" "ADL_ARCHITECT_TERMINAL_ID='%42'" "tmux capture should emit pane id"

dev_capture="$(ADL_FAKE_TMUX_PANE_ID="%77" "$ROOT/scripts/tmux" capture-focused dev)"
assert_contains "$dev_capture" "ADL_DEV_ADAPTER='tmux'" "tmux capture should emit dev adapter"
assert_contains "$dev_capture" "ADL_DEV_TERMINAL_ID='%77'" "tmux capture should emit role-specific pane id"

"$ROOT/scripts/tmux" send "%42" "Architect's Request: read file"
assert_contains "$(cat "$TMUX_LOG")" "send-keys -t %42 Architect's Request: read file Enter" "tmux send should send message and Enter"

set +e
missing_context="$(TMUX= "$ROOT/scripts/tmux" capture-focused architect 2>&1)"
missing_context_code="$?"
set -e
assert_eq "3" "$missing_context_code" "tmux capture should fail outside tmux context"
assert_contains "$missing_context" "requires running inside a tmux session" "tmux context failure should be clear"

NO_TMUX_BIN="$TMP/no-tmux-bin"
mkdir -p "$NO_TMUX_BIN"
set +e
missing_tmux="$(PATH="$NO_TMUX_BIN" "$ROOT/scripts/tmux" capture-focused architect 2>&1)"
missing_tmux_code="$?"
set -e
assert_eq "3" "$missing_tmux_code" "tmux capture should fail when tmux executable is missing"
assert_contains "$missing_tmux" "requires tmux on PATH" "missing tmux failure should be clear"
