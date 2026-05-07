#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/tests/assert.sh"

TMP="$(new_tmpdir)"
trap 'rm -rf "$TMP"' EXIT
cd "$TMP"

export ADL_GHOSTTY_DRY_RUN=1
export ADL_SCRIPT_ROOT="$ROOT/scripts"
ADL_PATH="${PWD:A}/.adl"

start="$("$ROOT/scripts/adl" architect start)"
assert_contains "$start" "ADL session ready" "start should create session before reset"
assert_dir_exists ".adl"

reset_output="$("$ROOT/scripts/adl-reset" "$PWD/.adl")"
assert_contains "$reset_output" "Reset ADL state: $ADL_PATH" "adl-reset should report reset path"
[[ ! -e ".adl" ]] || fail "expected .adl to be removed"

missing_output="$("$ROOT/scripts/adl-reset" "$PWD/.adl")"
assert_contains "$missing_output" "No ADL state found: $ADL_PATH" "adl-reset should be idempotent when .adl is absent"
[[ ! -e ".adl" ]] || fail "expected .adl to stay absent after idempotent reset"

status_after_reset="$("$ROOT/scripts/adl" status)"
assert_contains "$status_after_reset" "No active ADL session." "status should be clean after reset"

mkdir -p other/.adl
set +e
wrong_path="$("$ROOT/scripts/adl-reset" "$PWD/other/.adl" 2>&1)"
wrong_code="$?"
set -e
assert_eq "1" "$wrong_code" "adl-reset should reject a .adl path outside cwd"
assert_contains "$wrong_path" "Refusing to reset anything except this working directory's .adl" "adl-reset should explain path guard"
assert_dir_exists "other/.adl"
