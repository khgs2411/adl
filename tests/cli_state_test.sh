#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/tests/assert.sh"

TMP="$(new_tmpdir)"
trap 'rm -rf "$TMP"' EXIT
cd "$TMP"

export ADL_GHOSTTY_DRY_RUN=1
export ADL_SCRIPT_ROOT="$ROOT/scripts"

write_dev_prompt() {
  local path="$1" slice="$2"
  /bin/cat > "$path" <<PROMPT
Goal: Test ADL quality gate
Slice: $slice
Approved context: Use the test fixture only.
Acceptance criteria:
- Prompt and report preserve goal/slice context.
In scope: Test fixture state changes.
Out of scope: Real repo edits.
Expected evidence: CLI output and run.env state.
PROMPT
}

write_dev_report() {
  local path="$1" slice="$2"
  /bin/cat > "$path" <<REPORT
# Dev Report

Status: DONE
Goal: Test ADL quality gate
Slice: $slice

## Acceptance Results
- Prompt and report preserve goal/slice context. PASS - fixture written.

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

start="$("$ROOT/scripts/adl" architect start)"
assert_contains "$start" "ADL session ready" "start should report session"
assert_dir_exists ".adl/sessions"
assert_file_exists ".adl/active-session"
assert_file_exists ".adl/adl.log"
assert_contains "$(cat .adl/adl.log)" "event=architect.start mode=new" "architect start should write log entry"

session_id="$(cat .adl/active-session)"
assert_file_exists ".adl/sessions/$session_id/session.env"
assert_contains "$(cat ".adl/sessions/$session_id/session.env")" "ADL_ARCHITECT_TERMINAL_ID='dry-run-architect-terminal'" "architect start should store adapter capture output"
pin="$(grep "^ADL_PIN=" ".adl/sessions/$session_id/session.env" | sed "s/ADL_PIN='//;s/'$//")"

awk "{ if (\$0 ~ /^ADL_ARCHITECT_TERMINAL_ID=/) print \"ADL_ARCHITECT_TERMINAL_ID='stale-architect-terminal'\"; else print }" ".adl/sessions/$session_id/session.env" > ".adl/sessions/$session_id/session.env.tmp"
mv ".adl/sessions/$session_id/session.env.tmp" ".adl/sessions/$session_id/session.env"
again="$("$ROOT/scripts/adl" architect start)"
assert_contains "$again" "ADL session ready" "second start should create a fresh session"
assert_contains "$(cat ".adl/sessions/$session_id/session.env")" "ADL_STATUS='closed'" "second start should close previous active session"
assert_not_contains "$(cat .adl/active-session)" "$session_id" "active session should move to fresh session"

session_id="$(cat .adl/active-session)"
pin="$(grep "^ADL_PIN=" ".adl/sessions/$session_id/session.env" | sed "s/ADL_PIN='//;s/'$//")"
awk "{ if (\$0 ~ /^ADL_ARCHITECT_TERMINAL_ID=/) print \"ADL_ARCHITECT_TERMINAL_ID='stale-architect-terminal'\"; else print }" ".adl/sessions/$session_id/session.env" > ".adl/sessions/$session_id/session.env.tmp"
mv ".adl/sessions/$session_id/session.env.tmp" ".adl/sessions/$session_id/session.env"
resume="$("$ROOT/scripts/adl" architect resume)"
assert_contains "$resume" "Resumed ADL session" "architect resume should report resumed session"
assert_eq "$session_id" "$(cat .adl/active-session)" "architect resume should reuse active session"
assert_contains "$(cat ".adl/sessions/$session_id/session.env")" "ADL_ARCHITECT_TERMINAL_ID='stale-architect-terminal'" "architect resume should preserve existing transport"

refresh="$("$ROOT/scripts/adl" architect refresh)"
assert_contains "$refresh" "Refreshed Architect transport" "architect refresh should report refreshed transport"
assert_contains "$(cat ".adl/sessions/$session_id/session.env")" "ADL_ARCHITECT_TERMINAL_ID='dry-run-architect-terminal'" "architect refresh should refresh adapter capture output"

mkdir -p .adl/staging
print -r -- "Implement task A" > .adl/staging/bad-prompt.md
set +e
bad_prompt_output="$("$ROOT/scripts/adl" architect send-dev --prompt-file .adl/staging/bad-prompt.md 2>&1)"
bad_prompt_code="$?"
set -e
assert_eq "1" "$bad_prompt_code" "send-dev should reject prompts without required quality sections"
assert_contains "$bad_prompt_output" "Invalid Dev prompt" "bad prompt rejection should explain required sections"
write_dev_prompt .adl/staging/prompt.md "Implement task A"
status_before_connect="$("$ROOT/scripts/adl" status)"
assert_contains "$status_before_connect" "Dev: not connected" "status should clearly expose missing dev connection"
send_before="$("$ROOT/scripts/adl" architect send-dev --prompt-file .adl/staging/prompt.md)"
assert_contains "$send_before" "Dev is not connected" "send before connect should be pending"
assert_file_exists ".adl/sessions/$session_id/runs/001/dev-prompt.md"
assert_contains "$(cat .adl/sessions/$session_id/runs/001/dev-prompt.md)" "Slice: Implement task A" "prompt should be copied"
status_after_queued="$("$ROOT/scripts/adl" status)"
assert_contains "$status_after_queued" "Next: Connect Dev with \$adl-connect $pin." "queued prompt without dev should still tell Architect to connect Dev"

connect="$("$ROOT/scripts/adl" dev connect "$pin")"
assert_contains "$connect" "Connected to ADL session" "dev connect should succeed"
assert_contains "$connect" "Architect notified: Dev connected and ready." "dev connect should wake architect after successful connection"
assert_contains "$connect" "Pending Architect's Request:" "dev connect should surface queued pending prompt"
assert_file_exists ".adl/sessions/$session_id/dev-brief.md"
assert_contains "$(cat ".adl/sessions/$session_id/dev-brief.md")" "$ROOT/scripts/adl dev notify" "dev brief should use the active CLI path"
assert_contains "$(cat ".adl/sessions/$session_id/session.env")" "ADL_DEV_TERMINAL_ID='dry-run-dev-terminal'" "dev connect should store adapter capture output"
assert_contains "$(cat .adl/adl.log)" "event=dev.connect_notify" "dev connect should log architect wake"

set +e
bad_arch_refresh="$(ADL_GHOSTTY_DRY_RUN_TERMINAL_ID=dry-run-dev-terminal "$ROOT/scripts/adl" architect refresh 2>&1)"
bad_arch_refresh_code="$?"
set -e
assert_eq "3" "$bad_arch_refresh_code" "architect refresh should reject capture collision with dev"
assert_contains "$bad_arch_refresh" "Captured Architect transport matches Dev transport. Focus the Architect Ghostty pane and rerun \$adl refresh." "architect refresh collision should explain focused pane issue"
assert_contains "$(cat ".adl/sessions/$session_id/session.env")" "ADL_ARCHITECT_TERMINAL_ID='dry-run-architect-terminal'" "failed architect refresh should not overwrite architect transport"
assert_contains "$(cat .adl/adl.log)" "event=architect.refresh refused_collision" "architect refresh collision should write log entry"

set +e
notify_missing="$("$ROOT/scripts/adl" dev notify 2>&1)"
notify_code="$?"
set -e
assert_eq "1" "$notify_code" "notify without report should fail"
assert_contains "$notify_missing" "Missing" "notify should name missing report"

/bin/cat > ".adl/sessions/$session_id/runs/001/dev-report.md" <<'REPORT'
# Dev Report

Status: DONE
REPORT
set +e
bad_report_notify="$("$ROOT/scripts/adl" dev notify 2>&1)"
bad_report_code="$?"
set -e
assert_eq "1" "$bad_report_code" "notify should reject reports without acceptance sections"
assert_contains "$bad_report_notify" "Invalid Dev report" "bad report rejection should explain missing acceptance sections"
write_dev_report ".adl/sessions/$session_id/runs/001/dev-report.md" "Implement task A"

awk "{ if (\$0 ~ /^ADL_ARCHITECT_TERMINAL_ID=/) print \"ADL_ARCHITECT_TERMINAL_ID='dry-run-dev-terminal'\"; else print }" ".adl/sessions/$session_id/session.env" > ".adl/sessions/$session_id/session.env.tmp"
mv ".adl/sessions/$session_id/session.env.tmp" ".adl/sessions/$session_id/session.env"
set +e
self_notify="$("$ROOT/scripts/adl" dev notify 2>&1)"
self_notify_code="$?"
set -e
assert_eq "3" "$self_notify_code" "notify should reject architect/dev transport collision"
assert_contains "$self_notify" "Architect transport is missing or invalid. Ask Architect to run \$adl refresh, then retry notify." "notify collision should ask Dev to request Architect refresh"
assert_contains "$(cat ".adl/sessions/$session_id/runs/001/run.env")" "ADL_RUN_STATUS='pending_dev_connection'" "failed notify should not mark run reported"
awk "{ if (\$0 ~ /^ADL_ARCHITECT_TERMINAL_ID=/) print \"ADL_ARCHITECT_TERMINAL_ID='dry-run-architect-terminal'\"; else print }" ".adl/sessions/$session_id/session.env" > ".adl/sessions/$session_id/session.env.tmp"
mv ".adl/sessions/$session_id/session.env.tmp" ".adl/sessions/$session_id/session.env"

FAILING_ADAPTER_DIR="$TMP/failing-adapter"
mkdir -p "$FAILING_ADAPTER_DIR"
/bin/cat > "$FAILING_ADAPTER_DIR/ghostty-macos" <<'ADAPTER'
#!/bin/zsh
set -euo pipefail
case "${1:-}" in
  send)
    print -r -- "forced send failure" >&2
    exit 3
    ;;
  *)
    exec "$ADL_SCRIPT_ROOT/ghostty-macos" "$@"
    ;;
