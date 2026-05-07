---
name: adl-reset
description: Invoke as /adl-reset when the user wants to reset the current working directory's ADL session state, remove stale .adl sessions, or force the next /adl start to use a clean slate.
allowed-tools: Bash
---

# ADL Reset

Reset ADL as local protocol state, not as a project artifact.

When invoked as `/adl-reset`, run:

```text
{{ADL_SKILLS_DIR}}/adl-reset/scripts/adl-reset "$PWD/.adl"
```

This removes only the current working directory's `.adl/` directory. Use it when old sessions, pins, active runs, staging files, or transport metadata should not be reused by the next `/adl`.

After it succeeds, the next `/adl` starts from a clean slate.
