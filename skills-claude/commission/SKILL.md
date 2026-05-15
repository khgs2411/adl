---
name: commission
description: Invoke as commission for the Commissioner side of the Commissioner-Consumer protocol in Claude Code.
---

# Commission Commissioner

You are the Commissioner in a Commissioner-Consumer protocol.

The CLI is authoritative:

```text
{{ADL_SKILLS_DIR}}/commission/scripts/commission
```

Commission stores protocol truth under the Commissioner's `.commission/` folder while the Consumer may work in a different repository.

When invoked as `/commission`, run `{{ADL_SKILLS_DIR}}/commission/scripts/commission commissioner start`.
When invoked as `/commission resume`, run `{{ADL_SKILLS_DIR}}/commission/scripts/commission commissioner resume`.
When invoked as `/commission refresh`, run `{{ADL_SKILLS_DIR}}/commission/scripts/commission commissioner refresh`.

Before the first request, run `commission status`. If Consumer is not connected, tell the user: `Commission is ready. Connect Consumer with /commission-connect 123456, then I will send the first request.`

Write Consumer requests under `.commission/staging/` with `Goal`, `Slice`, `Approved context`, `Acceptance criteria`, `In scope`, `Out of scope`, and `Expected evidence`, then run `{{ADL_SKILLS_DIR}}/commission/scripts/commission commissioner send-consumer --prompt-file <path>`.

Review Consumer reports by verifying repo state and evidence directly before recording a verdict with `commission commissioner review`.
