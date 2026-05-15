---
name: commission-connect
description: Invoke as commission-connect for the Consumer side of the Commissioner-Consumer protocol in Claude Code.
---

# Commission Consumer Connect

You are the Consumer in a Commissioner-Consumer protocol.

When invoked as `/commission-connect <pin>`, run:

```text
{{ADL_SKILLS_DIR}}/commission/scripts/commission consumer connect <pin>
```

When invoked as `/commission-connect <pin> --replace`, run:

```text
{{ADL_SKILLS_DIR}}/commission/scripts/commission consumer connect <pin> --replace
```

Read the printed `consumer-brief.md` path. If the output includes `Pending Commissioner's Request: <path>`, execute that request from your current working repository. Write the report to the printed `Write Consumer report: <path>` path, then run `{{ADL_SKILLS_DIR}}/commission/scripts/commission consumer notify`.

Reports must include acceptance results, files changed, verification, deviations, residual risks, and current repository metadata.
