# Commission Target Repository Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Commission protocol where a Consumer can start in another directory but must implement the Commissioner's request in the Commissioner's target repository.

**Architecture:** Add a separate `commission` CLI parallel to `adl`; `.commission/` lives in the Commissioner target repo, while `~/.commission/` stores only routing pointers. Consumer connect resolves the pin to the Commissioner root first, prints the target repo, and records Consumer entry cwd only for reconnect/notify routing.

**Tech Stack:** zsh scripts, Ghostty macOS adapter, Codex and Claude skill templates, shell integration tests.

---

## File Structure

- Create `scripts/commission`: Commission CLI for commissioner start/resume/refresh/send/review, consumer connect/notify/status, doctor.
- Create `scripts/commission-reset`: safe reset for current cwd `.commission/` plus matching global routes.
- Modify `scripts/ghostty-macos`: add `commissioner` and `consumer` capture roles while preserving existing ADL roles.
- Modify `.install.sh`: install Commission source skills/scripts into Codex and Claude skill roots with collision-safe backups.
- Create `skills/commission/SKILL.md`, `skills/commission-connect/SKILL.md`, `skills/commission-reset/SKILL.md`.
- Create `skills-claude/commission/SKILL.md`, `skills-claude/commission-connect/SKILL.md`, `skills-claude/commission-reset/SKILL.md`.
- Create `tests/commission_state_test.sh`: target-repo and cross-directory behavior.
- Modify `tests/install_test.sh`: install assertions and collision backup assertions.
- Modify `tests/skill_text_test.sh`: source skill text assertions.
- Modify `tests/ghostty_adapter_test.sh`: new role assertions.
- Modify `README.md`: document Commission purpose, commands, diagnostics, and install impact.

## Commission State Contract

Use exact single-quoted env lines and reject unknown keys or newline-containing values.

Pin route file:

```text
~/.commission/pins/<pin>.env
COMMISSION_PIN='<pin>'
COMMISSION_SESSION_ID='<session-id>'
COMMISSION_COMMISSIONER_ROOT='<absolute-team-a-root>'
COMMISSION_TARGET_REPO='<absolute-team-a-git-root-or-cwd>'
```

Consumer route file:

```text
~/.commission/consumers/<consumer-entry-key>.env
COMMISSION_CONSUMER_ENTRY_CWD='<absolute-team-b-entry-cwd>'
COMMISSION_SESSION_ID='<session-id>'
COMMISSION_COMMISSIONER_ROOT='<absolute-team-a-root>'
COMMISSION_TARGET_REPO='<absolute-team-a-git-root-or-cwd>'
```

Session file:

```text
.commission/sessions/<session-id>/session.env
COMMISSION_SESSION_ID='<session-id>'
COMMISSION_PIN='<pin>'
COMMISSION_STATUS='waiting_for_consumer'
COMMISSION_ACTIVE_RUN=''
COMMISSION_COMMISSIONER_TERMINAL_ID='<terminal-id>'
COMMISSION_CONSUMER_TERMINAL_ID=''
COMMISSION_TARGET_REPO='<absolute-team-a-git-root-or-cwd>'
COMMISSION_CONSUMER_ENTRY_CWD=''
```

Run file:

```text
.commission/sessions/<session-id>/runs/<run-id>/run.env
COMMISSION_RUN_ID='<run-id>'
COMMISSION_RUN_STATUS='pending_consumer_connection'
COMMISSION_PROMPT_PATH='<absolute-team-a-root>/.commission/sessions/<session-id>/runs/<run-id>/consumer-prompt.md'
COMMISSION_REPORT_PATH='<absolute-team-a-root>/.commission/sessions/<session-id>/runs/<run-id>/consumer-report.md'
COMMISSION_REVIEW_PATH=''
COMMISSION_SUPERSEDED_BY=''
```

`<consumer-entry-key>` is the first field from:

```zsh
print -r -- "${consumer_entry_cwd:A}" | /usr/bin/cksum | /usr/bin/awk '{ print $1 }'
```

Lookup precedence:

| Command | Rule |
| --- | --- |
| `consumer connect <pin>` | Resolve `~/.commission/pins/<pin>.env` first and `cd` to `COMMISSION_COMMISSIONER_ROOT`; ignore local `.commission/` in the Consumer entry cwd. |
| `consumer notify` | Resolve `~/.commission/consumers/<current-cwd-key>.env` first. If no route exists, use local `.commission/` only for the current cwd. |
| `status` | Report local `.commission/` only; do not follow Consumer routes. |
| `doctor` | Report local state and the installed marker for the script's actual Codex or Claude skill root. |

