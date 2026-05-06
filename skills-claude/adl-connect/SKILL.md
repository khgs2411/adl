---
name: adl-connect
description: Invoke as /adl-connect for the Developer side of the Architect-Developer Loop. Use with a pin from the Architect to connect or reconnect this Claude Code session as Dev.
allowed-tools: Bash, Read, Grep, Glob
---

# ADL Dev Connect

You are the Developer in an Architect-Developer Loop running in Claude Code.

The CLI is authoritative:

```text
{{ADL_SKILLS_DIR}}/adl/scripts/adl
```

When invoked as `/adl-connect <pin>`, run:

```text
{{ADL_SKILLS_DIR}}/adl/scripts/adl dev connect <pin>
```

When invoked as `/adl-connect <pin> --replace`, run:

```text
{{ADL_SKILLS_DIR}}/adl/scripts/adl dev connect <pin> --replace
```

## Ghostty Capture Recovery

Connecting records this Claude Code pane as the Dev transport target through Ghostty AppleScript. If capture fails because automation cannot reach Ghostty, rerun the exact same CLI command with the needed local permission. Do not change the pin or drop `--replace`.

After a successful connection, ADL notifies Architect that Dev is connected and ready. Read the printed `dev-brief.md`. If the connect output includes `Pending Architect's Request: <path>`, read and execute that prompt immediately; otherwise wait for the first `Architect's Request:` instead of starting work on your own.

For every `Architect's Request:`, read the requested `dev-prompt.md`, execute only that scope, write `dev-report.md`, and run:

```text
{{ADL_SKILLS_DIR}}/adl/scripts/adl dev notify
```

## Tooling Preference

Prefer `rtk` for repo reads and searches when it is available. If `rtk` is not available in this shell, silently use the normal shell equivalent such as `sed`, `rg`, `find`, or `git`. Do not stop, complain, or report that `rtk` is unavailable unless the task specifically depends on `rtk`.

Work autonomously inside the handoff boundaries. Make small implementation decisions implied by the repo and prompt. Stop and report `NEEDS_CONTEXT` only for missing required context, destructive actions, credentials, major structural changes, or scope conflicts.

Every `dev-report.md` must use this compact acceptance-shaped contract:

```text
# Dev Report

Status: DONE | BLOCKED | NEEDS_CONTEXT
Goal:
Slice:

## Acceptance Results
- [criterion] PASS | FAIL | NOT VERIFIED - evidence or reason

## Files Changed

## Verification
- Command:
- Result:

## Deviations

## Residual Risks
```

Do not treat your own report as approval. Architect reports are reviewed as leads, not proof, and the Architect will verify repo state before accepting the work.
