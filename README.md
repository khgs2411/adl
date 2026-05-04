# ADL Project

ADL is a small framework for running an Architect-Developer Loop across two AI terminal sessions.

Core invariant:

```text
Skills are intent.
CLI is authority.
.adl is truth.
Ghostty is transport.
```

The project ships Codex and Claude Code skills plus shell scripts. Runtime session state is created per working directory in `.adl/` and should be ignored by git.

V1 targets macOS + Ghostty + two existing Codex or Claude Code panes. It does not scrape terminal output, run a daemon, or approve developer work automatically.

Install or update both Codex and Claude Code skills:

```text
./.install.sh
./.install.sh --update
./.install.sh --update --minor
./.install.sh --update --major
```

Limit installation to one runtime:

```text
./.install.sh --codex --update
./.install.sh --claude --update
```

Every update bumps the project version first. `--update` bumps patch by default; `--minor` and `--major` select larger version bumps.

Useful local diagnostics:

```text
adl doctor
adl doctor ghostty architect
adl doctor ghostty dev
```

`adl doctor` is read-only. It reports the local `.adl/` session state, installed ADL marker metadata, and Ghostty adapter path without scraping terminal output.

## Layout

```text
docs/specs/      Design specs
skills/          Codex skills to install into ~/.codex/skills
skills-claude/   Claude Code skills to install into ~/.claude/skills
scripts/         Skill-owned shell framework scripts
.install.sh      Installer for copying skills/scripts into the selected skills dir
```
