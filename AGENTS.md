# Repository Guidelines

## Project Structure & Module Organization

This repository contains the ADL shell protocol for coordinating Architect and Developer AI sessions.

- `scripts/` holds executable shell scripts: `adl`, `adl-reset`, and `ghostty-macos`.
- `skills/` contains Codex skill definitions installed into `~/.codex/skills`.
- `skills-claude/` contains Claude Code skill definitions installed into `~/.claude/skills`.
- `tests/` contains zsh integration and behavior tests. Shared helpers live in `tests/assert.sh`.
- `docs/specs/` and `docs/superpowers/plans/` contain design and implementation planning artifacts.
- `.install.sh` installs or updates runtime skills and scripts.

Runtime state is created per working directory in `.adl/`; never commit it.

## Build, Test, and Development Commands

- `./tests/run.sh` runs every `tests/*_test.sh` script.
- `./.install.sh` installs or reinstalls the current ADL skills and scripts for Codex and Claude Code.
- `./.install.sh --update` is a compatibility alias for reinstalling the current ADL version without bumping the product version.
- `./.install.sh --patch|--minor|--major` bumps the root `VERSION` file and reinstalls.
- `./.install.sh --codex --update` updates only the Codex runtime.
- `./.install.sh --claude --update` updates only the Claude Code runtime.
- `adl doctor` checks local `.adl/` state and installed framework metadata.

Use `rtk` wrappers where available, for example `rtk read README.md` or `rtk rg VERSION`. Treat `VERSION` as release-owned; it is protected by `.github/CODEOWNERS`.

## Coding Style & Naming Conventions

Scripts are written for `zsh` and should start with:

```zsh
#!/bin/zsh
set -euo pipefail
```

Prefer small shell functions, uppercase constants such as `VERSION`, and kebab-case executable names such as `adl-reset`. Keep comments minimal. Avoid broad structural rewrites unless the protocol contract changes.

## Testing Guidelines

Tests are shell scripts named `*_test.sh` under `tests/`. Add focused tests near changed behavior, and reuse `tests/assert.sh` for assertions. Run `./tests/run.sh` after edits. Installation tests should use temporary skill directories, not real user skill paths.

## Commit & Pull Request Guidelines

Recent history uses concise imperative commit subjects, for example `Bump ADL installer and runtime script to version 0.4.6`. Prefer conventional commit style when practical, such as `fix: handle stale ADL state`.

Pull requests should include intent, changed protocol surface, test evidence, and install/update impact. Link relevant specs or plans from `docs/` when applicable. Do not commit generated `.adl/` state.

## Agent-Specific Instructions

Respect the core invariant from `README.md`: skills are intent, CLI is authority, `.adl` is truth, and Ghostty is transport. Architect approval is a human review verdict; tests and Dev reports are evidence, not approval.
