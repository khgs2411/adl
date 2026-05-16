#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/tests/assert.sh"

TMP="$(new_tmpdir)"
trap 'rm -rf "$TMP"' EXIT

INSTALL_ROOT="$TMP/project"
mkdir -p "$INSTALL_ROOT"
/bin/cp "$ROOT/.install.sh" "$INSTALL_ROOT/.install.sh"
/bin/cp "$ROOT/VERSION" "$INSTALL_ROOT/VERSION"
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

expected_version="$(cat "$INSTALL_ROOT/VERSION")"

default_home="$TMP/home"
mkdir -p "$default_home"
default_output="$(HOME="$default_home" "$INSTALL_ROOT/.install.sh")"
assert_contains "$default_output" "Installed ADL framework" "default install should report codex install with HOME defaults"
assert_contains "$default_output" "Installed ADL Claude framework" "default install should report claude install with HOME defaults"
assert_file_exists "$default_home/.codex/skills/adl/.adl-framework"
assert_file_exists "$default_home/.claude/skills/adl/.adl-framework"
assert_contains "$(cat "$default_home/.codex/skills/adl/SKILL.md")" "$default_home/.codex/skills/adl/scripts/adl" "codex installed skill should point to HOME default install path"
assert_contains "$(cat "$default_home/.claude/skills/adl/SKILL.md")" "$default_home/.claude/skills/adl/scripts/adl" "claude installed skill should point to HOME default install path"
assert_not_contains "$(cat "$default_home/.codex/skills/adl/SKILL.md")" "{{ADL_SKILLS_DIR}}" "codex installed skill should render install path token"
assert_not_contains "$(cat "$default_home/.claude/skills/adl/SKILL.md")" "{{ADL_SKILLS_DIR}}" "claude installed skill should render install path token"
assert_not_contains "$(cat "$default_home/.codex/skills/adl/SKILL.md")" "/Users/liadgoren/.codex/skills" "codex installed skill should not contain maintainer-local path"
assert_not_contains "$(cat "$default_home/.claude/skills/adl/SKILL.md")" "/Users/liadgoren/.claude/skills" "claude installed skill should not contain maintainer-local path"

export ADL_CODEX_SKILLS_DIR="$TMP/skills"
export ADL_CLAUDE_SKILLS_DIR="$TMP/claude-skills"
mkdir -p "$ADL_CODEX_SKILLS_DIR/adl"
print -r -- "legacy skill" > "$ADL_CODEX_SKILLS_DIR/adl/SKILL.md"

output="$("$INSTALL_ROOT/.install.sh")"

assert_contains "$output" "Backed up existing adl skill" "installer should back up legacy skill"
assert_contains "$output" "Installed ADL framework" "default install should report codex install"
assert_contains "$output" "Installed ADL Claude framework" "default install should report claude install"
assert_file_exists "$ADL_CODEX_SKILLS_DIR/adl/.adl-framework"
assert_file_exists "$ADL_CODEX_SKILLS_DIR/adl/VERSION"
assert_file_exists "$ADL_CODEX_SKILLS_DIR/adl/scripts/adl"
assert_file_exists "$ADL_CODEX_SKILLS_DIR/adl/scripts/ghostty-macos"
assert_file_exists "$ADL_CODEX_SKILLS_DIR/adl-reset/SKILL.md"
assert_file_exists "$ADL_CODEX_SKILLS_DIR/adl-reset/scripts/adl-reset"
assert_file_exists "$ADL_CODEX_SKILLS_DIR/adl-connect/SKILL.md"
assert_contains "$(cat "$ADL_CODEX_SKILLS_DIR/adl/SKILL.md")" "$ADL_CODEX_SKILLS_DIR/adl/scripts/adl" "codex installed skill should point to overridden install path"
assert_file_exists "$ADL_CLAUDE_SKILLS_DIR/adl/.adl-framework"
assert_file_exists "$ADL_CLAUDE_SKILLS_DIR/adl/VERSION"
assert_file_exists "$ADL_CLAUDE_SKILLS_DIR/adl/scripts/adl"
assert_file_exists "$ADL_CLAUDE_SKILLS_DIR/adl/scripts/ghostty-macos"
assert_file_exists "$ADL_CLAUDE_SKILLS_DIR/adl-reset/SKILL.md"
assert_file_exists "$ADL_CLAUDE_SKILLS_DIR/adl-reset/scripts/adl-reset"
assert_file_exists "$ADL_CLAUDE_SKILLS_DIR/adl-connect/SKILL.md"
assert_contains "$(cat "$ADL_CLAUDE_SKILLS_DIR/adl/SKILL.md")" "$ADL_CLAUDE_SKILLS_DIR/adl/scripts/adl" "claude installed skill should point to overridden install path"

