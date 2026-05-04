#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/tests/assert.sh"

TMP="$(new_tmpdir)"
trap 'rm -rf "$TMP"' EXIT
cd "$TMP"

export ADL_GHOSTTY_DRY_RUN=1
export ADL_SCRIPT_ROOT="$ROOT/scripts"

start="$("$ROOT/scripts/adl" architect start)"
assert_contains "$start" "ADL session ready" "start should report session"
assert_dir_exists ".adl/sessions"
assert_file_exists ".adl/active-session"

session_id="$(cat .adl/active-session)"
assert_file_exists ".adl/sessions/$session_id/session.env"
assert_contains "$(cat ".adl/sessions/$session_id/session.env")" "ADL_ARCHITECT_TERMINAL_ID='dry-run-architect-terminal'" "architect start should store adapter capture output"
pin="$(grep "^ADL_PIN=" ".adl/sessions/$session_id/session.env" | sed "s/ADL_PIN='//;s/'$//")"

again="$("$ROOT/scripts/adl" architect start)"
assert_contains "$again" "Resumed ADL session" "second start should resume"
assert_eq "$session_id" "$(cat .adl/active-session)" "active session should be reused"

mkdir -p .adl/tmp
print -r -- "Implement task A" > .adl/tmp/prompt.md
send_before="$("$ROOT/scripts/adl" architect send-dev --prompt-file .adl/tmp/prompt.md)"
assert_contains "$send_before" "Dev is not connected" "send before connect should be pending"
assert_file_exists ".adl/sessions/$session_id/runs/001/dev-prompt.md"
assert_eq "Implement task A" "$(cat .adl/sessions/$session_id/runs/001/dev-prompt.md)" "prompt should be copied"

connect="$("$ROOT/scripts/adl" dev connect "$pin")"
assert_contains "$connect" "Connected to ADL session" "dev connect should succeed"
assert_file_exists ".adl/sessions/$session_id/dev-brief.md"
assert_contains "$(cat ".adl/sessions/$session_id/session.env")" "ADL_DEV_TERMINAL_ID='dry-run-dev-terminal'" "dev connect should store adapter capture output"

set +e
notify_missing="$("$ROOT/scripts/adl" dev notify 2>&1)"
notify_code="$?"
set -e
assert_eq "1" "$notify_code" "notify without report should fail"
assert_contains "$notify_missing" "Missing" "notify should name missing report"

cat > ".adl/sessions/$session_id/runs/001/dev-report.md" <<'REPORT'
# Dev Report

Status: DONE

## Files Changed
None

## Verification
Not run

## Deviations
None

## Blockers Or Assumptions
None

## Notes
Test report
REPORT

notify="$("$ROOT/scripts/adl" dev notify)"
assert_contains "$notify" "Developer's Report sent" "notify should wake architect"

awk "{ if (\$0 ~ /^ADL_DEV_TERMINAL_ID=/) print \"ADL_DEV_TERMINAL_ID='stale-dev-terminal'\"; else print }" ".adl/sessions/$session_id/session.env" > ".adl/sessions/$session_id/session.env.tmp"
mv ".adl/sessions/$session_id/session.env.tmp" ".adl/sessions/$session_id/session.env"
stale_connect="$("$ROOT/scripts/adl" dev connect "$pin")"
assert_contains "$stale_connect" "Connected to ADL session" "dev connect should replace stale metadata after reported run"
assert_contains "$(cat ".adl/sessions/$session_id/session.env")" "ADL_DEV_TERMINAL_ID='dry-run-dev-terminal'" "stale dev metadata should be replaced by current capture"

mkdir -p .adl/tmp
print -r -- "Implement task B" > .adl/tmp/prompt2.md
"$ROOT/scripts/adl" architect send-dev --prompt-file .adl/tmp/prompt2.md >/dev/null
set +e
inflight_connect="$("$ROOT/scripts/adl" dev connect "$pin" 2>&1)"
inflight_code="$?"
set -e
assert_eq "1" "$inflight_code" "plain dev connect should not steal an in-flight run"
assert_contains "$inflight_connect" "Dev already connected for active run" "in-flight connect rejection should explain replacement path"
print -r -- "Implement task C" > .adl/tmp/prompt3.md
supersede="$("$ROOT/scripts/adl" architect send-dev --prompt-file .adl/tmp/prompt3.md)"
assert_contains "$supersede" "superseded" "new active run should supersede previous pending run"
assert_file_exists ".adl/sessions/$session_id/runs/003/dev-prompt.md"

cat > ".adl/sessions/$session_id/runs/002/dev-report.md" <<'REPORT'
# Dev Report

Status: DONE

## Files Changed
None

## Verification
Not run

## Deviations
None

## Blockers Or Assumptions
None

## Notes
Superseded report
REPORT

awk "{ if (\$0 ~ /^ADL_ACTIVE_RUN=/) print \"ADL_ACTIVE_RUN='002'\"; else print }" ".adl/sessions/$session_id/session.env" > ".adl/sessions/$session_id/session.env.tmp"
mv ".adl/sessions/$session_id/session.env.tmp" ".adl/sessions/$session_id/session.env"
set +e
superseded_notify="$("$ROOT/scripts/adl" dev notify 2>&1)"
superseded_code="$?"
set -e
assert_eq "1" "$superseded_code" "notify should reject superseded run"
assert_contains "$superseded_notify" "superseded run" "notify should explain superseded rejection"
awk "{ if (\$0 ~ /^ADL_ACTIVE_RUN=/) print \"ADL_ACTIVE_RUN='003'\"; else print }" ".adl/sessions/$session_id/session.env" > ".adl/sessions/$session_id/session.env.tmp"
mv ".adl/sessions/$session_id/session.env.tmp" ".adl/sessions/$session_id/session.env"

status_output="$("$ROOT/scripts/adl" status)"
assert_contains "$status_output" "Active run: 003" "status should show latest run"

print -r -- "ADL_EVIL='x'" >> ".adl/sessions/$session_id/session.env"
set +e
unsafe_status="$("$ROOT/scripts/adl" status 2>&1)"
unsafe_code="$?"
set -e
assert_eq "2" "$unsafe_code" "unknown env key should be rejected as state corruption"
assert_contains "$unsafe_status" "Unknown ADL env key" "unsafe env should explain key rejection"
grep -v "^ADL_EVIL=" ".adl/sessions/$session_id/session.env" > ".adl/sessions/$session_id/session.env.tmp"
mv ".adl/sessions/$session_id/session.env.tmp" ".adl/sessions/$session_id/session.env"

new_session="$("$ROOT/scripts/adl" architect start --new)"
assert_contains "$new_session" "ADL session ready" "new should create session"
assert_contains "$(cat ".adl/sessions/$session_id/session.env")" "ADL_STATUS='closed'" "old session should be closed"
