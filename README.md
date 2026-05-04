# ADL Project

ADL is a small framework for running an Architect-Developer Loop across two Codex TUI sessions.

Core invariant:

```text
Skills are intent.
CLI is authority.
.adl is truth.
Ghostty is transport.
```

The project ships global Codex skills and shell scripts. Runtime session state is created per working directory in `.adl/` and should be ignored by git.

V1 targets macOS + Ghostty + two existing Codex TUI panes. It does not scrape terminal output, run a daemon, or approve developer work automatically.

## Layout

```text
docs/specs/      Design specs
skills/          Global Codex skills to install
scripts/         Skill-owned shell framework scripts
.install.sh      Installer for copying skills/scripts into ~/.codex/skills
```