esac
ADAPTER
chmod +x "$FAILING_ADAPTER_DIR/ghostty-macos"
set +e
failed_send="$(ADL_SCRIPT_ROOT="$FAILING_ADAPTER_DIR" "$ROOT/scripts/adl" dev notify 2>&1)"
failed_send_code="$?"
set -e
assert_eq "3" "$failed_send_code" "notify should fail when Ghostty send fails"
assert_contains "$failed_send" "Failed to wake Architect" "notify send failure should explain refresh path"
assert_contains "$(cat ".adl/sessions/$session_id/runs/001/run.env")" "ADL_RUN_STATUS='pending_dev_connection'" "failed send should not mark run reported"

notify="$("$ROOT/scripts/adl" dev notify)"
assert_contains "$notify" "Developer's Report sent" "notify should wake architect"
assert_contains "$(cat .adl/adl.log)" "event=dev.notify" "dev notify should write log entry"
assert_contains "$(cat ".adl/sessions/$session_id/runs/001/run.env")" "ADL_RUN_STATUS='reported'" "successful notify should mark run reported"

awk "{ if (\$0 ~ /^ADL_DEV_TERMINAL_ID=/) print \"ADL_DEV_TERMINAL_ID='stale-dev-terminal'\"; else print }" ".adl/sessions/$session_id/session.env" > ".adl/sessions/$session_id/session.env.tmp"
mv ".adl/sessions/$session_id/session.env.tmp" ".adl/sessions/$session_id/session.env"
stale_connect="$("$ROOT/scripts/adl" dev connect "$pin")"
assert_contains "$stale_connect" "Connected to ADL session" "dev connect should replace stale metadata after reported run"
assert_not_contains "$stale_connect" "Pending Architect's Request" "dev connect after reported run should not present stale work as pending"
assert_contains "$(cat ".adl/sessions/$session_id/session.env")" "ADL_DEV_TERMINAL_ID='dry-run-dev-terminal'" "stale dev metadata should be replaced by current capture"

