#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/tests/assert.sh"

TMP="$(new_tmpdir)"
trap 'rm -rf "$TMP"' EXIT

TEAM_A="$TMP/team-a-todo"
TEAM_B="$TMP/team-b-repo"
ROUTING="$TMP/routing"
mkdir -p "$TEAM_A" "$TEAM_B" "$ROUTING"
TEAM_A="${TEAM_A:A}"
TEAM_B="${TEAM_B:A}"

export ADL_GHOSTTY_DRY_RUN=1
export COMMISSION_SCRIPT_ROOT="$ROOT/scripts"
export COMMISSION_ROUTING_DIR="$ROUTING"

write_request() {
  local path="$1"
  /bin/cat > "$path" <<REQUEST
Goal: Add checklist support to Team A todo app
Target repo: $TEAM_A
Slice: Add the minimal checklist model
Approved context: Team B is only the Consumer entry point.
Acceptance criteria:
- Consumer target repo is Team A.
- Team B entry cwd does not receive protocol truth state.
In scope: Commission fixture state.
Out of scope: Real app edits.
Expected evidence: CLI output and run.env state.
REQUEST
}

write_report() {
  local path="$1"
  /bin/cat > "$path" <<'REPORT'
# Consumer Report

Status: DONE
Goal: Add checklist support to Team A todo app
Slice: Add the minimal checklist model

## Acceptance Results
- Consumer target repo is Team A. PASS - CLI output showed Team A.

## Files Changed

## Verification
- Command: commission consumer notify
- Result: passed

## Deviations

## Residual Risks
REPORT
}

cd "$TEAM_A"
start="$("$ROOT/scripts/commission" commissioner start)"
pin="$(print -r -- "$start" | /usr/bin/awk '/^Pin: / { print $2 }')"
session_id="$(/bin/cat .commission/active-session)"

assert_contains "$start" "Commission session ready" "commissioner start should report session"
assert_contains "$start" "In Consumer, invoke: \$commission-connect" "start should print connect command"
assert_contains "$(/bin/cat ".commission/sessions/$session_id/session.env")" "COMMISSION_TARGET_REPO='$TEAM_A'" "session should record Team A target repo"

mkdir -p .commission/staging
write_request .commission/staging/request.md
queued="$("$ROOT/scripts/commission" commissioner send-consumer --prompt-file .commission/staging/request.md)"
assert_contains "$queued" "Consumer is not connected" "request should queue before Consumer connects"

cd "$TEAM_B"
mkdir -p .commission
print -r -- "stale unrelated state" > .commission/unrelated
connect="$("$ROOT/scripts/commission" consumer connect "$pin")"

assert_contains "$connect" "Target repo: $TEAM_A" "Consumer connect should print Team A target repo"
assert_contains "$connect" "Pending Commissioner's Request: $TEAM_A/.commission/sessions/$session_id/runs/001/consumer-prompt.md" "pending prompt should be in Team A"
assert_contains "$connect" "Write Consumer report: $TEAM_A/.commission/sessions/$session_id/runs/001/consumer-report.md" "report path should be in Team A"
assert_file_exists "$TEAM_B/.commission/unrelated"
[[ ! -f "$TEAM_B/.commission/active-session" ]] || fail "Team B should not receive Commission protocol truth"
assert_not_contains "$(/bin/cat "$ROUTING/pins/$pin.env")" "Add checklist support" "pin route should not contain request body content"

write_report "$TEAM_A/.commission/sessions/$session_id/runs/001/consumer-report.md"
notify_from_b="$("$ROOT/scripts/commission" consumer notify)"
assert_contains "$notify_from_b" "Consumer's Report sent." "notify should work from Consumer entry cwd"
assert_contains "$(/bin/cat "$TEAM_A/.commission/sessions/$session_id/runs/001/run.env")" "COMMISSION_RUN_STATUS='reported'" "notify should update Team A run state"

cd "$TEAM_A"
notify_from_a="$("$ROOT/scripts/commission" consumer notify)"
assert_contains "$notify_from_a" "Consumer's Report sent." "notify should work from target repo"
