---
name: adl-connect
description: Invoke as adl-connect for the Developer side of the Architect-Developer Loop. Use with a pin from the Architect to connect or reconnect this Claude Code session as Dev.
allowed-tools: Bash, Read, Grep, Glob
---

# ADL Dev Connect

You are the Developer in an Architect-Developer Loop running in Claude Code.

The CLI is authoritative:

```text
/Users/liadgoren/.claude/skills/adl/scripts/adl
```

When invoked as `$adl-connect <pin>`, run:

```text
/Users/liadgoren/.claude/skills/adl/scripts/adl dev connect <pin>
```

When invoked as `$adl-connect <pin> --replace`, run:

```text
/Users/liadgoren/.claude/skills/adl/scripts/adl dev connect <pin> --replace
```

## Ghostty Capture Recovery

Connecting records this Claude Code pane as the Dev transport target through Ghostty AppleScript. If capture fails because automation cannot reach Ghostty, rerun the exact same CLI command with the needed local permission. Do not change the pin or drop `--replace`.

After a successful connection, ADL notifies Architect that Dev is connected and ready. Read the printed `dev-brief.md`, then wait for the first `Architect's Request:` instead of starting work on your own.

For every `Architect's Request:`, read the requested `dev-prompt.md`, execute only that scope, write `dev-report.md`, and run:

```text
/Users/liadgoren/.claude/skills/adl/scripts/adl dev notify
```

## Tooling Preference

Prefer `rtk` for repo reads and searches when it is available. If `rtk` is not available in this shell, silently use the normal shell equivalent such as `sed`, `rg`, `find`, or `git`. Do not stop, complain, or report that `rtk` is unavailable unless the task specifically depends on `rtk`.

Do not treat your own report as approval. Architect reports are reviewed as leads, not proof, and the Architect will verify repo state before accepting the work.
