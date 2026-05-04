# ADL Ghostty POC Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the shell-only ADL Ghostty POC described in `docs/specs/2026-05-04-adl-ghostty-poc-design.md`.

**Architecture:** Global Codex skills are installed from this project and call a skill-owned shell CLI by absolute path. The CLI owns session/run state under the caller's cwd-local `.adl/`; Ghostty AppleScript is used only to deliver short wake-up messages between existing Codex TUI panes.

**Tech Stack:** `/bin/zsh` scripts, macOS `/usr/bin/osascript`, Ghostty AppleScript, Markdown skill files, shell-based tests with no Python, no `jq`, and no PATH assumptions for installed CLI invocation or Ghostty transport.

---

## File Structure

- Create: `skills/adl/SKILL.md`  
  Architect-side Codex skill. Starts/resumes ADL, writes Dev prompts to `.adl/staging/`, and sends them without printing full prompt text.

- Create: `skills/adl-connect/SKILL.md`  
  Dev-side Codex skill. Connects/reconnects to a pin, reads `dev-brief.md`, follows `Architect's Request:` files, writes `dev-report.md`, and runs notify.

- Create: `scripts/adl`  
  Main zsh CLI. Owns install/runtime constants, argument parsing, `.adl` state, safe `.env` parsing/writing, run allocation, status, send-dev, connect, notify, and validation errors.

- Create: `scripts/ghostty-macos`  
  Ghostty transport adapter. Captures focused terminal metadata and sends short wake-up messages through AppleScript. Supports `ADL_GHOSTTY_DRY_RUN=1` for automated tests.

- Modify: `.install.sh`  
  Idempotently installs the two global skills and script files into `/Users/liadgoren/.codex/skills`, backing up the existing global `adl` skill unless it already has the ADL framework marker.

- Create: `tests/run.sh`  
  Shell test harness that runs all automated tests.

- Create: `tests/assert.sh`  
  Minimal shell assertions and temporary fixture helpers.

- Create: `tests/install_test.sh`  
  Tests installer backup/idempotency behavior against temporary fake Codex home paths.

- Create: `tests/cli_state_test.sh`  
  Tests `.adl` session state, active session reuse/new, send-dev, supersede, connect, notify rejection/success, and status.

- Create: `tests/ghostty_adapter_test.sh`  
  Tests Ghostty adapter argument validation and dry-run send/capture behavior without controlling the real app.

## Task 1: Test Harness

**Files:**
- Create: `tests/assert.sh`
- Create: `tests/run.sh`

- [ ] **Step 1: Write the shell assertion helpers**

Create `tests/assert.sh`:

```sh
#!/bin/zsh
set -euo pipefail
setopt EXTENDED_GLOB

fail() {
  print -r -- "FAIL: $*" >&2
  exit 1
}

assert_eq() {
  local expected="$1"
  local actual="$2"
  local message="$3"
  [[ "$expected" == "$actual" ]] || fail "$message: expected [$expected], got [$actual]"
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local message="$3"
  [[ "$haystack" == *"$needle"* ]] || fail "$message: missing [$needle] in [$haystack]"
}

assert_file_exists() {
  local path="$1"
  [[ -f "$path" ]] || fail "expected file to exist: $path"
}

assert_dir_exists() {
  local path="$1"
  [[ -d "$path" ]] || fail "expected directory to exist: $path"
}

new_tmpdir() {
  mktemp -d "${TMPDIR:-/tmp}/adl-project-test.XXXXXX"
}
```

- [ ] **Step 2: Write the test runner**

Create `tests/run.sh`:

```sh
#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

for test_file in "$ROOT"/tests/*_test.sh; do
  print -r -- "Running ${test_file:t}"
  "$test_file"
done

print -r -- "All tests passed."
```

- [ ] **Step 3: Make scripts executable**

Run:

```bash
chmod +x tests/assert.sh tests/run.sh
```

Expected: command exits `0`.

- [ ] **Step 4: Run harness before tests exist**

Run:

```bash
./tests/run.sh
```

Expected: `All tests passed.` because no `*_test.sh` files exist yet.

## Task 2: Installer Safety

**Files:**
- Modify: `.install.sh`
- Create: `tests/install_test.sh`

- [ ] **Step 1: Write failing installer tests**

Create `tests/install_test.sh`:

