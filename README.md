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

## Commission

Commission is a sibling protocol for delegating work on the Commissioner's repository to a Consumer that may currently be in another directory. The key invariant is that the Consumer entry cwd is not the implementation target.

Commission distinguishes three paths:

- Commissioner root: where `$commission` starts and where `.commission/` lives.
- Target repo: the Commissioner's git root, or the Commissioner cwd when there is no git root.
- Consumer entry cwd: where `$commission-connect <pin>` is invoked; it is only a reconnect and notify routing anchor.

The Commissioner repository owns all requests, reports, reviews, and logs. The Consumer's unrelated repository does not receive protocol truth state.

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

Install or reinstall both Codex and Claude Code skills:

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

Limit installation to one runtime:

```sh
./.install.sh --codex --update
./.install.sh --claude --update
```

Plain `./.install.sh` is the normal reinstall path. `--update` is accepted as a compatibility alias and also only reinstalls the current ADL version. Product versioning is separate and uses the root `VERSION` file.

Release maintainers can explicitly bump the product version and reinstall in one step:

```sh
./.install.sh --patch
./.install.sh --minor
./.install.sh --major
```

The `VERSION` file is protected by `.github/CODEOWNERS`; configure branch protection to require Code Owner review so version bumps cannot merge without maintainer approval.

The installer also installs Commission skills and scripts:

```text
$commission
$commission-connect <pin>
$commission-reset
```

Existing unrelated skills named `commission`, `commission-connect`, or `commission-reset` are backed up before replacement unless they have ADL Project managed markers.

## Use

Invoke the installed Architect skill from the repository you want ADL to manage.

| Intent | Codex | Claude Code | CLI |
| --- | --- | --- | --- |
| Start a fresh Architect session | `$adl` | `/adl` | `adl architect start` |
| Resume existing Architect session state | `$adl resume` | `/adl resume` | `adl architect resume` |
| Set this pane as Architect for the active session | `$adl refresh` | `/adl refresh` | `adl architect refresh` |
| Reset local ADL state | `$adl-reset` | `/adl-reset` | `adl-reset "$PWD/.adl"` |

Plain `$adl` starts fresh on purpose. Use resume only when you explicitly want to reuse the existing `.adl/` session, active run, reports, and pin.

### Architect

```text
$adl
```

```text
/adl
```

If you need the raw CLI:

```sh
adl architect start
adl architect resume
adl architect refresh
```

`resume` means state continuity. `refresh` means transport repair: keep the session, but recapture the current pane as Architect.

### Developer

Connect the Developer pane with the printed pin:

```text
$adl-connect <pin>
/adl-connect <pin>
```

If you need the raw CLI:

```sh
adl dev connect <pin>
```

If the previous Developer pane should be replaced, Dev takes the Dev slot for the existing session:

```text
$adl-connect <pin> --replace
/adl-connect <pin> --replace
```

Raw CLI:

```sh
adl dev connect <pin> --replace
```

### Diagnostics

Check local state and installed runtime metadata:

```sh
adl doctor
adl doctor ghostty architect
adl doctor ghostty dev
```

Reset stale protocol state for the current working directory:

```sh
adl-reset "$PWD/.adl"
```

`adl doctor` is read-only. `adl-reset` removes only the current working directory's `.adl/` directory so the next `$adl` starts clean.

### Commission Usage

Start Commission from the repository that should receive the work:

```text
$commission
/commission
```

Raw CLI:

```sh
commission commissioner start
```

Connect the Consumer from any directory:

```text
$commission-connect <pin>
/commission-connect <pin>
```

Raw CLI:

```sh
commission consumer connect <pin>
```

The connect output prints the target repo, pending request path, report path, and notify command. The Consumer must implement in the printed target repo.

Commissioner handoffs are sent from `.commission/staging/`:

```sh
commission commissioner send-consumer --prompt-file .commission/staging/request.md
```

Consumer reports are written under the Commissioner's `.commission/sessions/.../runs/.../consumer-report.md`, then sent with:

```sh
commission consumer notify
```

`consumer notify` first checks the Consumer route for the current cwd, then falls back to local `.commission/`. This prevents an unrelated local `.commission/` in the Consumer entry cwd from stealing the notification.

Diagnostics and reset:

```sh
commission status
commission doctor
commission doctor ghostty commissioner
commission doctor ghostty consumer
commission-reset "$PWD/.commission"
```

`commission-reset` removes only the current directory's `.commission/` and matching global routes for that Commissioner root.

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
