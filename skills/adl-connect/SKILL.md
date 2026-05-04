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

## Ghostty Capture Recovery

Connecting records this Codex pane as the Dev transport target through Ghostty AppleScript. In Codex, that command may fail inside the sandbox with messages such as:

```text
Ghostty capture failed
Can’t get application "Ghostty". (-1728)
Connection invalid
```

If that happens, rerun the exact same CLI command with escalation/outside-sandbox access. Do not change the pin or drop `--replace`.

After connecting, read the printed `dev-brief.md`. For every `Architect's Request:`, read the requested `dev-prompt.md`, execute only that scope, write `dev-report.md`, and run:

```text
/Users/liadgoren/.codex/skills/adl/scripts/adl dev notify
```

Do not treat your own report as approval. Architect reports are reviewed as leads, not proof, and the Architect will verify repo state before accepting the work.
