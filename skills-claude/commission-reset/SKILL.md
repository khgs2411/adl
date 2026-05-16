---
name: commission-reset
description: Invoke as commission-reset to remove the current working directory's Commission protocol state and matching global routes in Claude Code.
---

# Commission Reset

When invoked as `/commission-reset`, remove only this working directory's `.commission/` protocol state and matching global Commission routes:

```zsh
{{ADL_SKILLS_DIR}}/commission-reset/scripts/commission-reset "$PWD/.commission"
```

Treat `.commission/` as runtime coordination state, not as a project artifact.
