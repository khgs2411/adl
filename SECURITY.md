# Security Policy

## Supported Versions

ADL is pre-1.0. Security fixes are expected to land on the default branch until release branches exist.

## Reporting A Vulnerability

Please report security issues privately through GitHub private vulnerability reporting for this repository. Maintainers must enable that GitHub feature before public launch.

If private vulnerability reporting is not available yet, do not open a public issue with exploit details. Open a minimal public issue asking for a private security contact, or contact a maintainer through an existing private channel if one has been provided.

Include:

- affected command or skill
- operating system and terminal
- impact
- reproduction steps
- whether local `.adl/` state, prompts, or reports contain sensitive data

Do not include secrets, private prompts, repository credentials, or full `.adl/` runtime state unless a maintainer explicitly asks for a minimized sample.

## Local State

ADL stores per-repository runtime state in `.adl/`. Treat that directory as local operational data. It can contain handoff prompts, developer reports, and review context.
