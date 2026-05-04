#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/tests/assert.sh"

TMP="$(new_tmpdir)"
trap 'rm -rf "$TMP"' EXIT

INSTALL_ROOT="$TMP/project"
mkdir -p "$INSTALL_ROOT"
/bin/cp "$ROOT/.install.sh" "$INSTALL_ROOT/.install.sh"
/bin/cp -R "$ROOT/scripts" "$INSTALL_ROOT/scripts"
/bin/cp -R "$ROOT/skills" "$INSTALL_ROOT/skills"
/bin/cp -R "$ROOT/skills-claude" "$INSTALL_ROOT/skills-claude"

test_bumped_version() {
  local mode="$1"
  local version="$2"
  local parts major minor patch

  parts=("${(@s:.:)version}")
  major="${parts[1]}"
  minor="${parts[2]}"
  patch="${parts[3]}"

  case "$mode" in
    major) major=$((major + 1)); minor=0; patch=0 ;;
    minor) minor=$((minor + 1)); patch=0 ;;
    patch) patch=$((patch + 1)) ;;
  esac

  print -r -- "$major.$minor.$patch"
}

expected_version="$(grep '^VERSION=' "$INSTALL_ROOT/.install.sh" | sed 's/VERSION="//;s/"//')"

export ADL_CODEX_SKILLS_DIR="$TMP/skills"
export ADL_CLAUDE_SKILLS_DIR="$TMP/claude-skills"
mkdir -p "$ADL_CODEX_SKILLS_DIR/adl"
print -r -- "legacy skill" > "$ADL_CODEX_SKILLS_DIR/adl/SKILL.md"

output="$("$INSTALL_ROOT/.install.sh")"

assert_contains "$output" "Backed up existing adl skill" "installer should back up legacy skill"
assert_contains "$output" "Installed ADL framework" "default install should report codex install"
assert_contains "$output" "Installed ADL Claude framework" "default install should report claude install"
assert_file_exists "$ADL_CODEX_SKILLS_DIR/adl/.adl-framework"
assert_file_exists "$ADL_CODEX_SKILLS_DIR/adl/scripts/adl"
assert_file_exists "$ADL_CODEX_SKILLS_DIR/adl/scripts/ghostty-macos"
assert_file_exists "$ADL_CODEX_SKILLS_DIR/adl-connect/SKILL.md"
assert_file_exists "$ADL_CLAUDE_SKILLS_DIR/adl/.adl-framework"
assert_file_exists "$ADL_CLAUDE_SKILLS_DIR/adl/scripts/adl"
assert_file_exists "$ADL_CLAUDE_SKILLS_DIR/adl/scripts/ghostty-macos"
assert_file_exists "$ADL_CLAUDE_SKILLS_DIR/adl-connect/SKILL.md"

backup_count="$(find "$ADL_CODEX_SKILLS_DIR/.adl-project-backups" -name SKILL.md | wc -l | tr -d ' ')"
assert_eq "1" "$backup_count" "one legacy skill backup should exist"

second="$("$INSTALL_ROOT/.install.sh")"
assert_contains "$second" "already installed" "second install should require explicit update"
assert_contains "$second" "./.install.sh --update" "codex reinstall hint should preserve codex target"
assert_contains "$second" "./.install.sh --update --codex" "default reinstall hint should include explicit codex target option"
assert_contains "$second" "./.install.sh --update --claude" "default reinstall hint should include explicit claude target option"

backup_count_after="$(find "$ADL_CODEX_SKILLS_DIR/.adl-project-backups" -name SKILL.md | wc -l | tr -d ' ')"
assert_eq "1" "$backup_count_after" "idempotent reinstall should not create another backup"

updated="$("$INSTALL_ROOT/.install.sh" --update)"
expected_version="$(test_bumped_version patch "$expected_version")"
assert_contains "$updated" "Installed ADL framework" "explicit update should reinstall framework"
assert_contains "$updated" "Installed ADL Claude framework" "explicit update should reinstall claude framework"
assert_contains "$(cat "$ADL_CODEX_SKILLS_DIR/adl/.adl-framework")" "ADL_VERSION='$expected_version'" "update should bump and write patch version"
assert_contains "$(cat "$ADL_CLAUDE_SKILLS_DIR/adl/.adl-framework")" "ADL_VERSION='$expected_version'" "default update should bump and write claude patch version"
assert_contains "$(cat "$INSTALL_ROOT/.install.sh")" "VERSION=\"$expected_version\"" "update should persist bumped installer version"
assert_contains "$(cat "$INSTALL_ROOT/scripts/adl")" "VERSION=\"$expected_version\"" "update should persist bumped CLI version"

