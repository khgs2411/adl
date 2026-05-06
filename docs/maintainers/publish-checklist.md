# Maintainer Publish Checklist

This checklist prepares the local ADL project for public GitHub publication without mutating remote state from the repo itself.

## Local Repository

- Confirm `.adl/` is ignored by git.
- Review `README.md`, `LICENSE`, `NOTICE`, `CONTRIBUTING.md`, and `SECURITY.md`.
- Review GitHub issue and pull request templates under `.github/`.
- Run `rtk git status --short --untracked-files=all`.
- Commit only intentional publication files.

## Create Remote

- Create a GitHub repository named `adl`.
- Do not initialize the remote with a README, license, or gitignore if the local repo already has them.
- Add the remote locally:

```sh
git remote add origin git@github.com:<owner>/adl.git
```

## Push Default Branch

- Keep `master` as the default/root branch.
- Push and set upstream:

```sh
git push -u origin master
```

- Set GitHub's default branch to `master` if needed.

## Protect Master

Enable a branch protection ruleset for `master`:

- require pull request review before merging
- require status checks once CI exists
- block normal direct pushes to `master`
- block force pushes
- block deletion
- require linear history if that matches maintainer preference
- allow administrator or maintainer bypass for recovery, matching the requested admin-bypass governance stance

Record the chosen rules in repository settings or maintainer notes after publication.

## Security Reporting

- Enable GitHub private vulnerability reporting before public launch.
- If GitHub private vulnerability reporting will not be used, replace the SECURITY.md guidance with a concrete private security contact before publication.

## Follow-Up Product Work

- Define a terminal transport adapter contract separate from `scripts/ghostty-macos`.
- Document adapter detection and diagnostics.
- Investigate terminal support beyond Ghostty.
- Investigate Linux and Windows runtime layers.