```sh
#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/tests/assert.sh"

TMP="$(new_tmpdir)"
trap 'rm -rf "$TMP"' EXIT

export ADL_CODEX_SKILLS_DIR="$TMP/skills"
mkdir -p "$ADL_CODEX_SKILLS_DIR/adl"
print -r -- "legacy skill" > "$ADL_CODEX_SKILLS_DIR/adl/SKILL.md"

mkdir -p "$ROOT/skills/adl" "$ROOT/skills/adl-connect" "$ROOT/scripts"
print -r -- "---\nname: adl\n---\n# ADL" > "$ROOT/skills/adl/SKILL.md"
print -r -- "---\nname: adl-connect\n---\n# ADL Connect" > "$ROOT/skills/adl-connect/SKILL.md"
print -r -- "#!/bin/zsh\nprint adl" > "$ROOT/scripts/adl"
print -r -- "#!/bin/zsh\nprint ghostty" > "$ROOT/scripts/ghostty-macos"

output="$("$ROOT/.install.sh")"

assert_contains "$output" "Backed up existing adl skill" "installer should back up legacy skill"
assert_file_exists "$ADL_CODEX_SKILLS_DIR/adl/.adl-framework"
assert_file_exists "$ADL_CODEX_SKILLS_DIR/adl/scripts/adl"
assert_file_exists "$ADL_CODEX_SKILLS_DIR/adl/scripts/ghostty-macos"
assert_file_exists "$ADL_CODEX_SKILLS_DIR/adl-connect/SKILL.md"

backup_count="$(find "$ADL_CODEX_SKILLS_DIR/.adl-project-backups" -name SKILL.md | wc -l | tr -d ' ')"
assert_eq "1" "$backup_count" "one legacy skill backup should exist"

second="$("$ROOT/.install.sh")"
assert_contains "$second" "Installed ADL framework" "second install should be idempotent"

backup_count_after="$(find "$ADL_CODEX_SKILLS_DIR/.adl-project-backups" -name SKILL.md | wc -l | tr -d ' ')"
assert_eq "1" "$backup_count_after" "idempotent reinstall should not create another backup"
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
chmod +x tests/install_test.sh
./tests/install_test.sh
```

Expected: FAIL because `.install.sh` still prints `ADL installer is not implemented yet.` and does not copy files.

- [ ] **Step 3: Implement installer**

Replace `.install.sh` with:

```sh
#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h}"
VERSION="0.1.0"
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
```

- [ ] **Step 4: Run installer tests**

Run:

```bash
./tests/install_test.sh
```

Expected: exits `0`.

## Task 3: Ghostty Adapter Spike

**Files:**
- Create: `scripts/ghostty-macos`
- Create: `tests/ghostty_adapter_test.sh`

- [ ] **Step 1: Write failing adapter tests**

Create `tests/ghostty_adapter_test.sh`:

```sh
#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/tests/assert.sh"

export ADL_GHOSTTY_DRY_RUN=1

capture="$("$ROOT/scripts/ghostty-macos" capture-focused architect)"
assert_contains "$capture" "ADL_ARCHITECT_ADAPTER='ghostty-macos'" "capture should emit architect adapter"
assert_contains "$capture" "ADL_ARCHITECT_TERMINAL_ID='dry-run-architect-terminal'" "capture should emit dry architect terminal id"

dev_capture="$("$ROOT/scripts/ghostty-macos" capture-focused dev)"
assert_contains "$dev_capture" "ADL_DEV_TERMINAL_ID='dry-run-dev-terminal'" "capture should emit dry dev terminal id"

send="$("$ROOT/scripts/ghostty-macos" send dry-run-dev-terminal "Architect's Request:\nRead file")"
assert_contains "$send" "DRY RUN send to dry-run-dev-terminal" "send should dry-run"

set +e
bad="$("$ROOT/scripts/ghostty-macos" send "" "message" 2>&1)"
code="$?"
set -e
assert_eq "3" "$code" "empty terminal id should be transport failure"
assert_contains "$bad" "Missing terminal id" "empty terminal id should explain failure"
```

- [ ] **Step 2: Run adapter test to verify it fails**

Run:

```bash
chmod +x tests/ghostty_adapter_test.sh
./tests/ghostty_adapter_test.sh
```

Expected: FAIL because `scripts/ghostty-macos` does not exist.

- [ ] **Step 3: Implement Ghostty adapter**

Create `scripts/ghostty-macos`:

```sh
#!/bin/zsh
set -euo pipefail

cmd="${1:-}"

die_transport() {
  print -r -- "$*" >&2
  exit 3
}

escape_applescript_text() {
  local text="$1"
  text="${text//\\/\\\\}"
  text="${text//\"/\\\"}"
  print -r -- "$text"
}

capture_dry_run() {
  local role="$1"
  local role_upper="${role:u}"
  print -r -- "ADL_${role_upper}_ADAPTER='ghostty-macos'"
  print -r -- "ADL_${role_upper}_TERMINAL_ID='dry-run-${role}-terminal'"
  print -r -- "ADL_${role_upper}_LABEL='Ghostty dry-run ${role} terminal'"
}

case "$cmd" in
  capture-focused)
    role="${2:-}"
    [[ "$role" == "architect" || "$role" == "dev" ]] || die_transport "Usage: ghostty-macos capture-focused architect|dev"
    if [[ "${ADL_GHOSTTY_DRY_RUN:-0}" == "1" ]]; then
      capture_dry_run "$role"
      exit 0
    fi
    term_id="$(/usr/bin/osascript <<'APPLESCRIPT'
tell application "Ghostty"
  set t to focused terminal of selected tab of front window
  return (id of t as text)
end tell
APPLESCRIPT
)" || die_transport "Ghostty capture failed. Grant automation permission for osascript to control Ghostty, then reconnect."
    [[ -n "$term_id" ]] || die_transport "Ghostty capture returned an empty terminal id"
    role_upper="${role:u}"
    print -r -- "ADL_${role_upper}_ADAPTER='ghostty-macos'"
    print -r -- "ADL_${role_upper}_TERMINAL_ID='$term_id'"
    print -r -- "ADL_${role_upper}_LABEL='Ghostty terminal $term_id'"
    ;;
  send)
    terminal_id="${2:-}"
    message="${3:-}"
    [[ -n "$terminal_id" ]] || die_transport "Missing terminal id"
    [[ -n "$message" ]] || die_transport "Missing message"
    if [[ "${ADL_GHOSTTY_DRY_RUN:-0}" == "1" ]]; then
      print -r -- "DRY RUN send to $terminal_id"
      exit 0
    fi
    escaped="$(escape_applescript_text "$message")"
/usr/bin/osascript <<APPLESCRIPT || die_transport "Ghostty send failed. Reconnect the target terminal and retry."
tell application "Ghostty"
  set targetId to "$terminal_id"
  set targetTerm to missing value
  repeat with candidate in terminals
    if ((id of candidate as text) is targetId) then
      set targetTerm to candidate
      exit repeat
    end if
  end repeat
  if targetTerm is missing value then error "target terminal not found"
  input text "$escaped" to targetTerm
  send key "enter" to targetTerm
end tell
APPLESCRIPT
    ;;
  *)
    die_transport "Usage: ghostty-macos capture-focused architect|dev | send <terminal-id> <message>"
    ;;
esac
```

- [ ] **Step 4: Run adapter tests**

Run:

```bash
chmod +x scripts/ghostty-macos
./tests/ghostty_adapter_test.sh
```

Expected: exits `0`.

- [ ] **Step 5: Manual Ghostty spike gate**

This step is blocking before Task 4. Use two existing Ghostty Codex panes.

In the Architect pane, run:

```bash
scripts/ghostty-macos capture-focused architect
```

Expected: prints `ADL_ARCHITECT_TERMINAL_ID='<real-id>'` or a clear permission/action error.

In the Dev pane, run:

```bash
scripts/ghostty-macos capture-focused dev
```

Expected: prints `ADL_DEV_TERMINAL_ID='<real-id>'` or a clear permission/action error.

From the Architect pane, send to the Dev terminal id captured above:

```bash
scripts/ghostty-macos send '<dev-terminal-id>' "Architect's Request:

Transport spike request."
```

Expected: the Dev Codex pane receives the `Architect's Request:` message.

From the Dev pane, send to the Architect terminal id captured above:

```bash
scripts/ghostty-macos send '<architect-terminal-id>' "Developer's Report:

Transport spike report."
```

Expected: the Architect Codex pane receives the `Developer's Report:` message.

If stored IDs cannot be re-targeted after focus/tab changes, record that result and keep the reconnect-before-send fallback allowed by the spec. If capture or send fails because of macOS automation permissions, grant the permission and rerun this step before Task 4.

## Task 4: CLI State Machine

**Files:**
- Create: `scripts/adl`
- Create: `tests/cli_state_test.sh`

- [ ] **Step 1: Write failing CLI state tests**

Create `tests/cli_state_test.sh`:

```sh
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

mkdir -p .adl/staging
print -r -- "Implement task A" > .adl/staging/prompt.md
send_before="$("$ROOT/scripts/adl" architect send-dev --prompt-file .adl/staging/prompt.md)"
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

mkdir -p .adl/staging
print -r -- "Implement task B" > .adl/staging/prompt2.md
"$ROOT/scripts/adl" architect send-dev --prompt-file .adl/staging/prompt2.md >/dev/null
print -r -- "Implement task C" > .adl/staging/prompt3.md
supersede="$("$ROOT/scripts/adl" architect send-dev --prompt-file .adl/staging/prompt3.md)"
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

status="$("$ROOT/scripts/adl" status)"
assert_contains "$status" "Active run: 003" "status should show latest run"

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
```

- [ ] **Step 2: Run CLI test to verify it fails**

Run:

```bash
chmod +x tests/cli_state_test.sh
./tests/cli_state_test.sh
```

Expected: FAIL because `scripts/adl` does not exist.

- [ ] **Step 3: Implement CLI**

Create `scripts/adl` with:

```sh
#!/bin/zsh
set -euo pipefail
setopt EXTENDED_GLOB

VERSION="0.1.0"
SCRIPT_PATH="${0:A}"
SCRIPT_DIR="${ADL_SCRIPT_ROOT:-${SCRIPT_PATH:h}}"
GHOSTTY="$SCRIPT_DIR/ghostty-macos"
ADL_DIR=".adl"
SESSIONS_DIR="$ADL_DIR/sessions"
STAGING_DIR="$ADL_DIR/staging"
ACTIVE_FILE="$ADL_DIR/active-session"
DATE="/bin/date"
CAT="/bin/cat"
CP="/bin/cp"
MKDIR="/bin/mkdir"
MV="/bin/mv"
RM="/bin/rm"
AWK="/usr/bin/awk"

die() { print -r -- "$*" >&2; exit 1; }
die_state() { print -r -- "$*" >&2; exit 2; }
die_transport() { print -r -- "$*" >&2; exit 3; }

now_ts() { "$DATE" "+%Y-%m-%dT%H:%M:%S%z"; }
pin() { printf "%06d\n" "$((100000 + RANDOM % 900000))"; }
session_id_for_pin() { print -r -- "$("$DATE" "+%Y-%m-%d-%H%M%S")-$1"; }

safe_write() {
  local path="$1"
  local tmp="$path.tmp.$$"
  "$CAT" > "$tmp"
  "$MV" "$tmp" "$path"
}

allowed_key() {
  case "$1" in
    ADL_SESSION_ID|ADL_PIN|ADL_STATUS|ADL_ACTIVE_RUN|ADL_ARCHITECT_ADAPTER|ADL_ARCHITECT_TERMINAL_ID|ADL_DEV_ADAPTER|ADL_DEV_TERMINAL_ID|ADL_DEV_GENERATION|ADL_VERSION|ADL_RUN_ID|ADL_RUN_STATUS|ADL_PROMPT_PATH|ADL_REPORT_PATH|ADL_CREATED_AT|ADL_SENT_AT|ADL_REPORTED_AT|ADL_SUPERSEDED_BY)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

validate_value() {
  local key="$1" value="$2"
  [[ "$value" != *$'\n'* ]] || return 1
  case "$key" in
    ADL_PROMPT_PATH|ADL_REPORT_PATH)
      [[ "$value" == .adl/* ]]
      ;;
    ADL_SESSION_ID)
      [[ "$value" == [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9] ]]
      ;;
    ADL_PIN)
      [[ "$value" == <100000-999999> ]]
      ;;
    ADL_STATUS|ADL_RUN_STATUS)
      [[ "$value" == waiting_for_dev || "$value" == pending_dev_connection || "$value" == sent_to_dev || "$value" == reported || "$value" == superseded || "$value" == closed ]]
      ;;
    *)
      [[ -z "$value" || "$value" == [A-Za-z0-9._:/+-]## ]]
      ;;
  esac
}

validate_env_file() {
  local file="$1"
  local line key prefix suffix value
  [[ -f "$file" ]] || return 1
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    key="${line%%=*}"
    allowed_key "$key" || die_state "Unknown ADL env key in $file: $key"
    prefix="$key='"
    suffix="'"
    [[ "$line" == "$prefix"*"$suffix" ]] || die_state "Malformed ADL env line in $file: $line"
    value="${line#$prefix}"
    value="${value%$suffix}"
    validate_value "$key" "$value" || die_state "Unsafe ADL env value for $key in $file"
  done < "$file"
}

env_get() {
  local file="$1"
  local key="$2"
  allowed_key "$key" || die_state "Unknown ADL env key: $key"
  [[ -f "$file" ]] || return 1
  validate_env_file "$file"
  local value
  value="$("$AWK" -F"'" -v key="$key" '$1 == key"=" && $3 == "" { print $2; found=1; exit } END { if (!found) exit 1 }' "$file")" || return 1
  validate_value "$key" "$value" || die_state "Unsafe ADL env value for $key in $file"
  print -r -- "$value"
}

env_set() {
  local file="$1"
  local key="$2"
  local value="$3"
  allowed_key "$key" || die_state "Unknown ADL env key: $key"
  validate_value "$key" "$value" || die_state "Unsafe ADL env value for $key"
  validate_env_file "$file"
  local tmp="$file.tmp.$$"
  "$AWK" -v key="$key" -v value="$value" '
    BEGIN { done=0 }
    $0 ~ "^" key "=" { print key "='\''" value "'\''"; done=1; next }
    { print }
    END { if (!done) print key "='\''" value "'\''" }
  ' "$file" > "$tmp"
  "$MV" "$tmp" "$file"
}

active_session() {
  [[ -f "$ACTIVE_FILE" ]] || return 1
  "$CAT" "$ACTIVE_FILE"
}

session_file() {
  print -r -- "$SESSIONS_DIR/$1/session.env"
}

require_active_session() {
  local sid
  sid="$(active_session)" || die "No active ADL session. Invoke \$adl first."
  [[ -f "$(session_file "$sid")" ]] || die_state "Active ADL session is missing session.env: $sid"
  print -r -- "$sid"
}

capture_role() {
  local role="$1"
  "$GHOSTTY" capture-focused "$role" || die_transport "Ghostty capture failed for $role. Grant permissions or reconnect from a Ghostty pane."
}

create_session() {
  "$MKDIR" -p "$SESSIONS_DIR" "$STAGING_DIR"
  local p sid sdir
  p="$(pin)"
  sid="$(session_id_for_pin "$p")"
  sdir="$SESSIONS_DIR/$sid"
  "$MKDIR" -p "$sdir/runs"
  local capture
  capture="$(capture_role architect)"
  local arch_term
  arch_term="$(print -r -- "$capture" | "$AWK" -F"'" '$1 == "ADL_ARCHITECT_TERMINAL_ID=" { print $2; exit }')"
  {
    print -r -- "ADL_SESSION_ID='$sid'"
    print -r -- "ADL_PIN='$p'"
    print -r -- "ADL_STATUS='waiting_for_dev'"
    print -r -- "ADL_ACTIVE_RUN=''"
    print -r -- "ADL_ARCHITECT_ADAPTER='ghostty-macos'"
    print -r -- "ADL_ARCHITECT_TERMINAL_ID='$arch_term'"
    print -r -- "ADL_DEV_ADAPTER=''"
    print -r -- "ADL_DEV_TERMINAL_ID=''"
    print -r -- "ADL_DEV_GENERATION='0'"
    print -r -- "ADL_VERSION='$VERSION'"
  } | safe_write "$sdir/session.env"
  print -r -- "$sid" | safe_write "$ACTIVE_FILE"
  print -r -- "ADL session ready."
  print -r -- "Pin: $p"
  print -r -- "In Dev Codex, invoke: \$adl-connect $p"
}

start_architect() {
  if [[ "${1:-}" == "--new" ]]; then
    if sid="$(active_session 2>/dev/null)"; then
      local sf
      sf="$(session_file "$sid")"
      [[ -f "$sf" ]] && env_set "$sf" ADL_STATUS closed
    fi
    create_session
    return
  fi
  "$MKDIR" -p "$ADL_DIR"
  if sid="$(active_session 2>/dev/null)" && [[ -f "$(session_file "$sid")" ]]; then
    local p
    p="$(env_get "$(session_file "$sid")" ADL_PIN)"
    print -r -- "Resumed ADL session."
    print -r -- "Pin: $p"
    return
  fi
  create_session
}

next_run_id() {
  local sid="$1"
  local runs="$SESSIONS_DIR/$sid/runs"
  "$MKDIR" -p "$runs"
  local max=0 n d
  for d in "$runs"/[0-9][0-9][0-9](N); do
    n="${d:t}"
    (( 10#$n > max )) && max="$((10#$n))"
  done
  printf "%03d\n" "$((max + 1))"
}

write_run_env() {
  local sid="$1" rid="$2" status="$3"
  local rdir="$SESSIONS_DIR/$sid/runs/$rid"
  {
    print -r -- "ADL_RUN_ID='$rid'"
    print -r -- "ADL_RUN_STATUS='$status'"
    print -r -- "ADL_PROMPT_PATH='$rdir/dev-prompt.md'"
    print -r -- "ADL_REPORT_PATH='$rdir/dev-report.md'"
    print -r -- "ADL_CREATED_AT='$(now_ts)'"
    print -r -- "ADL_SENT_AT=''"
    print -r -- "ADL_REPORTED_AT=''"
    print -r -- "ADL_SUPERSEDED_BY=''"
  } | safe_write "$rdir/run.env"
}

send_dev() {
  [[ "${1:-}" == "--prompt-file" ]] || die "Usage: adl architect send-dev --prompt-file <path>"
  local prompt="${2:-}"
  [[ -f "$prompt" ]] || die "Missing prompt file: $prompt"
  [[ "$prompt" == .adl/staging/* ]] || die "Prompt file must be under .adl/staging/"
  local sid sf active rid rdir dev_term status
  sid="$(require_active_session)"
  sf="$(session_file "$sid")"
  active="$(env_get "$sf" ADL_ACTIVE_RUN || true)"
  if [[ -n "$active" ]]; then
    local active_env="$SESSIONS_DIR/$sid/runs/$active/run.env"
    local active_status="$(env_get "$active_env" ADL_RUN_STATUS || true)"
    if [[ "$active_status" == "pending_dev_connection" || "$active_status" == "sent_to_dev" ]]; then
      env_set "$active_env" ADL_RUN_STATUS superseded
    fi
  fi
  rid="$(next_run_id "$sid")"
  rdir="$SESSIONS_DIR/$sid/runs/$rid"
  "$MKDIR" -p "$rdir"
  "$CP" "$prompt" "$rdir/dev-prompt.md.tmp.$$"
  "$MV" "$rdir/dev-prompt.md.tmp.$$" "$rdir/dev-prompt.md"
  "$RM" -f "$prompt"
  dev_term="$(env_get "$sf" ADL_DEV_TERMINAL_ID || true)"
  status="pending_dev_connection"
  write_run_env "$sid" "$rid" "$status"
  env_set "$sf" ADL_ACTIVE_RUN "$rid"
  env_set "$sf" ADL_STATUS "$status"
  if [[ -n "$dev_term" ]]; then
    "$GHOSTTY" send "$dev_term" "Architect's Request: read and execute $rdir/dev-prompt.md. When done, write $rdir/dev-report.md, then run /Users/liadgoren/.codex/skills/adl/scripts/adl dev notify." >/dev/null || die_transport "Failed to wake Dev. Reconnect Dev and retry."
    env_set "$rdir/run.env" ADL_RUN_STATUS sent_to_dev
    env_set "$rdir/run.env" ADL_SENT_AT "$(now_ts)"
    env_set "$sf" ADL_STATUS sent_to_dev
    print -r -- "Passing this to the developer..."
    print -r -- "Run: $rid"
  else
    print -r -- "Dev is not connected."
    print -r -- "Run: $rid"
    print -r -- "Pin: $(env_get "$sf" ADL_PIN)"
  fi
  [[ -n "$active" ]] && print -r -- "Previous active run superseded: $active"
}

write_dev_brief_once() {
  local sid="$1"
  local brief="$SESSIONS_DIR/$sid/dev-brief.md"
  [[ -f "$brief" ]] && return
  "$CAT" > "$brief" <<'BRIEF'
# ADL Developer Brief

You are the Developer in an Architect-Developer Loop.

For each Architect's Request:
1. Read the requested dev-prompt.md.
2. Execute only that scope.
3. Write dev-report.md using the requested template.
4. Run /Users/liadgoren/.codex/skills/adl/scripts/adl dev notify.

Do not commit unless explicitly instructed.
Do not broaden scope.
BRIEF
}

connect_dev() {
  local p="${1:-}"
  local replace="${2:-}"
  [[ -n "$p" ]] || die "Usage: adl dev connect <pin> [--replace]"
  local found=""
  for sf in "$SESSIONS_DIR"/*/session.env(N); do
    [[ "$(env_get "$sf" ADL_PIN || true)" == "$p" ]] && found="${sf:h:t}"
  done
  [[ -n "$found" ]] || die "No .adl session with pin $p found in this directory."
  local sf="$(session_file "$found")"
  local existing="$(env_get "$sf" ADL_DEV_TERMINAL_ID || true)"
  if [[ -n "$existing" && "$replace" != "--replace" ]]; then
    die "Dev already connected. Run: \$adl-connect $p --replace"
  fi
  write_dev_brief_once "$found"
  local capture dev_term
  capture="$(capture_role dev)"
  dev_term="$(print -r -- "$capture" | "$AWK" -F"'" '$1 == "ADL_DEV_TERMINAL_ID=" { print $2; exit }')"
  env_set "$sf" ADL_DEV_ADAPTER ghostty-macos
  env_set "$sf" ADL_DEV_TERMINAL_ID "$dev_term"
  env_set "$sf" ADL_DEV_GENERATION "$(( $(env_get "$sf" ADL_DEV_GENERATION || print 0) + 1 ))"
  print -r -- "Connected to ADL session $p."
  print -r -- "Read your persistent developer brief:"
  print -r -- "$SESSIONS_DIR/$found/dev-brief.md"
  local active="$(env_get "$sf" ADL_ACTIVE_RUN || true)"
  [[ -n "$active" ]] && print -r -- "Pending Architect's Request: $SESSIONS_DIR/$found/runs/$active/dev-prompt.md"
}

notify_dev() {
  local sid sf active rdir report arch_term
  sid="$(require_active_session)"
  sf="$(session_file "$sid")"
  active="$(env_get "$sf" ADL_ACTIVE_RUN || true)"
  [[ -n "$active" ]] || die "No active run to notify."
  rdir="$SESSIONS_DIR/$sid/runs/$active"
  local run_status
  run_status="$(env_get "$rdir/run.env" ADL_RUN_STATUS || true)"
  [[ "$run_status" != "superseded" ]] || die "Cannot notify for superseded run: $active"
  report="$rdir/dev-report.md"
  [[ -f "$report" ]] || {
    print -r -- "Cannot notify Architect yet." >&2
    print -r -- "Missing: $report" >&2
    print -r -- "# Dev Report\n\nStatus: DONE | BLOCKED | NEEDS_CONTEXT\n\n## Files Changed\n\n## Verification\n\n## Deviations\n\n## Blockers Or Assumptions\n\n## Notes" >&2
    exit 1
  }
  env_set "$rdir/run.env" ADL_RUN_STATUS reported
  env_set "$rdir/run.env" ADL_REPORTED_AT "$(now_ts)"
  env_set "$sf" ADL_STATUS reported
  arch_term="$(env_get "$sf" ADL_ARCHITECT_TERMINAL_ID || true)"
  "$GHOSTTY" send "$arch_term" "Developer's Report: read $report. Review against repo state before approving or sending a follow-up." >/dev/null || die_transport "Failed to wake Architect. Reconnect Architect by invoking \$adl."
  print -r -- "Developer's Report sent."
}

status_cmd() {
  if ! sid="$(active_session 2>/dev/null)"; then
    print -r -- "No active ADL session."
    return
  fi
  local sf="$(session_file "$sid")"
  [[ -f "$sf" ]] || die_state "Active session missing: $sid"
  print -r -- "ADL session: $sid"
  print -r -- "Root: $PWD"
  print -r -- "Pin: $(env_get "$sf" ADL_PIN)"
  print -r -- "Status: $(env_get "$sf" ADL_STATUS)"
  [[ -n "$(env_get "$sf" ADL_DEV_TERMINAL_ID || true)" ]] && print -r -- "Dev: connected" || print -r -- "Dev: not connected"
  print -r -- "Active run: $(env_get "$sf" ADL_ACTIVE_RUN || true)"
}

case "${1:-}" in
  architect)
    shift
    case "${1:-}" in
      start) shift; start_architect "${1:-}" ;;
      send-dev) shift; send_dev "$@" ;;
      *) die "Usage: adl architect start [--new] | send-dev --prompt-file <path>" ;;
    esac
    ;;
  dev)
    shift
    case "${1:-}" in
      connect) shift; connect_dev "$@" ;;
      notify) notify_dev ;;
      *) die "Usage: adl dev connect <pin> [--replace] | notify" ;;
    esac
    ;;
  status)
    status_cmd
    ;;
  *)
    die "Usage: adl architect ... | dev ... | status"
    ;;
esac
```