claude_output="$("$INSTALL_ROOT/.install.sh" --claude --update)"
expected_version="$(test_bumped_version patch "$expected_version")"
assert_contains "$claude_output" "Installed ADL Claude framework" "claude install should report claude target"
assert_not_contains "$claude_output" "Installed ADL framework" "explicit claude install should not report codex target"
assert_file_exists "$ADL_CLAUDE_SKILLS_DIR/adl/.adl-framework"
assert_file_exists "$ADL_CLAUDE_SKILLS_DIR/adl/SKILL.md"
assert_file_exists "$ADL_CLAUDE_SKILLS_DIR/adl/scripts/adl"
assert_file_exists "$ADL_CLAUDE_SKILLS_DIR/adl/scripts/ghostty-macos"
assert_file_exists "$ADL_CLAUDE_SKILLS_DIR/adl-connect/SKILL.md"
assert_contains "$(cat "$ADL_CLAUDE_SKILLS_DIR/adl/.adl-framework")" "ADL_VERSION='$expected_version'" "claude marker should write bumped patch version"
assert_contains "$(cat "$ADL_CLAUDE_SKILLS_DIR/adl/SKILL.md")" "Claude Code" "claude architect skill should use Claude language"
assert_contains "$(cat "$ADL_CLAUDE_SKILLS_DIR/adl/SKILL.md")" "/Users/liadgoren/.claude/skills/adl/scripts/adl" "claude architect skill should use claude absolute CLI path"
assert_contains "$(cat "$ADL_CLAUDE_SKILLS_DIR/adl-connect/SKILL.md")" "Claude Code" "claude connect skill should use Claude language"

claude_second="$("$INSTALL_ROOT/.install.sh" --claude)"
assert_contains "$claude_second" "already installed" "second claude install should require explicit update"
assert_contains "$claude_second" "./.install.sh --claude --update" "claude reinstall hint should preserve claude target"

claude_updated="$("$INSTALL_ROOT/.install.sh" --claude --update)"
expected_version="$(test_bumped_version patch "$expected_version")"
assert_contains "$claude_updated" "Installed ADL Claude framework" "explicit claude update should reinstall framework"
assert_not_contains "$claude_updated" "Installed ADL framework" "explicit claude update should not report codex target"
assert_contains "$(cat "$ADL_CLAUDE_SKILLS_DIR/adl/.adl-framework")" "ADL_VERSION='$expected_version'" "second claude update should bump patch again"

codex_updated="$("$INSTALL_ROOT/.install.sh" --codex --update)"
expected_version="$(test_bumped_version patch "$expected_version")"
assert_contains "$codex_updated" "Installed ADL framework" "explicit codex update should reinstall codex framework"
assert_not_contains "$codex_updated" "Installed ADL Claude framework" "explicit codex update should not report claude target"
assert_contains "$(cat "$ADL_CODEX_SKILLS_DIR/adl/.adl-framework")" "ADL_VERSION='$expected_version'" "explicit codex update should bump patch again"

minor_updated="$("$INSTALL_ROOT/.install.sh" --update --minor)"
expected_version="$(test_bumped_version minor "$expected_version")"
assert_contains "$minor_updated" "Installed ADL framework" "minor update should install codex framework"
assert_contains "$minor_updated" "Installed ADL Claude framework" "minor update should install claude framework"
assert_contains "$(cat "$ADL_CODEX_SKILLS_DIR/adl/.adl-framework")" "ADL_VERSION='$expected_version'" "minor update should bump minor and reset patch"
assert_contains "$(cat "$ADL_CLAUDE_SKILLS_DIR/adl/.adl-framework")" "ADL_VERSION='$expected_version'" "minor update should write bumped minor version to claude"
assert_contains "$(cat "$INSTALL_ROOT/.install.sh")" "VERSION=\"$expected_version\"" "minor update should persist installer version"
assert_contains "$(cat "$INSTALL_ROOT/scripts/adl")" "VERSION=\"$expected_version\"" "minor update should persist CLI version"

major_updated="$("$INSTALL_ROOT/.install.sh" --codex --major)"
expected_version="$(test_bumped_version major "$expected_version")"
assert_contains "$major_updated" "Installed ADL framework" "major update should install requested codex framework"
assert_not_contains "$major_updated" "Installed ADL Claude framework" "major codex update should not install claude framework"
assert_contains "$(cat "$ADL_CODEX_SKILLS_DIR/adl/.adl-framework")" "ADL_VERSION='$expected_version'" "major update should bump major and reset minor and patch"
assert_contains "$(cat "$INSTALL_ROOT/.install.sh")" "VERSION=\"$expected_version\"" "major update should persist installer version"
assert_contains "$(cat "$INSTALL_ROOT/scripts/adl")" "VERSION=\"$expected_version\"" "major update should persist CLI version"

set +e
bad_flags="$("$INSTALL_ROOT/.install.sh" --bogus 2>&1)"
bad_flags_code="$?"
set -e
assert_eq "2" "$bad_flags_code" "unknown flags should fail clearly"
assert_contains "$bad_flags" "Usage: .install.sh [--update] [--minor|--major] [--codex|--claude]" "bad flags should print usage"
