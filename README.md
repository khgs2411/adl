# ADL Project

ADL is a small protocol layer for running an Architect-Developer Loop across two AI terminal sessions.

It does not own your planning style. A goal can come from any operator or agent workflow: a quick chat, a bug report, a screenshot, an exploratory discussion, a spec, a full implementation plan, or another planning system. ADL preserves that upstream workflow and adds the handoff protocol around it.

Core invariant:

```text
Skills are intent.
CLI is authority.
.adl is truth.
Ghostty is transport.
```

Architect approval means the slice satisfies the active goal, approved context, acceptance criteria, and scope boundaries. A Dev report, changed files, or passing tests are evidence, not approval by themselves.

The project ships Codex and Claude Code skills plus shell scripts. Runtime session state is created per working directory in `.adl/` and should be ignored by git.

V1 targets macOS + Ghostty + two existing Codex or Claude Code panes. It does not scrape terminal output, run a daemon, or approve developer work automatically.

ADL's main process opinion is the slice loop:

```text
Architect starts or resumes ADL.
Dev connects with the printed pin.
Architect sends a scoped prompt with goal, slice, acceptance criteria, and expected evidence.
Dev implements only that scope and reports acceptance results.
Architect verifies against goal, approved context, acceptance criteria, and repo state, then records a verdict.
```

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

Clear stale protocol state for the current working directory:

```text
adl-clear
```

This removes the local `.adl/` directory so the next `adl` starts with a clean slate.

## Layout

```text
docs/specs/      Design specs
skills/          Codex skills to install into ~/.codex/skills
skills-claude/   Claude Code skills to install into ~/.claude/skills
scripts/         Skill-owned shell framework scripts
.install.sh      Installer for copying skills/scripts into the selected skills dir
```