This version supports multiple sequential runs with one active run. The first run id is `001`; `next_run_id` increments to `002`, `003`, and so on. A new request may supersede a pending active run.

## Task 1: Add Commission State Tests First

**Files:**
- Create: `tests/commission_state_test.sh`
- Modify: `tests/run.sh` only if it does not already execute all `*_test.sh`

- [ ] **Step 1: Write failing cross-repo target test**

Create `tests/commission_state_test.sh` with a fixture that models Team A and Team B:

```zsh
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
```

- [ ] **Step 2: Add assertions for corrected invariant**

Append the test body:

```zsh
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
```

- [ ] **Step 3: Run test and verify it fails before implementation**

Run: `rtk tests/commission_state_test.sh`

Expected: fails because `scripts/commission` does not exist.

## Task 2: Implement Minimal Commission CLI State Model

**Files:**
- Create: `scripts/commission`
- Test: `tests/commission_state_test.sh`

- [ ] **Step 1: Add CLI skeleton and state helpers**

Create `scripts/commission` with the same zsh header style as `scripts/adl`. Include constants for `.commission`, routing dirs, `/bin` tool paths, `skill_invocation`, env validation, `repo_root`, `routing_key`, `safe_write`, `env_get`, and `env_set`. Use only the keys from the Commission State Contract, including `COMMISSION_COMMISSIONER_ROOT` and `COMMISSION_SUPERSEDED_BY`, plus timestamp and version keys needed for status/doctor output.

```text
COMMISSION_SESSION_ID
COMMISSION_PIN
COMMISSION_STATUS
COMMISSION_ACTIVE_RUN
COMMISSION_COMMISSIONER_TERMINAL_ID
COMMISSION_CONSUMER_TERMINAL_ID
COMMISSION_COMMISSIONER_ROOT
COMMISSION_TARGET_REPO
COMMISSION_CONSUMER_ENTRY_CWD
COMMISSION_RUN_ID
COMMISSION_RUN_STATUS
COMMISSION_PROMPT_PATH
COMMISSION_REPORT_PATH
COMMISSION_REVIEW_PATH
COMMISSION_SUPERSEDED_BY
```

- [ ] **Step 2: Implement Commissioner start**

Behavior:

```text
commission commissioner start
```

Creates `.commission/sessions/<session>/session.env`, writes `COMMISSION_TARGET_REPO` as `git rev-parse --show-toplevel` or `$PWD`, records Commissioner terminal via `ghostty-macos capture-focused commissioner`, writes `~/.commission/pins/<pin>.env`, and prints:

```text
Commission session ready.
Target repo: <absolute-target-repo>
Pin: <pin>
In Consumer, invoke: $commission-connect <pin>
```

- [ ] **Step 3: Implement send-consumer**

Behavior:

```text
commission commissioner send-consumer --prompt-file .commission/staging/request.md
```

Validate required sections, including `Target repo`, copy prompt to `.commission/sessions/<session>/runs/<next-run>/consumer-prompt.md`, remove the staging file after copy, set active run, and notify Consumer only when a Consumer terminal is recorded.

- [ ] **Step 4: Implement Consumer connect with pin-first routing**

Critical rule:

```zsh
commissioner_root="$(route_for_pin "$pin")"
cd "$commissioner_root"
```

Do this even if the Consumer entry cwd already contains `.commission/`. Record the original Consumer entry cwd as `COMMISSION_CONSUMER_ENTRY_CWD`; never treat it as target repo. Print:

```text
Connected to Commission session <pin>.
Target repo: <absolute-target-repo>
Commissioner notified: Consumer connected and ready.
Read your persistent consumer brief:
<absolute-brief-path>
Pending Commissioner's Request: <absolute-prompt-path>
Write Consumer report: <absolute-report-path>
Notify with: <absolute-commission-cli-path> consumer notify
```

- [ ] **Step 5: Run target routing test**

Run: `rtk tests/commission_state_test.sh`

Expected: passes through connect assertions, then may fail later if notify is not implemented yet.

## Task 3: Add Consumer Notify, Review, Status, Doctor, and Reset

**Files:**
- Modify: `scripts/commission`
- Create: `scripts/commission-reset`
- Test: `tests/commission_state_test.sh`

- [ ] **Step 1: Extend test for notify from Team B with valid local `.commission/`**

Append:

