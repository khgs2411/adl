#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h}"
VERSION="0.4.7"
UPDATE=0
TARGET_RUNTIME="all"
BUMP_MODE="patch"
BUMP_MODE_SET=0

usage() {
  print -r -- "Usage: .install.sh [--update] [--minor|--major] [--codex|--claude]" >&2
}

set_bump_mode() {
  local mode="$1"
  if [[ "$BUMP_MODE_SET" == "1" ]]; then
    usage
    exit 2
  fi
  BUMP_MODE="$mode"
  BUMP_MODE_SET=1
  UPDATE=1
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --update) UPDATE=1 ;;
    --minor) set_bump_mode minor ;;
    --major) set_bump_mode major ;;
    --codex) TARGET_RUNTIME="codex" ;;
    --claude) TARGET_RUNTIME="claude" ;;
    *) usage; exit 2 ;;
  esac
  shift
done

CP="/bin/cp"
CHMOD="/bin/chmod"
DATE="/bin/date"
MKDIR="/bin/mkdir"
RM="/bin/rm"
PERL="/usr/bin/perl"

require_file() {
  [[ -f "$1" ]] || {
    print -r -- "Missing required source file: $1" >&2
    exit 4
  }
}

require_file "$ROOT/scripts/adl"
require_file "$ROOT/scripts/adl-clear"
require_file "$ROOT/scripts/ghostty-macos"

bumped_version() {
  local mode="$1"
  local version="$2"
  local parts major minor patch

  parts=("${(@s:.:)version}")
  [[ "${#parts[@]}" == "3" ]] || {
    print -r -- "Invalid VERSION: $version" >&2
    exit 5
  }

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

replace_version_in_file() {
  local file="$1"
  local version="$2"

  "$PERL" -0pi -e 's/VERSION="[0-9]+\.[0-9]+\.[0-9]+"/VERSION="'$version'"/' "$file"
}

render_skill_template() {
  local file="$1"
  local skills_dir="$2"

  ADL_SKILLS_DIR="$skills_dir" "$PERL" -0pi -e 'BEGIN { $skills_dir=$ENV{ADL_SKILLS_DIR}; } s/\{\{ADL_SKILLS_DIR\}\}/$skills_dir/g' "$file"
}

if [[ "$UPDATE" == "1" ]]; then
  VERSION="$(bumped_version "$BUMP_MODE" "$VERSION")"
  replace_version_in_file "$ROOT/.install.sh" "$VERSION"
  replace_version_in_file "$ROOT/scripts/adl" "$VERSION"
fi

install_runtime() {
  local runtime="$1"
  local skills_dir source_skills_dir runtime_label update_hint

  if [[ "$runtime" == "claude" ]]; then
    skills_dir="${ADL_CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
    source_skills_dir="$ROOT/skills-claude"
    runtime_label="ADL Claude framework"
    update_hint="./.install.sh --claude --update"
    if [[ "$TARGET_RUNTIME" == "all" ]]; then
      update_hint="./.install.sh --update --claude"
    fi
  else
    skills_dir="${ADL_CODEX_SKILLS_DIR:-$HOME/.codex/skills}"
    source_skills_dir="$ROOT/skills"
    runtime_label="ADL framework"
    update_hint="./.install.sh --update"
    if [[ "$TARGET_RUNTIME" == "all" ]]; then
      update_hint="./.install.sh --update --codex"
    fi
  fi

  local adl_target="$skills_dir/adl"
  local clear_target="$skills_dir/adl-clear"
  local connect_target="$skills_dir/adl-connect"
  local backup_root="$skills_dir/.adl-project-backups"
  local marker="$adl_target/.adl-framework"

  require_file "$source_skills_dir/adl/SKILL.md"
  require_file "$source_skills_dir/adl-clear/SKILL.md"
  require_file "$source_skills_dir/adl-connect/SKILL.md"

  "$MKDIR" -p "$skills_dir"

  if [[ -d "$adl_target" && ! -f "$marker" ]]; then
    local ts backup
    ts="$("$DATE" +%Y%m%d-%H%M%S)"
    backup="$backup_root/$ts/adl"
    "$MKDIR" -p "$backup:h"
    "$CP" -R "$adl_target" "$backup"
    print -r -- "Backed up existing adl skill to: $backup"
    print -r -- "Rollback: \"$RM\" -rf '$adl_target' && \"$CP\" -R '$backup' '$adl_target'"
  fi

  if [[ -f "$marker" && "$UPDATE" != "1" ]]; then
    print -r -- "$runtime_label already installed at $adl_target"
    print -r -- "Run $update_hint to replace it with version $VERSION."
    return 0
  fi

  "$RM" -rf "$adl_target" "$clear_target" "$connect_target"
  "$MKDIR" -p "$adl_target/scripts" "$connect_target"
  "$MKDIR" -p "$clear_target/scripts"

  "$CP" "$source_skills_dir/adl/SKILL.md" "$adl_target/SKILL.md"
  "$CP" "$source_skills_dir/adl-clear/SKILL.md" "$clear_target/SKILL.md"
  "$CP" "$source_skills_dir/adl-connect/SKILL.md" "$connect_target/SKILL.md"
  render_skill_template "$adl_target/SKILL.md" "$skills_dir"
  render_skill_template "$clear_target/SKILL.md" "$skills_dir"
  render_skill_template "$connect_target/SKILL.md" "$skills_dir"
  "$CP" "$ROOT/scripts/adl" "$adl_target/scripts/adl"
  "$CP" "$ROOT/scripts/adl-clear" "$clear_target/scripts/adl-clear"
  "$CP" "$ROOT/scripts/ghostty-macos" "$adl_target/scripts/ghostty-macos"
  "$CHMOD" +x "$adl_target/scripts/adl" "$adl_target/scripts/ghostty-macos"
  "$CHMOD" +x "$clear_target/scripts/adl-clear"

  {
    print -r -- "ADL_VERSION='$VERSION'"
    print -r -- "ADL_SOURCE='$ROOT'"
  } > "$marker"

  print -r -- "Installed $runtime_label $VERSION into $skills_dir"
}

case "$TARGET_RUNTIME" in
  codex) install_runtime codex ;;
  claude) install_runtime claude ;;
  all)
    install_runtime codex
    install_runtime claude
    ;;
esac
