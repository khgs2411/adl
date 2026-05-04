#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h}"
VERSION="0.2.0"
SKILLS_DIR="${ADL_CODEX_SKILLS_DIR:-/Users/liadgoren/.codex/skills}"
ADL_TARGET="$SKILLS_DIR/adl"
CONNECT_TARGET="$SKILLS_DIR/adl-connect"
BACKUP_ROOT="$SKILLS_DIR/.adl-project-backups"
MARKER="$ADL_TARGET/.adl-framework"
CP="/bin/cp"
CHMOD="/bin/chmod"
DATE="/bin/date"
MKDIR="/bin/mkdir"
RM="/bin/rm"

require_file() {
  [[ -f "$1" ]] || {
    print -r -- "Missing required source file: $1" >&2
    exit 4
  }
}

require_file "$ROOT/skills/adl/SKILL.md"
require_file "$ROOT/skills/adl-connect/SKILL.md"
require_file "$ROOT/scripts/adl"
require_file "$ROOT/scripts/ghostty-macos"

"$MKDIR" -p "$SKILLS_DIR"

if [[ -d "$ADL_TARGET" && ! -f "$MARKER" ]]; then
  ts="$("$DATE" +%Y%m%d-%H%M%S)"
  backup="$BACKUP_ROOT/$ts/adl"
  "$MKDIR" -p "$backup:h"
  "$CP" -R "$ADL_TARGET" "$backup"
  print -r -- "Backed up existing adl skill to: $backup"
  print -r -- "Rollback: \"$RM\" -rf '$ADL_TARGET' && \"$CP\" -R '$backup' '$ADL_TARGET'"
fi

"$RM" -rf "$ADL_TARGET" "$CONNECT_TARGET"
"$MKDIR" -p "$ADL_TARGET/scripts" "$CONNECT_TARGET"

"$CP" "$ROOT/skills/adl/SKILL.md" "$ADL_TARGET/SKILL.md"
"$CP" "$ROOT/skills/adl-connect/SKILL.md" "$CONNECT_TARGET/SKILL.md"
"$CP" "$ROOT/scripts/adl" "$ADL_TARGET/scripts/adl"
"$CP" "$ROOT/scripts/ghostty-macos" "$ADL_TARGET/scripts/ghostty-macos"
"$CHMOD" +x "$ADL_TARGET/scripts/adl" "$ADL_TARGET/scripts/ghostty-macos"

{
  print -r -- "ADL_VERSION='$VERSION'"
  print -r -- "ADL_SOURCE='$ROOT'"
} > "$MARKER"

print -r -- "Installed ADL framework $VERSION into $SKILLS_DIR"
