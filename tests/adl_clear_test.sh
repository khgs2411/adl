#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/tests/assert.sh"

TMP="$(new_tmpdir)"
trap 'rm -rf "$TMP"' EXIT
cd "$TMP"

export ADL_GHOSTTY_DRY_RUN=1
export ADL_TRANSPORT=ghostty-macos
export ADL_SCRIPT_ROOT="$ROOT/scripts"
ADL_PATH="${PWD:A}/.adl"

start="$("$ROOT/scripts/adl" architect start)"
assert_contains "$start" "ADL session ready" "start should create session before clear"
assert_dir_exists ".adl"

clear_output="$("$ROOT/scripts/adl-clear" "$PWD/.adl")"
assert_contains "$clear_output" "Cleared ADL state: $ADL_PATH" "adl-clear should report cleared path"
[[ ! -e ".adl" ]] || fail "expected .adl to be removed"

missing_output="$("$ROOT/scripts/adl-clear" "$PWD/.adl")"
assert_contains "$missing_output" "No ADL state found: $ADL_PATH" "adl-clear should be idempotent when .adl is absent"
[[ ! -e ".adl" ]] || fail "expected .adl to stay absent after idempotent clear"

status_after_clear="$("$ROOT/scripts/adl" status)"
assert_contains "$status_after_clear" "No active ADL session." "status should be clean after clear"

mkdir -p other/.adl
set +e
wrong_path="$("$ROOT/scripts/adl-clear" "$PWD/other/.adl" 2>&1)"
wrong_code="$?"
set -e
assert_eq "1" "$wrong_code" "adl-clear should reject a .adl path outside cwd"
assert_contains "$wrong_path" "Refusing to clear anything except this working directory's .adl" "adl-clear should explain path guard"
assert_dir_exists "other/.adl"