backup_count="$(find "$ADL_CODEX_SKILLS_DIR/.adl-project-backups" -name SKILL.md | wc -l | tr -d ' ')"
assert_eq "1" "$backup_count" "one legacy skill backup should exist"

second="$("$INSTALL_ROOT/.install.sh")"
assert_contains "$second" "Installed ADL framework" "second install should reinstall codex by default"
assert_contains "$second" "Installed ADL Claude framework" "second install should reinstall claude by default"
assert_contains "$(cat "$INSTALL_ROOT/VERSION")" "$expected_version" "plain reinstall should not bump product version file"

backup_count_after="$(find "$ADL_CODEX_SKILLS_DIR/.adl-project-backups" -name SKILL.md | wc -l | tr -d ' ')"
assert_eq "1" "$backup_count_after" "idempotent reinstall should not create another backup"

updated="$("$INSTALL_ROOT/.install.sh" --update)"
assert_contains "$updated" "Installed ADL framework" "explicit update should reinstall framework"
assert_contains "$updated" "Installed ADL Claude framework" "explicit update should reinstall claude framework"
assert_contains "$(cat "$ADL_CODEX_SKILLS_DIR/adl/.adl-framework")" "ADL_VERSION='$expected_version'" "update should reinstall current product version"
assert_contains "$(cat "$ADL_CLAUDE_SKILLS_DIR/adl/.adl-framework")" "ADL_VERSION='$expected_version'" "default update should reinstall current product version for claude"
assert_contains "$(cat "$INSTALL_ROOT/VERSION")" "$expected_version" "update should not bump product version file"

bumped_patch="$("$INSTALL_ROOT/.install.sh" --patch)"
expected_version="$(test_bumped_version patch "$expected_version")"
assert_contains "$bumped_patch" "Bumped ADL product version to $expected_version." "explicit patch bump should report product version bump"
assert_contains "$bumped_patch" "Installed ADL framework" "explicit patch bump should install codex framework"
assert_contains "$bumped_patch" "Installed ADL Claude framework" "explicit patch bump should install claude framework"
assert_contains "$(cat "$ADL_CODEX_SKILLS_DIR/adl/.adl-framework")" "ADL_VERSION='$expected_version'" "explicit patch bump should write bumped product version"
assert_contains "$(cat "$ADL_CLAUDE_SKILLS_DIR/adl/.adl-framework")" "ADL_VERSION='$expected_version'" "explicit patch bump should write bumped claude product version"
assert_contains "$(cat "$INSTALL_ROOT/VERSION")" "$expected_version" "explicit patch bump should persist product version file"

claude_output="$("$INSTALL_ROOT/.install.sh" --claude --update)"
assert_contains "$claude_output" "Installed ADL Claude framework" "claude install should report claude target"
assert_not_contains "$claude_output" "Installed ADL framework" "explicit claude install should not report codex target"
assert_file_exists "$ADL_CLAUDE_SKILLS_DIR/adl/.adl-framework"
assert_file_exists "$ADL_CLAUDE_SKILLS_DIR/adl/VERSION"
assert_file_exists "$ADL_CLAUDE_SKILLS_DIR/adl/SKILL.md"
assert_file_exists "$ADL_CLAUDE_SKILLS_DIR/adl/scripts/adl"
assert_file_exists "$ADL_CLAUDE_SKILLS_DIR/adl/scripts/ghostty-macos"
assert_file_exists "$ADL_CLAUDE_SKILLS_DIR/adl-reset/SKILL.md"
assert_file_exists "$ADL_CLAUDE_SKILLS_DIR/adl-reset/scripts/adl-reset"
assert_file_exists "$ADL_CLAUDE_SKILLS_DIR/adl-connect/SKILL.md"
assert_contains "$(cat "$ADL_CLAUDE_SKILLS_DIR/adl/.adl-framework")" "ADL_VERSION='$expected_version'" "claude marker should keep current product version"
assert_contains "$(cat "$ADL_CLAUDE_SKILLS_DIR/adl/SKILL.md")" "Claude Code" "claude architect skill should use Claude language"
assert_contains "$(cat "$ADL_CLAUDE_SKILLS_DIR/adl/SKILL.md")" "$ADL_CLAUDE_SKILLS_DIR/adl/scripts/adl" "claude architect skill should use installed claude CLI path"
assert_contains "$(cat "$ADL_CLAUDE_SKILLS_DIR/adl-connect/SKILL.md")" "Claude Code" "claude connect skill should use Claude language"

