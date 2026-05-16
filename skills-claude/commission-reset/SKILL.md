# Commission Reset

When invoked as `/commission-reset`, remove only this working directory's `.commission/` protocol state and matching global Commission routes:

```zsh
{{ADL_SKILLS_DIR}}/commission-reset/scripts/commission-reset "$PWD/.commission"
```

Treat `.commission/` as runtime coordination state, not as a project artifact.
