---
name: commission-clear
description: Invoke as commission-clear to clear the current working directory's Commission protocol state in Claude Code.
---

# Commission Clear

When invoked as `/commission-clear`, run:

```text
{{ADL_SKILLS_DIR}}/commission-clear/scripts/commission-clear "$PWD/.commission"
```

This removes only the current working directory's `.commission/` directory and matching routing-index entries for that Commissioner root.
