#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h}"
VERSION_FILE="$ROOT/VERSION"
[[ -f "$VERSION_FILE" ]] || {
  print -r -- "Missing required source file: $VERSION_FILE" >&2
  exit 4
}
VERSION="$(/bin/cat "$VERSION_FILE")"
TARGET_RUNTIME="all"
BUMP_MODE=""

usage() {
  print -r -- "Usage: .install.sh [--update] [--patch|--minor|--major] [--codex|--claude]" >&2
}

set_bump_mode() {
  local mode="$1"
  if [[ -n "$BUMP_MODE" ]]; then
    usage
    exit 2
  fi
  BUMP_MODE="$mode"
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --update) ;;
    --patch) set_bump_mode patch ;;
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
require_file "$ROOT/scripts/adl-reset"
require_file "$ROOT/scripts/commission"
require_file "$ROOT/scripts/commission-clear"
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

render_skill_template() {
  local file="$1"
  local skills_dir="$2"

  ADL_SKILLS_DIR="$skills_dir" "$PERL" -0pi -e 'BEGIN { $skills_dir=$ENV{ADL_SKILLS_DIR}; } s/\{\{ADL_SKILLS_DIR\}\}/$skills_dir/g' "$file"
}

if [[ -n "$BUMP_MODE" ]]; then
  VERSION="$(bumped_version "$BUMP_MODE" "$VERSION")"
  print -r -- "$VERSION" > "$VERSION_FILE"
  print -r -- "Bumped ADL product version to $VERSION."
fi

install_runtime() {
  local runtime="$1"
  local skills_dir source_skills_dir runtime_label

  if [[ "$runtime" == "claude" ]]; then
    skills_dir="${ADL_CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
    source_skills_dir="$ROOT/skills-claude"
    runtime_label="ADL Claude framework"
  else
    skills_dir="${ADL_CODEX_SKILLS_DIR:-$HOME/.codex/skills}"
    source_skills_dir="$ROOT/skills"
    runtime_label="ADL framework"
  fi

  local adl_target="$skills_dir/adl"
  local reset_target="$skills_dir/adl-reset"
  local connect_target="$skills_dir/adl-connect"
  local commission_target="$skills_dir/commission"
  local commission_clear_target="$skills_dir/commission-clear"
  local commission_connect_target="$skills_dir/commission-connect"
  local backup_root="$skills_dir/.adl-project-backups"
  local marker="$adl_target/.adl-framework"

  require_file "$source_skills_dir/adl/SKILL.md"
  require_file "$source_skills_dir/adl-reset/SKILL.md"
  require_file "$source_skills_dir/adl-connect/SKILL.md"
  require_file "$source_skills_dir/commission/SKILL.md"
  require_file "$source_skills_dir/commission-clear/SKILL.md"
  require_file "$source_skills_dir/commission-connect/SKILL.md"

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

  "$RM" -rf "$adl_target" "$skills_dir/adl-clear" "$reset_target" "$connect_target" "$commission_target" "$commission_clear_target" "$commission_connect_target"
  "$MKDIR" -p "$adl_target/scripts" "$connect_target"
  "$MKDIR" -p "$reset_target/scripts"
  "$MKDIR" -p "$commission_target/scripts" "$commission_connect_target"
  "$MKDIR" -p "$commission_clear_target/scripts"

  "$CP" "$source_skills_dir/adl/SKILL.md" "$adl_target/SKILL.md"
  "$CP" "$source_skills_dir/adl-reset/SKILL.md" "$reset_target/SKILL.md"
  "$CP" "$source_skills_dir/adl-connect/SKILL.md" "$connect_target/SKILL.md"
  "$CP" "$source_skills_dir/commission/SKILL.md" "$commission_target/SKILL.md"
  "$CP" "$source_skills_dir/commission-clear/SKILL.md" "$commission_clear_target/SKILL.md"
  "$CP" "$source_skills_dir/commission-connect/SKILL.md" "$commission_connect_target/SKILL.md"
  render_skill_template "$adl_target/SKILL.md" "$skills_dir"
  render_skill_template "$reset_target/SKILL.md" "$skills_dir"
  render_skill_template "$connect_target/SKILL.md" "$skills_dir"
  render_skill_template "$commission_target/SKILL.md" "$skills_dir"
  render_skill_template "$commission_clear_target/SKILL.md" "$skills_dir"
  render_skill_template "$commission_connect_target/SKILL.md" "$skills_dir"
  "$CP" "$ROOT/scripts/adl" "$adl_target/scripts/adl"
  "$CP" "$ROOT/VERSION" "$adl_target/VERSION"
  "$CP" "$ROOT/scripts/adl-reset" "$reset_target/scripts/adl-reset"
  "$CP" "$ROOT/scripts/commission" "$commission_target/scripts/commission"
  "$CP" "$ROOT/VERSION" "$commission_target/VERSION"
  "$CP" "$ROOT/scripts/commission-clear" "$commission_clear_target/scripts/commission-clear"
  "$CP" "$ROOT/scripts/ghostty-macos" "$adl_target/scripts/ghostty-macos"
  "$CP" "$ROOT/scripts/ghostty-macos" "$commission_target/scripts/ghostty-macos"
  "$CHMOD" +x "$adl_target/scripts/adl" "$adl_target/scripts/ghostty-macos"
  "$CHMOD" +x "$reset_target/scripts/adl-reset"
  "$CHMOD" +x "$commission_target/scripts/commission" "$commission_target/scripts/ghostty-macos"
  "$CHMOD" +x "$commission_clear_target/scripts/commission-clear"

  {
    print -r -- "ADL_VERSION='$VERSION'"
    print -r -- "ADL_SOURCE='$ROOT'"
  } > "$marker"

  {
    print -r -- "COMMISSION_VERSION='$VERSION'"
    print -r -- "COMMISSION_SOURCE='$ROOT'"
  } > "$commission_target/.commission-framework"

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
