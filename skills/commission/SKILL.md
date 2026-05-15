---
name: commission
description: Invoke as commission for the Commissioner side of the Commissioner-Consumer protocol. Use to start, resume, refresh, send scoped requests to Consumer, and review Consumer reports.
---

# Commission Commissioner

You are the Commissioner in a Commissioner-Consumer protocol.

The CLI is authoritative:

```text
{{ADL_SKILLS_DIR}}/commission/scripts/commission
```

Commission is a protocol layer for delegating scoped work to another agent that may be operating in a different repository. The Commissioner's current working directory owns the protocol truth under `.commission/`; Consumer work may happen elsewhere, but requests, reports, reviews, and logs stay in the Commissioner's folder.

## Start, Resume, Or Refresh

When invoked as `$commission`, run:

```text
{{ADL_SKILLS_DIR}}/commission/scripts/commission commissioner start
```

When invoked as `$commission resume`, run:

```text
{{ADL_SKILLS_DIR}}/commission/scripts/commission commissioner resume
```

When invoked as `$commission refresh`, run:

```text
{{ADL_SKILLS_DIR}}/commission/scripts/commission commissioner refresh
```

Before the first request, run `commission status`. If Consumer is not connected, tell the user with the actual pin:

```text
Commission is ready. Connect Consumer with $commission-connect 123456, then I will send the first request.
```

## Send Requests

Write each Consumer request under `.commission/staging/` and include `Goal`, `Slice`, `Approved context`, `Acceptance criteria`, `In scope`, `Out of scope`, and `Expected evidence`.

Then run:

```text
{{ADL_SKILLS_DIR}}/commission/scripts/commission commissioner send-consumer --prompt-file <path>
```

Use Commissioner and Consumer language in all user-facing text. Review Consumer reports as evidence, not approval; verify files, diffs, commands, repo state, and acceptance criteria before recording a verdict.

Record reviews with:

```text
{{ADL_SKILLS_DIR}}/commission/scripts/commission commissioner review --verdict accepted|accepted-with-notes|passed-back|blocked --review-file <path>
```
