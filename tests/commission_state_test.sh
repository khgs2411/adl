#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/tests/assert.sh"

TMP="$(new_tmpdir)"
trap 'rm -rf "$TMP"' EXIT

COMMISSIONER="$TMP/commissioner"
CONSUMER="$TMP/consumer"
ROUTING="$TMP/routing"
mkdir -p "$COMMISSIONER" "$CONSUMER" "$ROUTING"
COMMISSIONER="${COMMISSIONER:A}"
CONSUMER="${CONSUMER:A}"
ROUTING="${ROUTING:A}"

export ADL_GHOSTTY_DRY_RUN=1
export COMMISSION_SCRIPT_ROOT="$ROOT/scripts"
export COMMISSION_ROUTING_DIR="$ROUTING"

write_request() {
  local path="$1"
  /bin/cat > "$path" <<'REQUEST'
Goal: Test Commission cross-repo routing
Slice: Consumer completes one request
Approved context: Test fixture only.
Acceptance criteria:
- Report stays in the Commissioner's local state tree.
In scope: Commission fixture state.
Out of scope: Real repo edits.
Expected evidence: CLI output and run.env state.
REQUEST
}

write_report() {
  local path="$1"
  /bin/cat > "$path" <<REPORT
# Consumer Report

Status: DONE
Goal: Test Commission cross-repo routing
Slice: Consumer completes one request

## Acceptance Results
- Report stays in the Commissioner's local state tree. PASS - report written to $COMMISSIONER.

## Files Changed
None

## Verification
- Command: fixture
- Result: PASS

## Deviations
None

## Residual Risks
None
REPORT
}

cd "$COMMISSIONER"
start="$("$ROOT/scripts/commission" commissioner start)"
assert_contains "$start" "Commission session ready" "commissioner start should report session"
assert_contains "$start" "In Consumer, invoke: \$commission-connect" "start should print Consumer connect command"
assert_dir_exists ".commission/sessions"
assert_file_exists ".commission/active-session"
assert_file_exists ".commission/commission.log"

session_id="$(cat .commission/active-session)"
pin="$(print -r -- "$start" | awk '/^Pin: / { print $2 }')"
assert_file_exists "$ROUTING/pins/$pin.env"
assert_contains "$(cat "$ROUTING/pins/$pin.env")" "COMMISSION_COMMISSIONER_CWD='$COMMISSIONER'" "pin index should route to Commissioner cwd"
assert_contains "$(cat ".commission/sessions/$session_id/session.env")" "COMMISSION_COMMISSIONER_CWD='$COMMISSIONER'" "session should record Commissioner cwd"

mkdir -p .commission/staging
write_request .commission/staging/request.md
queued="$("$ROOT/scripts/commission" commissioner send-consumer --prompt-file .commission/staging/request.md)"
assert_contains "$queued" "Consumer is not connected" "send before connect should queue request"
assert_file_exists ".commission/sessions/$session_id/runs/001/consumer-prompt.md"

cd "$CONSUMER"
connect="$("$ROOT/scripts/commission" consumer connect "$pin")"
assert_contains "$connect" "Connected to Commission session" "Consumer should connect from a different cwd"
pending_prompt="$(print -r -- "$connect" | awk -F": " '/^Pending Commissioner'\''s Request: / { print $2 }')"
report_path="$(print -r -- "$connect" | awk -F": " '/^Write Consumer report: / { print $2 }')"
assert_eq "$COMMISSIONER/.commission/sessions/$session_id/runs/001/consumer-prompt.md" "$pending_prompt" "connect should print an absolute pending request path"
assert_eq "$COMMISSIONER/.commission/sessions/$session_id/runs/001/consumer-report.md" "$report_path" "connect should print an absolute report path"
assert_file_exists "$pending_prompt"
assert_file_exists "$ROUTING/consumers/$(print -r -- "$CONSUMER" | /usr/bin/cksum | awk '{ print $1 }').env"
assert_contains "$(cat "$COMMISSIONER/.commission/sessions/$session_id/session.env")" "COMMISSION_CONSUMER_CWD='$CONSUMER'" "session should record Consumer cwd"
[[ ! -e "$CONSUMER/.commission" ]] || fail "Consumer repo should not receive protocol truth state"

write_report "$report_path"
notify="$("$ROOT/scripts/commission" consumer notify)"
assert_contains "$notify" "Consumer's Report sent" "notify should resolve route from Consumer cwd"
assert_contains "$(cat "$COMMISSIONER/.commission/sessions/$session_id/runs/001/run.env")" "COMMISSION_RUN_STATUS='reported'" "notify should mark Commissioner-local run reported"

cd "$COMMISSIONER"
clear="$("$ROOT/scripts/commission-clear" "$PWD/.commission")"
assert_contains "$clear" "Cleared Commission state" "commission-clear should clear local state"
[[ ! -e "$COMMISSIONER/.commission" ]] || fail "commission-clear should remove Commissioner .commission"
remaining_routes="$(find "$ROUTING" -type f | wc -l | tr -d ' ')"
assert_eq "0" "$remaining_routes" "commission-clear should remove matching routing entries"