CONNECT_FAIL_ADAPTER_DIR="$TMP/connect-failing-adapter"
mkdir -p "$CONNECT_FAIL_ADAPTER_DIR"
/bin/cat > "$CONNECT_FAIL_ADAPTER_DIR/ghostty-macos" <<'ADAPTER'
#!/bin/zsh
set -euo pipefail
case "${1:-}" in
  send)
    print -r -- "forced connect notify failure" >&2
    exit 3
    ;;
  *)
    exec "__ROOT__/scripts/ghostty-macos" "$@"
    ;;
esac
ADAPTER
sed "s#__ROOT__#$ROOT#g" "$CONNECT_FAIL_ADAPTER_DIR/ghostty-macos" > "$CONNECT_FAIL_ADAPTER_DIR/ghostty-macos.tmp"
mv "$CONNECT_FAIL_ADAPTER_DIR/ghostty-macos.tmp" "$CONNECT_FAIL_ADAPTER_DIR/ghostty-macos"
chmod +x "$CONNECT_FAIL_ADAPTER_DIR/ghostty-macos"
set +e
failed_connect_notify="$(ADL_SCRIPT_ROOT="$CONNECT_FAIL_ADAPTER_DIR" "$ROOT/scripts/adl" dev connect "$pin" 2>&1)"
failed_connect_notify_code="$?"
set -e
assert_eq "3" "$failed_connect_notify_code" "dev connect should fail when architect wake fails"
assert_contains "$failed_connect_notify" "Failed to notify Architect that Dev connected. Ask Architect to run \$adl refresh, then retry \$adl-connect with --replace." "connect wake failure should explain recovery"
assert_contains "$(cat ".adl/sessions/$session_id/session.env")" "ADL_DEV_TERMINAL_ID='dry-run-dev-terminal'" "failed connect wake should still store dev metadata"

