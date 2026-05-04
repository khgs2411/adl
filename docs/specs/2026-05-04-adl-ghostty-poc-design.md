# ADL Ghostty POC Design

## Purpose

ADL automates the existing two-terminal Architect-Developer Loop without changing its authority model. The Architect remains responsible for planning, scoping, reviewing, and approving. The Developer implements scoped handoffs and reports back.

The framework removes manual copy/paste by using project-local file payloads and Ghostty wake-up messages.

## Core Invariant

```text
Skills are intent.
CLI is authority.
.adl is truth.
Ghostty is transport.
```

## Scope

V1 supports:

- macOS + Ghostty.
- Two existing Codex TUI panes.
- Global Codex skills installed from this project by `.install.sh`.
- Shell scripts only, using a fixed zsh shebang.
- Runtime state in the current working directory under `.adl/`.
- File-first handoffs and reports.
- Explicit notify commands.
- Dev reconnect and replacement.
- Minimal status output.

V1 does not support:

- Terminal output scraping.
- Daemons or polling.
- Automatic approval.
- Queue semantics.
- Cross-terminal adapters beyond Ghostty.
- Repo-root or branch detection.
- Automatic `.gitignore` edits.
- Python, `jq`, Homebrew-only dependencies, or PATH assumptions.

## Project And Install Layout

This repository is the source project for the framework. Runtime use happens through globally installed Codex skills and skill-owned scripts.

Source layout:

```text
skills/
  adl/
    SKILL.md
  adl-connect/
    SKILL.md
scripts/
  adl
  ghostty-macos
.install.sh
```

These source paths are to be created by the implementation. Until `.install.sh` is run, the installed runtime paths may be absent.

Install target:

```text
/Users/liadgoren/.codex/skills/adl/
  SKILL.md
  scripts/
    adl
    ghostty-macos
/Users/liadgoren/.codex/skills/adl-connect/
  SKILL.md
```

`.install.sh` copies project files into the install target. The runtime skills invoke the CLI by absolute path:

```text
/Users/liadgoren/.codex/skills/adl/scripts/adl
```

Install safety rules:

- `.install.sh` must be idempotent.
- `.install.sh` must detect an existing `/Users/liadgoren/.codex/skills/adl/` directory.
- If the existing directory does not contain an ADL framework marker file, `.install.sh` must back it up before replacing it.
- Backups are stored outside the target directory under `/Users/liadgoren/.codex/skills/.adl-project-backups/<timestamp>/`.
- The backup must include the full existing `adl` skill directory.
- `.install.sh` must print the rollback command/path after creating a backup.
- `.install.sh` must not delete backup directories.
- If the target already contains the ADL framework marker for the same version, `.install.sh` may overwrite the installed ADL files in place.

Framework marker:

```text
/Users/liadgoren/.codex/skills/adl/.adl-framework
```

The marker contains the installed ADL framework version and source project path.

## Runtime State

ADL stores runtime state in the directory where `$adl` is invoked:

```text
.adl/
  active-session
  sessions/
    <session-id>/
      session.env
      dev-brief.md
      runs/
        001/
          run.env
          dev-prompt.md
          dev-report.md
```

`.adl/` is ignored by default in this project. The framework should warn if the target project does not ignore `.adl/`, but it must not edit `.gitignore` automatically in V1.

## Session Semantics

One active ADL session exists per current working directory.

`$adl` maps to:

```text
/Users/liadgoren/.codex/skills/adl/scripts/adl architect start
```

Behavior:

- Create `.adl/` if missing.
- Reuse the active session if present.
- Otherwise create a new session, generate a pin, and record Architect Ghostty transport metadata.
- Print the pin and tell the user to invoke `$adl-connect <pin>` in the Dev Codex session.

`$adl new` maps to:

```text
/Users/liadgoren/.codex/skills/adl/scripts/adl architect start --new
```

Behavior:

- Close the previous active session without deleting artifacts.
- Create a new active session.

## Dev Connection

`$adl-connect <pin>` maps to:

```text
/Users/liadgoren/.codex/skills/adl/scripts/adl dev connect <pin>
```

Rules:

- Must run from the same directory that contains the matching `.adl/` session.
- The pin identifies the ADL session.
- Ghostty terminal identity is replaceable transport metadata.
- `dev-brief.md` is created once per new ADL session.
- Reconnect must not rewrite `dev-brief.md`.
- Existing sessions keep the ADL protocol version they started with.

Replacement:

```text
$adl-connect <pin> --replace
```

This replaces the Dev transport identity, not the session history.

After reconnect, Dev is instructed to read the existing `dev-brief.md`. If a pending active run exists, Dev is shown the pending request path.