```zsh
mkdir -p "$TEAM_B/.commission/sessions/local/runs/001"
print -r -- "local" > "$TEAM_B/.commission/active-session"
/bin/cat > "$TEAM_B/.commission/sessions/local/session.env" <<'LOCAL'
COMMISSION_SESSION_ID='local'
COMMISSION_PIN='999999'
COMMISSION_STATUS='sent_to_consumer'
COMMISSION_ACTIVE_RUN='001'
COMMISSION_COMMISSIONER_TERMINAL_ID='team-b-local-terminal'
COMMISSION_CONSUMER_TERMINAL_ID=''
COMMISSION_TARGET_REPO='/tmp/team-b-should-not-be-used'
COMMISSION_CONSUMER_ENTRY_CWD=''
LOCAL
/bin/cat > "$TEAM_B/.commission/sessions/local/runs/001/run.env" <<'LOCALRUN'
COMMISSION_RUN_ID='001'
COMMISSION_RUN_STATUS='sent_to_consumer'
COMMISSION_PROMPT_PATH='/tmp/team-b-should-not-be-used/.commission/sessions/local/runs/001/consumer-prompt.md'
COMMISSION_REPORT_PATH='/tmp/team-b-should-not-be-used/.commission/sessions/local/runs/001/consumer-report.md'
COMMISSION_REVIEW_PATH=''
COMMISSION_SUPERSEDED_BY=''
LOCALRUN

report="$TEAM_A/.commission/sessions/$session_id/runs/001/consumer-report.md"
/bin/cat > "$report" <<REPORT
# Consumer Report

Status: DONE
Goal: Add checklist support to Team A todo app
Slice: Add the minimal checklist model

## Acceptance Results
- Consumer target repo is Team A. PASS - connect output printed $TEAM_A.
- Team B entry cwd does not receive protocol truth state. PASS - Team B has no active-session.

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

cd "$TEAM_B"
notify_from_b="$("$ROOT/scripts/commission" consumer notify)"
assert_contains "$notify_from_b" "Consumer's Report sent" "notify should work from Consumer entry cwd"
assert_contains "$(/bin/cat "$TEAM_A/.commission/sessions/$session_id/runs/001/run.env")" "COMMISSION_RUN_STATUS='reported'" "Team A run should be reported"
assert_contains "$(/bin/cat "$TEAM_B/.commission/sessions/local/runs/001/run.env")" "COMMISSION_RUN_STATUS='sent_to_consumer'" "Team B local session should not be touched"

cd "$TEAM_A"
status="$("$ROOT/scripts/commission" status)"
assert_contains "$status" "Target repo: $TEAM_A" "status should expose target repo"
assert_contains "$status" "Run status: reported" "status should show reported run"
```

- [ ] **Step 2: Add missing-route negative notify assertion**

Append a separate fixture check:

```zsh
ORPHAN="$TMP/orphan-consumer"
mkdir -p "$ORPHAN"
cd "$ORPHAN"
set +e
missing_route="$("$ROOT/scripts/commission" consumer notify 2>&1)"
missing_route_code="$?"
set -e
assert_eq "1" "$missing_route_code" "notify without route should fail clearly"
assert_contains "$missing_route" "Reconnect with \$commission-connect <pin>" "missing route should tell Consumer to reconnect"
```

- [ ] **Step 3: Implement notify with route-first precedence**

Resolve `~/.commission/consumers/<current-cwd-key>.env` first. If it exists, `cd` to `COMMISSION_COMMISSIONER_ROOT` from that route. Only when no Consumer route exists may notify use local `.commission/` for the current cwd. Validate report sections before setting Team A's run status to `reported`.

- [ ] **Step 4: Implement review and status**

`commission commissioner review` records verdict and review file under the active run. `commission status` prints:

```text
Commission session: <session-id>
Root: <commissioner-root>
Target repo: <target-repo>
Pin: <pin>
Status: <session-status>
Consumer: connected|not connected
Active run: <run-id>
Run status: <run-status>
Next: <next-action>
```

- [ ] **Step 5: Implement doctor**

`commission doctor` reports cwd, `.commission` presence, session state, target repo, routing dir, Ghostty adapter, and installed marker. Detect the installed runtime from `SCRIPT_PATH`: `.claude/skills` uses the Claude skill root; otherwise Codex uses the Codex skill root.

- [ ] **Step 6: Implement reset**

Create `scripts/commission-reset` mirroring `scripts/adl-reset` safety: accept only `"$PWD/.commission"`, reject symlinks and non-directories, remove matching pin and consumer routes whose Commissioner root equals current cwd, then remove local `.commission/`.

## Task 4: Add Ghostty Role Support

**Files:**
- Modify: `scripts/ghostty-macos`
- Modify: `tests/ghostty_adapter_test.sh`

- [ ] **Step 1: Add failing role assertions**

In `tests/ghostty_adapter_test.sh`, assert dry-run capture works for `commissioner` and `consumer` and prints `COMMISSION_COMMISSIONER_TERMINAL_ID` / `COMMISSION_CONSUMER_TERMINAL_ID`.

- [ ] **Step 2: Update adapter role validation**

