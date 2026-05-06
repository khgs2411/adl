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
Transport is explicit state.
```

That means:

- Skills describe how the Architect and Developer should behave.
- The `adl` CLI owns session state, handoffs, notifications, and reports.
- `.adl/` is the local source of truth for the active working directory.
- Transport adapters are captured per role and stored in `.adl/`.

Developer reports, changed files, and passing tests are evidence. They are not approval. Architect approval is a human review verdict for the active slice.

## Current Support

ADL V1 targets:

- macOS
- Ghostty
- two existing Codex or Claude Code terminal panes
- shell-based coordination with no daemon

ADL does not scrape arbitrary terminal output, approve work automatically, or create remote repositories for you.

The Ghostty/macOS dependency is a production baseline, not a product boundary. The installer detects the OS, records one operator-chosen transport per installed runtime, and the protocol stores Architect and Dev transport metadata separately after capture so a session can route handoffs and reports through different adapters.

Supported transport adapters are `ghostty-macos`, `tmux`, and `terminal-macos`. Explicit `ADL_TRANSPORT=<adapter>` overrides the installed runtime config for one command. `ADL_TRANSPORT=auto` remains available as an explicit diagnostic/setup helper, but it is not the default product path.

Experimental tmux transport is available for operators who already run both ADL panes inside tmux:

```sh
ADL_TRANSPORT=tmux adl
ADL_TRANSPORT=tmux adl-connect <pin>
```

Ghostty remains the production baseline. The tmux adapter expects existing tmux panes; ADL does not create tmux sessions or panes for you.

Experimental macOS Terminal.app transport is also available:

```sh
ADL_TRANSPORT=terminal-macos adl
ADL_TRANSPORT=terminal-macos adl-connect <pin>
```

`terminal-macos` targets Terminal.app tabs by their `tty` value and uses AppleScript through `osascript`. It is experimental, macOS-only, and may require macOS Automation permission for `osascript` to control Terminal.

Linux and WSL users should prefer `ADL_TRANSPORT=tmux` for now. ADL does not currently provide generic Windows Terminal, PowerShell, Linux GUI terminal, or raw TTY adapters.

## How The Loop Works

```text
Architect starts or resumes ADL.
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

During install, ADL detects the OS and asks you to choose a supported transport for the installed runtime. The choice is saved adjacent to that runtime's installed `adl` skill directory as `.adl-config`, not in any project `.adl/` state. Codex and Claude installs can have different configs. Reinstall or update to change the configured transport.

Conservative choices:

- macOS may offer `ghostty-macos`, `terminal-macos`, and `tmux` when available.
- Linux and WSL may offer `tmux` when `tmux` is installed.
- Windows has no generic supported GUI terminal adapter yet.

For automation or tests, pass the transport non-interactively:

```sh
./.install.sh --transport ghostty-macos
ADL_INSTALL_TRANSPORT=tmux ./.install.sh --update
```

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

Start or resume an Architect session:

```sh
adl
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
adl doctor transport architect
adl doctor transport dev
adl doctor ghostty architect
adl doctor ghostty dev
```

Clear stale protocol state for the current working directory:

```sh
adl-clear
```

`adl doctor` is read-only. `adl-clear` removes the local `.adl/` directory so the next `adl` starts clean.

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
