#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/tests/assert.sh"

TMP="$(new_tmpdir)"
trap 'rm -rf "$TMP"' EXIT

export ADL_CODEX_SKILLS_DIR="$TMP/skills"
mkdir -p "$ADL_CODEX_SKILLS_DIR/adl"
print -r -- "legacy skill" > "$ADL_CODEX_SKILLS_DIR/adl/SKILL.md"

output="$("$ROOT/.install.sh")"

assert_contains "$output" "Backed up existing adl skill" "installer should back up legacy skill"
assert_file_exists "$ADL_CODEX_SKILLS_DIR/adl/.adl-framework"
assert_file_exists "$ADL_CODEX_SKILLS_DIR/adl/scripts/adl"
assert_file_exists "$ADL_CODEX_SKILLS_DIR/adl/scripts/ghostty-macos"
assert_file_exists "$ADL_CODEX_SKILLS_DIR/adl-connect/SKILL.md"

backup_count="$(find "$ADL_CODEX_SKILLS_DIR/.adl-project-backups" -name SKILL.md | wc -l | tr -d ' ')"
assert_eq "1" "$backup_count" "one legacy skill backup should exist"

second="$("$ROOT/.install.sh")"
assert_contains "$second" "Installed ADL framework" "second install should be idempotent"

backup_count_after="$(find "$ADL_CODEX_SKILLS_DIR/.adl-project-backups" -name SKILL.md | wc -l | tr -d ' ')"
assert_eq "1" "$backup_count_after" "idempotent reinstall should not create another backup"