- [ ] **Step 4: Run CLI state test**

Run:

```bash
chmod +x scripts/adl
./tests/cli_state_test.sh
```

Expected: exits `0`.

## Task 5: Skill Files

**Files:**
- Create: `skills/adl/SKILL.md`
- Create: `skills/adl-connect/SKILL.md`

- [ ] **Step 1: Create Architect skill**

Create `skills/adl/SKILL.md`:

```markdown
---
name: adl
description: Invoke as adl for the Architect side of the Architect-Developer Loop. Use when starting or resuming an ADL session, sending scoped work to Dev, reviewing Dev reports, or passing follow-up work back to Dev.
---

# ADL Architect

You are the Architect in an Architect-Developer Loop.

The CLI is authoritative:

```text
/Users/liadgoren/.codex/skills/adl/scripts/adl
```

## Start Or Resume

When invoked as `$adl`, run:

```text
/Users/liadgoren/.codex/skills/adl/scripts/adl architect start
```

When invoked as `$adl new`, run:

```text
/Users/liadgoren/.codex/skills/adl/scripts/adl architect start --new
```

## Send Work To Dev

When you have a Dev handoff or follow-up:

1. Do not print the full Dev prompt in chat.
2. Ensure `.adl/staging/` exists.
3. Write the full prompt to `.adl/staging/<timestamp>-dev-prompt.md`.
4. Run:

```text
/Users/liadgoren/.codex/skills/adl/scripts/adl architect send-dev --prompt-file <path>
```

5. Tell the user only a short status such as `Passing this to the developer...`.

## Review Dev Reports

When notified with `Developer's Report:`, read the report file and verify repo state directly before approving or sending a follow-up. Do not accept the report alone as proof.
```

- [ ] **Step 2: Create Dev connect skill**

Create `skills/adl-connect/SKILL.md`:

```markdown
---
name: adl-connect
description: Invoke as adl-connect for the Developer side of the Architect-Developer Loop. Use with a pin from the Architect to connect or reconnect this Codex session as Dev.
---