claude_second="$("$INSTALL_ROOT/.install.sh" --claude)"
assert_contains "$claude_second" "Installed ADL Claude framework" "second claude install should reinstall claude runtime"
assert_not_contains "$claude_second" "Installed ADL framework" "second claude install should not install codex runtime"
assert_contains "$(cat "$ADL_CLAUDE_SKILLS_DIR/adl/.adl-framework")" "ADL_VERSION='$expected_version'" "second claude install should keep current product version"

claude_updated="$("$INSTALL_ROOT/.install.sh" --claude --update)"
assert_contains "$claude_updated" "Installed ADL Claude framework" "explicit claude update should reinstall framework"
assert_not_contains "$claude_updated" "Installed ADL framework" "explicit claude update should not report codex target"
assert_contains "$(cat "$ADL_CLAUDE_SKILLS_DIR/adl/.adl-framework")" "ADL_VERSION='$expected_version'" "second claude update should keep current product version"

codex_updated="$("$INSTALL_ROOT/.install.sh" --codex --update)"
assert_contains "$codex_updated" "Installed ADL framework" "explicit codex update should reinstall codex framework"
assert_not_contains "$codex_updated" "Installed ADL Claude framework" "explicit codex update should not report claude target"
assert_contains "$(cat "$ADL_CODEX_SKILLS_DIR/adl/.adl-framework")" "ADL_VERSION='$expected_version'" "explicit codex update should keep current product version"

minor_updated="$("$INSTALL_ROOT/.install.sh" --minor)"
expected_version="$(test_bumped_version minor "$expected_version")"
assert_contains "$minor_updated" "Installed ADL framework" "minor update should install codex framework"
assert_contains "$minor_updated" "Installed ADL Claude framework" "minor update should install claude framework"
assert_contains "$minor_updated" "Bumped ADL product version to $expected_version." "explicit minor bump should report product version bump"
assert_contains "$(cat "$ADL_CODEX_SKILLS_DIR/adl/.adl-framework")" "ADL_VERSION='$expected_version'" "minor bump should bump minor and reset patch"
assert_contains "$(cat "$ADL_CLAUDE_SKILLS_DIR/adl/.adl-framework")" "ADL_VERSION='$expected_version'" "minor bump should write bumped minor version to claude"
assert_contains "$(cat "$INSTALL_ROOT/VERSION")" "$expected_version" "minor bump should persist product version file"

major_updated="$("$INSTALL_ROOT/.install.sh" --codex --major)"
expected_version="$(test_bumped_version major "$expected_version")"
assert_contains "$major_updated" "Installed ADL framework" "major update should install requested codex framework"
assert_not_contains "$major_updated" "Installed ADL Claude framework" "major codex update should not install claude framework"
assert_contains "$major_updated" "Bumped ADL product version to $expected_version." "explicit major bump should report product version bump"
assert_contains "$(cat "$ADL_CODEX_SKILLS_DIR/adl/.adl-framework")" "ADL_VERSION='$expected_version'" "major bump should bump major and reset minor and patch"
assert_contains "$(cat "$INSTALL_ROOT/VERSION")" "$expected_version" "major bump should persist product version file"

set +e
bad_flags="$("$INSTALL_ROOT/.install.sh" --bogus 2>&1)"
bad_flags_code="$?"
set -e
assert_eq "2" "$bad_flags_code" "unknown flags should fail clearly"
assert_contains "$bad_flags" "Usage: .install.sh [--update] [--patch|--minor|--major] [--codex|--claude]" "bad flags should print usage"
