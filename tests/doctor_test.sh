#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/tests/assert.sh"

TMP="$(new_tmpdir)"
trap 'rm -rf "$TMP"' EXIT
cd "$TMP"
WORKDIR="$PWD"

export ADL_GHOSTTY_DRY_RUN=1
export ADL_SCRIPT_ROOT="$ROOT/scripts"
export ADL_CODEX_SKILLS_DIR="$TMP/skills"
expected_cli_version="$(grep '^VERSION=' "$ROOT/scripts/adl" | sed 's/VERSION="//;s/"//')"

mkdir -p "$ADL_CODEX_SKILLS_DIR/adl"
/bin/cat > "$ADL_CODEX_SKILLS_DIR/adl/.adl-framework" <<MARKER
ADL_VERSION='9.9.9'
ADL_SOURCE='$ROOT'
MARKER

empty_doctor="$("$ROOT/scripts/adl" doctor)"
assert_contains "$empty_doctor" "cli.version: $expected_cli_version" "doctor should print CLI version"
assert_contains "$empty_doctor" "log.enabled: 1" "doctor should print log enabled state"
assert_contains "$empty_doctor" "log.path: $WORKDIR/.adl/adl.log" "doctor should print log path"
assert_contains "$empty_doctor" "adl.dir: missing" "doctor should report missing .adl"
assert_contains "$empty_doctor" "session.id: absent" "doctor should report absent session"
assert_contains "$empty_doctor" "global.marker: present ($ADL_CODEX_SKILLS_DIR/adl/.adl-framework)" "doctor should report marker path"
assert_contains "$empty_doctor" "global.version: 9.9.9" "doctor should report installed version"
assert_contains "$empty_doctor" "ghostty.adapter: executable ($ROOT/scripts/ghostty-macos)" "doctor should report adapter executable"

start="$("$ROOT/scripts/adl" architect start)"
assert_contains "$start" "ADL session ready" "start should create a dry-run session"
session_id="$(cat .adl/active-session)"
pin="$(grep "^ADL_PIN=" ".adl/sessions/$session_id/session.env" | sed "s/ADL_PIN='//;s/'$//")"

mkdir -p .adl/staging
/bin/cat > .adl/staging/prompt.md <<'PROMPT'
Goal: Doctor test
Slice: Create pending doctor run
Approved context: Test fixture only.
Acceptance criteria:
- Doctor reports active run.
In scope: ADL state.
Out of scope: Real terminal automation.
Expected evidence: doctor output.
PROMPT
"$ROOT/scripts/adl" architect send-dev --prompt-file .adl/staging/prompt.md >/dev/null
"$ROOT/scripts/adl" dev connect "$pin" >/dev/null

active_doctor="$("$ROOT/scripts/adl" doctor)"
assert_contains "$active_doctor" "adl.dir: present ($WORKDIR/.adl)" "doctor should report .adl path"
assert_contains "$active_doctor" "session.id: $session_id" "doctor should report active session"
assert_contains "$active_doctor" "session.pin: $pin" "doctor should report pin"
assert_contains "$active_doctor" "session.status: pending_dev_connection" "doctor should report session status"
assert_contains "$active_doctor" "run.id: 001" "doctor should report active run"
assert_contains "$active_doctor" "run.status: pending_dev_connection" "doctor should report run status"
assert_contains "$active_doctor" "transport.architect: present (ghostty-macos)" "doctor should report architect transport"
assert_contains "$active_doctor" "transport.dev: present (ghostty-macos)" "doctor should report dev transport"

awk "{ if (\$0 ~ /^ADL_ARCHITECT_TERMINAL_ID=/) print \"ADL_ARCHITECT_TERMINAL_ID='dry-run-dev-terminal'\"; else print }" ".adl/sessions/$session_id/session.env" > ".adl/sessions/$session_id/session.env.tmp"
mv ".adl/sessions/$session_id/session.env.tmp" ".adl/sessions/$session_id/session.env"
collision_doctor="$("$ROOT/scripts/adl" doctor)"
assert_contains "$collision_doctor" "transport.warning: architect and dev terminal ids match; run \$adl refresh in the Architect pane" "doctor should point collision recovery at refresh"
assert_contains "$collision_doctor" "next: run \$adl refresh in Architect pane" "doctor should print refresh next step for colliding transport"

ghostty_arch="$("$ROOT/scripts/adl" doctor ghostty architect)"
assert_contains "$ghostty_arch" "ADL doctor ghostty" "ghostty doctor should print heading"
assert_contains "$ghostty_arch" "role: architect" "ghostty doctor should report role"
assert_contains "$ghostty_arch" "dry_run: 1" "ghostty doctor should expose dry run"
assert_contains "$ghostty_arch" "capture: ok" "ghostty doctor dry-run should capture"
assert_contains "$ghostty_arch" "ADL_ARCHITECT_TERMINAL_ID='dry-run-architect-terminal'" "ghostty doctor should include capture output"

ghostty_dev="$("$ROOT/scripts/adl" doctor ghostty dev)"
assert_contains "$ghostty_dev" "ADL_DEV_TERMINAL_ID='dry-run-dev-terminal'" "ghostty doctor should include dev capture output"