# ADL Dev Connect

You are the Developer in an Architect-Developer Loop.

The CLI is authoritative:

```text
/Users/liadgoren/.codex/skills/adl/scripts/adl
```

When invoked as `$adl-connect <pin>`, run:

```text
/Users/liadgoren/.codex/skills/adl/scripts/adl dev connect <pin>
```

When invoked as `$adl-connect <pin> --replace`, run:

```text
/Users/liadgoren/.codex/skills/adl/scripts/adl dev connect <pin> --replace
```

After connecting, read the printed `dev-brief.md`. For every `Architect's Request:`, read the requested `dev-prompt.md`, execute only that scope, write `dev-report.md`, and run:

```text
/Users/liadgoren/.codex/skills/adl/scripts/adl dev notify
```
```

- [ ] **Step 3: Verify skill files exist**

Run:

```bash
test -f skills/adl/SKILL.md
test -f skills/adl-connect/SKILL.md
```

Expected: both commands exit `0`.

## Task 6: Full Test And Install Dry Run

**Files:**
- Modify only if tests expose issues: `.install.sh`, `scripts/adl`, `scripts/ghostty-macos`, `skills/adl/SKILL.md`, `skills/adl-connect/SKILL.md`

- [ ] **Step 1: Run all automated tests**

Run:

```bash
./tests/run.sh
```

Expected:

```text
Running cli_state_test.sh
Running ghostty_adapter_test.sh
Running install_test.sh
All tests passed.
```

- [ ] **Step 2: Verify no Python, jq, or repo-local PATH assumption was added**

Run:

```bash
rtk rg -n 'python|jq|/opt/homebrew|/usr/local|env bash|#!/bin/bash' . --glob '!docs/**'
rtk rg -n '(^|[;&|[:space:]])(dirname|cat|mkdir|cp|mv|rm|awk|grep|sed|find|chmod)[[:space:]]' .install.sh scripts/adl scripts/ghostty-macos
```

Expected: no matches. Runtime scripts should use zsh-native path handling or command variables such as `$CAT`, `$MKDIR`, and `$AWK`.

- [ ] **Step 3: Run installer against temporary skills dir**

Run:

```bash
ADL_CODEX_SKILLS_DIR="$(mktemp -d)" ./.install.sh
```

Expected: prints `Installed ADL framework 0.1.0 into <temp-dir>` and exits `0`.

- [ ] **Step 4: Inspect git status**

Run:

```bash
rtk git status --short --untracked-files=all
```

Expected: only intended project files are untracked/modified. No `.adl/` runtime state should be tracked.

## Self-Review Notes

Spec coverage:

- Global skill install, installer backup, marker, and rollback are covered by Task 2.
- Ghostty AppleScript spike and dry-run transport are covered by Task 3.
- `.adl` state, sessions, active sessions, new sessions, runs, supersede, notify, and status are covered by Task 4.
- Skills and absolute path behavior are covered by Task 5.
- End-to-end shell-only verification is covered by Task 6.

Placeholder scan:

- No placeholder markers or unspecified implementation steps remain.

Type/name consistency:

- CLI names match the spec: `architect start`, `architect start --new`, `architect send-dev --prompt-file`, `dev connect`, `dev connect --replace`, `dev notify`, and `status`.
