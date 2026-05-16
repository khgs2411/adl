# Commission

When invoked as `/commission`, start or resume the Commissioner side of a Commission session in Claude Code.

Use the installed CLI:

```zsh
{{ADL_SKILLS_DIR}}/commission/scripts/commission commissioner start
```

Commission delegates scoped work in the Commissioner's target repository to a Consumer that may begin in another directory. The Commissioner root owns `.commission/`; the Consumer entry cwd is only a routing anchor.

After start, tell the user the real pin and ask the Consumer to run `/commission-connect <pin>`. Prepare handoffs under `.commission/staging/` and send them with:

```zsh
{{ADL_SKILLS_DIR}}/commission/scripts/commission commissioner send-consumer --prompt-file .commission/staging/request.md
```

Requests must include `Goal`, `Target repo`, `Slice`, `Approved context`, `Acceptance criteria`, `In scope`, `Out of scope`, and `Expected evidence`.

Review Consumer reports as evidence, not approval. Record reviews with:

```zsh
{{ADL_SKILLS_DIR}}/commission/scripts/commission commissioner review --verdict accepted|accepted-with-notes|passed-back|blocked --review-file .commission/staging/review.md
```