Allow `capture-focused architect|dev|commissioner|consumer`. Use `ADL_` prefix for ADL roles and `COMMISSION_` prefix for Commission roles.

- [ ] **Step 3: Run adapter test**

Run: `rtk tests/ghostty_adapter_test.sh`

Expected: pass.

## Task 5: Add Skills and Installer Support Safely

**Files:**
- Modify: `.install.sh`
- Create: `skills/commission/SKILL.md`
- Create: `skills/commission-connect/SKILL.md`
- Create: `skills/commission-reset/SKILL.md`
- Create: `skills-claude/commission/SKILL.md`
- Create: `skills-claude/commission-connect/SKILL.md`
- Create: `skills-claude/commission-reset/SKILL.md`
- Modify: `tests/install_test.sh`
- Modify: `tests/skill_text_test.sh`

- [ ] **Step 1: Add install collision and marker tests**

In `tests/install_test.sh`, create unrelated existing `commission`, `commission-connect`, and `commission-reset` skill dirs in both `ADL_CODEX_SKILLS_DIR` and `ADL_CLAUDE_SKILLS_DIR` before install. Assert each is backed up under `.adl-project-backups` before replacement. Assert every installed managed skill has `.adl-project-skill`, and assert `commission/.commission-framework` exists for doctor metadata.

- [ ] **Step 2: Implement installer backup for each managed skill**

Use `.adl-project-skill` as the per-target managed marker for every installed skill directory. Preserve `adl/.adl-framework` and add `commission/.commission-framework` as group-level doctor markers. Replace the single `adl` backup check with a helper:

```zsh
backup_if_unmanaged() {
  local target="$1" label="$2"
  [[ -d "$target" ]] || return 0
  [[ -f "$target/.adl-project-skill" || -f "$target/.adl-framework" || -f "$target/.commission-framework" ]] && return 0
  local ts backup
  ts="$("$DATE" +%Y%m%d-%H%M%S)"
  backup="$backup_root/$ts/$label"
  "$MKDIR" -p "$backup:h"
  "$CP" -R "$target" "$backup"
  print -r -- "Backed up existing $label skill to: $backup"
}
```

Call it for `adl`, `adl-connect`, `adl-reset`, `commission`, `commission-connect`, and `commission-reset` before removing targets. After installing each skill directory, write:

```text
ADL_PROJECT_VERSION='<version>'
ADL_PROJECT_SOURCE='<repo-root>'
ADL_PROJECT_SKILL='<skill-name>'
```

to `<skill>/.adl-project-skill`.

- [ ] **Step 3: Add source skill templates**

Codex skills use `$commission`, `$commission-connect`, `$commission-reset`; Claude skills use slash invocations. `commission-connect` must instruct Consumer to switch all reads, edits, and verification commands to the printed `Target repo` before opening the request or changing files.

- [ ] **Step 4: Add skill text assertions**

Assert source templates use `{{ADL_SKILLS_DIR}}`, mention target repo, and do not use ADL active role names as Commission active roles. Add an assertion for this exact Consumer instruction text:

```text
Run all implementation reads, edits, and verification commands from the printed Target repo.
```

- [ ] **Step 5: Run install and skill tests**

Run: `rtk tests/install_test.sh` and `rtk tests/skill_text_test.sh`

Expected: pass.

## Task 6: Document and Verify Whole Surface

**Files:**
- Modify: `README.md`
- Test: all tests

- [ ] **Step 1: Update README**

Document Commission as: Team A starts from target repo; Team B may connect from elsewhere but implements in Team A's target repo. Include command table for `$commission`, `$commission-connect <pin>`, `$commission-reset`, `commission status`, and `commission doctor`.

- [ ] **Step 2: Run full verification**

Run: `rtk ./tests/run.sh`

Expected:

```text
Running adl_reset_test.sh
Running cli_state_test.sh
Running commission_state_test.sh
Running doctor_test.sh
Running ghostty_adapter_test.sh
Running install_test.sh
Running panel_message_test.sh
Running skill_text_test.sh
All tests passed.
```

- [ ] **Step 3: Inspect working tree**

Run: `rtk proxy git status --short --untracked-files=all`

Expected: only intended Commission source, docs, and tests are changed. Do not commit unless the user explicitly asks.

## Self-Review

- Spec coverage: all spec requirements map to Tasks 1-6.
- Placeholder scan: no TBD/TODO/implement-later placeholders.
- Type consistency: plan consistently uses `COMMISSION_TARGET_REPO` for the work target and `COMMISSION_CONSUMER_ENTRY_CWD` for the Consumer's starting directory.
- Scope check: single implementation plan, no unrelated ADL refactor or shared library extraction.