mkdir -p .adl/staging
write_dev_prompt .adl/staging/prompt2.md "Implement task B"
SEND_FAIL_ADAPTER_DIR="$TMP/send-failing-adapter"
mkdir -p "$SEND_FAIL_ADAPTER_DIR"
/bin/cat > "$SEND_FAIL_ADAPTER_DIR/ghostty-macos" <<'ADAPTER'
#!/bin/zsh
set -euo pipefail
case "${1:-}" in
  send)
    print -r -- "execution error: Can't get application \"Ghostty\". (-1728)" >&2
    exit 3
    ;;
  *)
    exec "__ROOT__/scripts/ghostty-macos" "$@"
    ;;
esac
ADAPTER
sed "s#__ROOT__#$ROOT#g" "$SEND_FAIL_ADAPTER_DIR/ghostty-macos" > "$SEND_FAIL_ADAPTER_DIR/ghostty-macos.tmp"
mv "$SEND_FAIL_ADAPTER_DIR/ghostty-macos.tmp" "$SEND_FAIL_ADAPTER_DIR/ghostty-macos"
chmod +x "$SEND_FAIL_ADAPTER_DIR/ghostty-macos"
set +e
failed_arch_send="$(ADL_SCRIPT_ROOT="$SEND_FAIL_ADAPTER_DIR" "$ROOT/scripts/adl" architect send-dev --prompt-file .adl/staging/prompt2.md 2>&1)"
failed_arch_send_code="$?"
set -e
assert_eq "3" "$failed_arch_send_code" "send-dev should fail when Dev wake fails"
assert_contains "$failed_arch_send" "Rerun the same send-dev command outside the sandbox" "sandboxed send failure should explain exact recovery path"
assert_contains "$(cat ".adl/sessions/$session_id/session.env")" "ADL_DEV_TERMINAL_ID='dry-run-dev-terminal'" "sandboxed send failure should preserve Dev transport"
status_after_failed_arch_send="$("$ROOT/scripts/adl" status)"
assert_contains "$status_after_failed_arch_send" "Dev: connected" "status should keep Dev connected after sandboxed send failure"
set +e
inflight_connect="$("$ROOT/scripts/adl" dev connect "$pin" 2>&1)"
inflight_code="$?"
set -e
assert_eq "1" "$inflight_code" "plain dev connect should not steal an in-flight run"
assert_contains "$inflight_connect" "Dev already connected for active run" "in-flight connect rejection should explain replacement path"
mkdir -p .adl/tmp
write_dev_prompt .adl/tmp/prompt3.md "Implement task C"
supersede="$("$ROOT/scripts/adl" architect send-dev --prompt-file .adl/tmp/prompt3.md)"
assert_contains "$supersede" "superseded" "new active run should supersede previous pending run"
assert_contains "$supersede" "accepted legacy staging path" "legacy .adl/tmp prompts should be accepted with a compatibility notice"
assert_file_exists ".adl/sessions/$session_id/runs/003/dev-prompt.md"
assert_contains "$(cat ".adl/sessions/$session_id/runs/002/run.env")" "ADL_SUPERSEDED_BY='003'" "superseded run should point at replacement run"

write_dev_report ".adl/sessions/$session_id/runs/002/dev-report.md" "Implement task B"

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
dev_status_output="$("$ROOT/scripts/adl" dev status)"
assert_contains "$dev_status_output" "Active run: 003" "dev status should alias top-level status"
assert_contains "$(cat .adl/adl.log)" "event=status" "status should write log entry"

mkdir -p .adl/staging
/bin/cat > .adl/staging/review.md <<'REVIEW'
Verdict: Pass this back to the Dev
Goal/Slice Reviewed: Test ADL quality gate / Implement task C
Approved Context Checked: Test fixture only
Evidence Checked: run.env
Acceptance Result: NOT VERIFIED - superseded fixture
Follow-up: Pass this back to the Dev
REVIEW
review_output="$("$ROOT/scripts/adl" architect review --verdict passed-back --review-file .adl/staging/review.md)"
assert_contains "$review_output" "Architect review recorded" "architect review should persist verdict"
assert_contains "$(cat ".adl/sessions/$session_id/runs/003/run.env")" "ADL_RUN_STATUS='passed_back'" "review should update durable run status"
assert_file_exists ".adl/sessions/$session_id/runs/003/architect-review.md"

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

NOLOG="$TMP/nolog"
mkdir -p "$NOLOG"
cd "$NOLOG"
ADL_LOG=0 "$ROOT/scripts/adl" architect start >/dev/null
[[ ! -f ".adl/adl.log" ]] || fail "ADL_LOG=0 should disable log file creation"
