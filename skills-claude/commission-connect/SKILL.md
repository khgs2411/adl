# Commission Connect

When invoked as `/commission-connect <pin>` in Claude Code, connect as the Consumer:

```zsh
{{ADL_SKILLS_DIR}}/commission/scripts/commission consumer connect <pin>
```

After connection, work only in the printed `Target repo`. Do not treat the Consumer entry cwd as the implementation target unless it is also the target repo. The entry cwd is only used for reconnect and `commission consumer notify` routing.

If a pending request is printed, read that request, implement only its scope in the target repo, then write the printed `consumer-report.md` path.

Notify the Commissioner with:

```zsh
{{ADL_SKILLS_DIR}}/commission/scripts/commission consumer notify
```
