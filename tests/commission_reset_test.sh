#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/tests/assert.sh"

TMP="$(new_tmpdir)"
trap 'rm -rf "$TMP"' EXIT

TEAM_A="$TMP/team-a"
TEAM_B="$TMP/team-b"
ROUTING="$TMP/routing"
mkdir -p "$TEAM_A" "$TEAM_B" "$ROUTING"

export ADL_GHOSTTY_DRY_RUN=1
export COMMISSION_SCRIPT_ROOT="$ROOT/scripts"
export COMMISSION_ROUTING_DIR="$ROUTING"

cd "$TEAM_A"
start="$("$ROOT/scripts/commission" commissioner start)"
pin="$(print -r -- "$start" | /usr/bin/awk '/^Pin: / { print $2 }')"

cd "$TEAM_B"
"$ROOT/scripts/commission" consumer connect "$pin" >/dev/null
consumer_key="$(print -r -- "${TEAM_B:A}" | /usr/bin/cksum | /usr/bin/awk '{ print $1 }')"
assert_file_exists "$ROUTING/pins/$pin.env"
assert_file_exists "$ROUTING/consumers/$consumer_key.env"

cd "$TEAM_A"
reset="$("$ROOT/scripts/commission-reset" "$PWD/.commission")"
assert_contains "$reset" "Reset Commission state" "reset should remove local Commission state"
[[ ! -e "$TEAM_A/.commission" ]] || fail "reset should remove Team A .commission"
[[ ! -f "$ROUTING/pins/$pin.env" ]] || fail "reset should remove matching pin route"
[[ ! -f "$ROUTING/consumers/$consumer_key.env" ]] || fail "reset should remove matching consumer route"
