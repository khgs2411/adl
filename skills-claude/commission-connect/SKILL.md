# Commission Connect

When invoked as `/commission-connect <pin>` in Claude Code, connect as the Consumer:

```zsh
{{ADL_SKILLS_DIR}}/commission/scripts/commission consumer connect <pin>
```

After connection, use the printed `Target repo` as the authoritative repository for the request. The Consumer entry cwd is only a routing anchor for reconnect and `commission consumer notify`; do not treat it as the work target unless it is also the printed target repo.

If a pending request is printed, read that request from the target repo and handle it according to that repo's own instructions and operating model. Commission transports the requested outcome, scope, acceptance criteria, expected evidence, and target repo; it does not decide whether the target repo expects direct implementation, orchestration through its own project system, or another local workflow. For example, an orchestrator repo may require creating or updating a work card and reviewing downstream evidence, while a simple dev repo may expect direct edits.

When the request is resolved or blocked according to the target repo's model, write the printed `consumer-report.md` path.

Notify the Commissioner with:

```zsh
{{ADL_SKILLS_DIR}}/commission/scripts/commission consumer notify
```