## Handoff Flow

In ADL-connected mode, the Architect does not print the full Dev prompt in chat.

Instead:

1. Architect says a short status such as `Passing this to the developer...`.
2. Architect writes the full handoff to a staging prompt file under `.adl/staging/`.
3. Architect invokes the send command with that prompt file.
4. The CLI creates the next run and copies the prompt into `dev-prompt.md`.
5. The CLI removes the staging prompt file after a successful copy.
6. Ghostty injects a short wake-up into the Dev pane.

Send command:

```text
/Users/liadgoren/.codex/skills/adl/scripts/adl architect send-dev --prompt-file <path>
```

Rules:

- `--prompt-file` is required.
- The prompt file must exist.
- The prompt file must be under the current working directory's `.adl/staging/`.
- The CLI allocates the next run ID.
- The CLI copies the prompt file to the new run's `dev-prompt.md` using atomic write behavior.
- The CLI must not echo the prompt content to stdout.
- The CLI prints only a short status, run ID, and next action.
- If Dev is not connected, the run is created and marked `pending_dev_connection`.
- If Dev is connected, the run is marked `sent_to_dev` after wake-up delivery succeeds.

Wake-up prefix:

```text
Architect's Request:
```

Payload:

```text
Read and execute:
.adl/sessions/<session-id>/runs/<run-id>/dev-prompt.md

When done, write:
.adl/sessions/<session-id>/runs/<run-id>/dev-report.md

Then notify Architect:
/Users/liadgoren/.codex/skills/adl/scripts/adl dev notify
```

Full payloads appear once in files, not duplicated in terminal chat.

## Runs

One run is created per handoff.

`send-dev` always creates a new run. If the previous active run is still pending or reportless, the CLI warns and marks the previous run as `superseded`.

V1 has no queue semantics. Dev receives only `active_run`.

Run statuses:

```text
pending_dev_connection
sent_to_dev
reported
superseded
```

A superseded run keeps `dev-prompt.md`, does not require `dev-report.md`, and is historical only.

Example `run.env`:

```sh
ADL_RUN_ID='003'
ADL_RUN_STATUS='sent_to_dev'
ADL_PROMPT_PATH='.adl/sessions/2026-05-04-132201-482913/runs/003/dev-prompt.md'
ADL_REPORT_PATH='.adl/sessions/2026-05-04-132201-482913/runs/003/dev-report.md'
ADL_CREATED_AT='2026-05-04T13:22:01+0300'
ADL_SENT_AT='2026-05-04T13:22:05+0300'
ADL_REPORTED_AT=''
ADL_SUPERSEDED_BY=''
```

## Dev Report

Dev writes structured Markdown:

```markdown
# Dev Report

Status: DONE | BLOCKED | NEEDS_CONTEXT

## Files Changed

## Verification

## Deviations

## Blockers Or Assumptions

## Notes
```

The CLI checks that `dev-report.md` exists before notify. It does not parse report semantics in V1.

## Notify Flow

Dev explicitly runs:

```text
/Users/liadgoren/.codex/skills/adl/scripts/adl dev notify
```

No daemon or poller exists.

Notify behavior:

- Infer the active run from session metadata.
- Reject if `dev-report.md` is missing.
- Print the exact expected path and report template on rejection.
- Mark the run as `reported`.
- Notify Architect via Ghostty.

Architect wake-up prefix:

```text
Developer's Report:
```

Payload:

```text
Read:
.adl/sessions/<session-id>/runs/<run-id>/dev-report.md

Review against repo state before approving or sending a follow-up.
```

## Status

V1 includes minimal status:

```text
/Users/liadgoren/.codex/skills/adl/scripts/adl status
```

It should show:

- Current working directory.
- Active session ID.
- Pin.
- Session status.
- Dev connected or not connected.
- Active run.
- Next expected action.

No separate `$adl-status` skill exists in V1.

## Metadata

V1 uses shell-readable `.env` files instead of JSON.

Example `session.env`:

```sh
ADL_SESSION_ID='2026-05-04-132201-482913'
ADL_PIN='482913'
ADL_STATUS='waiting_for_dev'
ADL_ACTIVE_RUN=''
ADL_ARCHITECT_ADAPTER='ghostty-macos'
ADL_ARCHITECT_TERMINAL_ID=''
ADL_DEV_ADAPTER=''
ADL_DEV_TERMINAL_ID=''
ADL_DEV_GENERATION='0'
ADL_VERSION='0.1.0'
```

Shell safety rules:

- Scripts must not blindly `source` `.env` files from `.adl/`.
- Scripts must parse only known `ADL_*` keys.
- Values must be single-line and must not contain shell metacharacters outside the allowed character set for that field.
- Generated values such as session IDs, pins, run IDs, statuses, timestamps, and adapter names must use constrained formats.
- State writes must use temp-file-plus-rename behavior for `.adl/active-session`, `session.env`, and `run.env`.
- Prompt and report payloads are Markdown files and are not sourced or executed.

## Ghostty Adapter

The Ghostty adapter is V1 transport only.

It should:

- Capture the currently focused Ghostty terminal when a role connects.
- Use macOS AppleScript via `osascript`.
- Store best-effort window/tab/terminal metadata returned by Ghostty's AppleScript object model.
- Send short wake-up messages to the recorded terminal using Ghostty AppleScript `input text` and `send key "enter"`.
- Treat stale terminal metadata as recoverable through reconnect.

It should not:

- Scrape terminal output.
- Parse Codex TUI state.
- Create panes in V1.

Transport spike gate:

Before the full CLI implementation, the implementation must prove the Ghostty adapter can:

1. Capture the currently focused Ghostty terminal for Architect.
2. Capture the currently focused Ghostty terminal for Dev.
3. Send `Architect's Request:` to the captured Dev terminal.
4. Send `Developer's Report:` to the captured Architect terminal.
5. Fail clearly when a captured terminal cannot be targeted.

If stored Ghostty IDs cannot be reliably re-targeted, V1 may use a simpler adapter that records enough metadata for status display and requires reconnect before every send/notify. It must still preserve the file-first `.adl` protocol.

macOS permission expectation:

- The first AppleScript send may require the user to grant automation/accessibility permission for the shell running `osascript` to control Ghostty.
- The adapter must surface permission failures as actionable errors.

## Skills

Two global Codex skills are installed:

```text
/Users/liadgoren/.codex/skills/adl/
/Users/liadgoren/.codex/skills/adl-connect/
```

Both invoke the shared CLI through absolute paths under:

```text
/Users/liadgoren/.codex/skills/adl/scripts/adl
```

The skills are natural-language entrypoints. The CLI is responsible for parsing pins, flags, state transitions, and validation.

Architect skill behavior:

- `$adl` starts or resumes the active session.
- `$adl new` creates a fresh session.
- When ready to hand work to Dev, the skill writes the full prompt to `.adl/staging/<timestamp>-dev-prompt.md`.
- The skill then runs `adl architect send-dev --prompt-file <path>` using the absolute CLI path.
- The skill must not print the full Dev prompt in chat.

Dev skill behavior:

- `$adl-connect <pin>` runs `adl dev connect <pin>`.
- `$adl-connect <pin> --replace` runs `adl dev connect <pin> --replace`.
- Dev follows `dev-brief.md`, reads request files, writes `dev-report.md`, and runs `adl dev notify`.

## Command Contract

| Command | Role | Input | Success Behavior | Failure Behavior |
| --- | --- | --- | --- | --- |
| `adl architect start` | Architect | current cwd | Create or resume active session; create `.adl/` if needed; record Architect transport; print pin/status. | Print actionable error if `.adl` cannot be created or transport capture fails. |
| `adl architect start --new` | Architect | current cwd | Mark old active session closed, create new session, print new pin/status. | Preserve old artifacts on failure. |
| `adl architect send-dev --prompt-file <path>` | Architect | prompt file under `.adl/staging/` | Allocate run, copy prompt to `dev-prompt.md`, update active run, wake Dev if connected, remove staging prompt after copy. | Reject missing/invalid prompt file; never echo prompt; preserve staging prompt on failure. |
| `adl dev connect <pin>` | Dev | pin, current cwd | Find matching session in current `.adl/`, record Dev transport, create `dev-brief.md` only if missing, show pending active request if present. | Reject wrong cwd or unknown pin with exact next step. |
| `adl dev connect <pin> --replace` | Dev | pin, current cwd | Replace Dev transport metadata and increment generation; do not rewrite `dev-brief.md`. | Reject unknown pin or invalid session. |
| `adl dev notify` | Dev | current cwd | Infer active run, require `dev-report.md`, mark reported, wake Architect. | Reject missing session, no active run, superseded run, or missing report with exact expected path and template. |
| `adl status` | Either | current cwd | Print minimal session/run/next-action status. | Explain if no `.adl` or no active session exists. |

Exit codes:

- `0`: success.
- `1`: user/actionable validation error.
- `2`: corrupted or inconsistent `.adl` state.
- `3`: Ghostty transport failure.
- `4`: install/permission failure.

## Open Implementation Risks

- Ensure large Dev prompts can be written to file without being echoed in chat.
- Confirm whether stored Ghostty terminal IDs remain targetable after focus/tab changes; reconnect fallback is allowed.
