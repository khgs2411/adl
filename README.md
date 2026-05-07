# adl

ADL is a small shell protocol for running an Architect-Developer Loop across two AI terminal sessions.

It gives an Architect session and a Developer session a shared handoff contract: the Architect sends a scoped request, the Developer implements only that slice, and the Architect verifies the result against the goal, context, acceptance criteria, and repository state.

ADL does not replace your planning style. A goal can come from a quick chat, a bug report, a screenshot, a spec, a full implementation plan, or another planning system. ADL preserves that upstream workflow and adds the operational loop around it.

## Why ADL Exists

AI coding sessions are useful, but long-lived work breaks down when authority is unclear. ADL keeps the roles explicit:

```text
Skills are intent.
CLI is authority.
.adl is truth.
Ghostty is transport.
```

That means:

- Skills describe how the Architect and Developer should behave.
- The `adl` CLI owns session state, handoffs, notifications, and reports.
- `.adl/` is the local source of truth for the active working directory.
- Ghostty is the current terminal transport adapter.

Developer reports, changed files, and passing tests are evidence. They are not approval. Architect approval is a human review verdict for the active slice.

## Current Support

ADL V1 targets:

- macOS
- Ghostty
- two existing Codex or Claude Code terminal panes
- shell-based coordination with no daemon

ADL does not scrape arbitrary terminal output, approve work automatically, or create remote repositories for you.

The Ghostty/macOS dependency is a transport limitation, not a product boundary. The protocol is intentionally shaped so future adapters can support other terminals and operating systems.

## How The Loop Works

```text
Architect starts fresh ADL sessions, explicitly resumes existing sessions, or refreshes the Architect pane.
Dev connects with the printed pin.
Architect sends a scoped prompt with goal, slice, acceptance criteria, and expected evidence.
Dev implements only that scope and writes a compact report.
Architect verifies the result and records a verdict.
```

The working directory owns the runtime state. Each repository gets its own `.adl/` directory, which should stay ignored by git.

## Install

Install or update both Codex and Claude Code skills:

```sh
./.install.sh
./.install.sh --update
```

By default, the installer writes Codex skills to `$HOME/.codex/skills` and Claude Code skills to `$HOME/.claude/skills`. The installed skill text is rewritten to call the CLI from the actual install directory.

Override either target when needed:

```sh
ADL_CODEX_SKILLS_DIR=/path/to/codex/skills ./.install.sh --codex
ADL_CLAUDE_SKILLS_DIR=/path/to/claude/skills ./.install.sh --claude
```

Select the version bump during update:

```sh
./.install.sh --update --minor
./.install.sh --update --major
```

Limit installation to one runtime:

```sh
./.install.sh --codex --update
./.install.sh --claude --update
```

Every update bumps the project version first. `--update` bumps patch by default.

## Use

In Codex, invoke the installed Architect skill from the repository you want ADL to manage:

```text
$adl
```

In Claude Code, invoke the corresponding skill:

```text
/adl
```

The skill runs the installed `adl` CLI. You can also run that CLI directly if its install directory is on your path.

Start a fresh Architect session:

```sh
adl architect start
```

Resume an existing Architect session only when you mean to reuse its state:

```sh
adl architect resume
```

Refresh the current pane as Architect for the active session:

```sh
adl architect refresh
```

Connect the Developer pane with the printed pin. Codex uses `$adl-connect`; Claude Code uses `/adl-connect`.

```sh
adl-connect <pin>
```

If the previous Developer pane should be replaced:

```sh
adl-connect <pin> --replace
```

Check local state and installed runtime metadata:

```sh
adl doctor
adl doctor ghostty architect
adl doctor ghostty dev
```

Clear stale protocol state for the current working directory:

```sh
adl-reset
```

`adl doctor` is read-only. `adl-reset` removes the local `.adl/` directory so the next `adl` starts clean.

## Repository Layout

```text
scripts/          Shell entrypoints and transport adapter
skills/           Codex skills installed into ~/.codex/skills
skills-claude/    Claude Code skills installed into ~/.claude/skills
tests/            zsh integration and behavior tests
docs/specs/       Design specs
docs/superpowers/ Implementation plans
.install.sh       Installer and updater
```

## Roadmap

Near-term publication work:

- create the GitHub remote as `adl`
- push and keep `master` as the default branch
- protect `master` so normal work goes through pull requests while administrators or maintainers can bypass for recovery

Transport and platform work:

- split the terminal transport contract from `scripts/ghostty-macos`
- add adapter discovery and diagnostics
- investigate native terminal adapters beyond Ghostty
- investigate Linux and Windows support layers

See [docs/maintainers/publish-checklist.md](docs/maintainers/publish-checklist.md) for the maintainer checklist.

## Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md) before proposing changes. Keep protocol changes small, evidence-backed, and covered by focused zsh tests.

## Security

Read [SECURITY.md](SECURITY.md) for reporting guidance. Please do not publish sensitive local `.adl/` state in public issues.

## License

Apache License 2.0. See [LICENSE](LICENSE) and [NOTICE](NOTICE).

Apache-2.0 keeps the open-source core permissive and patent-aware. It does not prevent future paid proprietary add-ons or separately licensed modules.
