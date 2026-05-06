#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h}"
VERSION="0.4.10"
UPDATE=0
TARGET_RUNTIME="all"
BUMP_MODE="patch"
BUMP_MODE_SET=0
INSTALL_TRANSPORT="${ADL_INSTALL_TRANSPORT:-}"

usage() {
  print -r -- "Usage: .install.sh [--update] [--minor|--major] [--codex|--claude] [--transport ghostty-macos|tmux|terminal-macos|auto]" >&2
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
    --transport)
      shift
      [[ -n "${1:-}" ]] || { usage; exit 2; }
      INSTALL_TRANSPORT="$1"
      ;;
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
UNAME="/usr/bin/uname"

valid_transport() {
  case "$1" in
    ghostty-macos|tmux|terminal-macos|auto) return 0 ;;
    *) return 1 ;;
  esac
}

detect_os() {
  case "$("$UNAME" -s 2>/dev/null || print unknown)" in
    Darwin) print -r -- "macos" ;;
    Linux)
      if [[ -n "${WSL_DISTRO_NAME:-}" || -n "${WSL_INTEROP:-}" ]]; then
        print -r -- "wsl"
      else
        print -r -- "linux"
      fi
      ;;
    CYGWIN*|MINGW*|MSYS*) print -r -- "windows" ;;
    *) print -r -- "unknown" ;;
  esac
}

supported_transports() {
  local os="$1"
  local choices=()
  case "$os" in
    macos)
      [[ "${TERM_PROGRAM:-}" == "ghostty" || -n "${GHOSTTY_RESOURCES_DIR:-}" || -d "/Applications/Ghostty.app" || -d "$HOME/Applications/Ghostty.app" ]] && choices+=("ghostty-macos")
      choices+=("terminal-macos")
      command -v tmux >/dev/null 2>&1 && choices+=("tmux")
      ;;
    linux|wsl)
      command -v tmux >/dev/null 2>&1 && choices+=("tmux")
      ;;
    *)
      ;;
  esac
  print -r -- "${(j: :)choices}"
}

choose_transport() {
  local os choices choice index
  os="$(detect_os)"
  choices=("${(@s: :)$(supported_transports "$os")}")

  if [[ -n "$INSTALL_TRANSPORT" ]]; then
    valid_transport "$INSTALL_TRANSPORT" || {
      print -r -- "Unsupported ADL transport: $INSTALL_TRANSPORT" >&2
      usage
      exit 2
    }
    print -r -- "$INSTALL_TRANSPORT"
    return
  fi

  if (( ${#choices[@]} == 0 )); then
    print -r -- "No supported ADL transport detected for $os. Re-run with --transport ghostty-macos, --transport tmux, or --transport terminal-macos if you know the adapter is available." >&2
    exit 6
  fi

  if (( ${#choices[@]} == 1 )); then
    print -r -- "$choices[1]"
    return
  fi

  if [[ ! -t 0 ]]; then
    print -r -- "Multiple ADL transports are supported for $os: ${(j:, :)choices}. Re-run with --transport <adapter> or ADL_INSTALL_TRANSPORT=<adapter>." >&2
    exit 6
  fi

  print -r -- "Select ADL transport for $os:" >&2
  for index in {1..${#choices[@]}}; do
    print -r -- "  $index) $choices[$index]" >&2
  done
  printf "Transport [1-%d]: " "${#choices[@]}" >&2
  read -r choice
  [[ "$choice" == <-> && "$choice" -ge 1 && "$choice" -le "${#choices[@]}" ]] || {
    print -r -- "Invalid transport choice: $choice" >&2
    exit 6
  }
  print -r -- "$choices[$choice]"
}

SELECTED_TRANSPORT="$(choose_transport)"

require_file() {
  [[ -f "$1" ]] || {
    print -r -- "Missing required source file: $1" >&2
    exit 4
  }
}

require_file "$ROOT/scripts/adl"
require_file "$ROOT/scripts/adl-clear"
require_file "$ROOT/scripts/ghostty-macos"
require_file "$ROOT/scripts/tmux"
require_file "$ROOT/scripts/terminal-macos"

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
  local config="$adl_target/.adl-config"

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
  "$CP" "$ROOT/scripts/tmux" "$adl_target/scripts/tmux"
  "$CP" "$ROOT/scripts/terminal-macos" "$adl_target/scripts/terminal-macos"
  "$CHMOD" +x "$adl_target/scripts/adl" "$adl_target/scripts/ghostty-macos" "$adl_target/scripts/tmux" "$adl_target/scripts/terminal-macos"
  "$CHMOD" +x "$clear_target/scripts/adl-clear"

  {
    print -r -- "ADL_VERSION='$VERSION'"
    print -r -- "ADL_SOURCE='$ROOT'"
  } > "$marker"

  {
    print -r -- "ADL_TRANSPORT='$SELECTED_TRANSPORT'"
  } > "$config"

  print -r -- "Installed $runtime_label $VERSION into $skills_dir"
  print -r -- "Configured ADL transport for $runtime: $SELECTED_TRANSPORT"
}

case "$TARGET_RUNTIME" in
  codex) install_runtime codex ;;
  claude) install_runtime claude ;;
  all)
    install_runtime codex
    install_runtime claude
    ;;
esac
