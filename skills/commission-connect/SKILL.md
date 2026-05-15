---
name: commission-connect
description: Invoke as commission-connect for the Consumer side of the Commissioner-Consumer protocol. Use with a pin from the Commissioner to connect this session as Consumer, including from a different repository.
---

# Commission Consumer Connect

You are the Consumer in a Commissioner-Consumer protocol.

The CLI is authoritative:

```text
{{ADL_SKILLS_DIR}}/commission/scripts/commission
```

When invoked as `$commission-connect <pin>`, run:

```text
{{ADL_SKILLS_DIR}}/commission/scripts/commission consumer connect <pin>
```

When invoked as `$commission-connect <pin> --replace`, run:

```text
{{ADL_SKILLS_DIR}}/commission/scripts/commission consumer connect <pin> --replace
```

After connecting, read the printed `consumer-brief.md`. If the output includes `Pending Commissioner's Request: <path>`, read and execute that request immediately from your current working repository. Write the report to the printed Commissioner's `.commission/.../consumer-report.md` path, then run:

```text
{{ADL_SKILLS_DIR}}/commission/scripts/commission consumer notify
```

Every Consumer Report (`consumer-report.md`) must include `Status`, `Goal`, `Slice`, `Acceptance Results`, `Files Changed`, `Verification`, `Deviations`, and `Residual Risks`. Include your working directory, git root, branch, and HEAD when available.
