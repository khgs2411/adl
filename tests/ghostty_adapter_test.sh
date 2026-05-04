#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/tests/assert.sh"

export ADL_GHOSTTY_DRY_RUN=1

capture="$("$ROOT/scripts/ghostty-macos" capture-focused architect)"
assert_contains "$capture" "ADL_ARCHITECT_ADAPTER='ghostty-macos'" "capture should emit architect adapter"
assert_contains "$capture" "ADL_ARCHITECT_TERMINAL_ID='dry-run-architect-terminal'" "capture should emit dry architect terminal id"

dev_capture="$("$ROOT/scripts/ghostty-macos" capture-focused dev)"
assert_contains "$dev_capture" "ADL_DEV_TERMINAL_ID='dry-run-dev-terminal'" "capture should emit dry dev terminal id"

send="$("$ROOT/scripts/ghostty-macos" send dry-run-dev-terminal "Architect's Request:\nRead file")"
assert_contains "$send" "DRY RUN send to dry-run-dev-terminal" "send should dry-run"

set +e
bad="$("$ROOT/scripts/ghostty-macos" send "" "message" 2>&1)"
code="$?"
set -e
assert_eq "3" "$code" "empty terminal id should be transport failure"
assert_contains "$bad" "Missing terminal id" "empty terminal id should explain failure"
