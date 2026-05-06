# Contributing

Thanks for taking a look at ADL.

ADL is a small protocol project, so contributions should keep the authority model clear:

```text
Skills are intent.
CLI is authority.
.adl is truth.
Ghostty is transport.
```

## Development

Use a local checkout and run the shell tests before proposing behavior changes:

```sh
./tests/run.sh
```

Install local runtime updates when you need to verify skill or CLI behavior:

```sh
./.install.sh
```

Use update mode only when the change is intended to bump the installed framework version:

```sh
./.install.sh --update
```

## Change Guidelines

- Keep changes focused on one protocol surface at a time.
- Add or update tests for CLI behavior, installer behavior, and skill text contracts.
- Do not commit `.adl/` runtime state.
- Do not broaden the transport contract casually; document adapter assumptions.
- Prefer small shell functions and clear zsh over new dependencies.

## Pull Requests

Pull requests should include:

- intent
- changed protocol surface
- test evidence
- install/update impact
- any manual verification steps

Use concise imperative or conventional commit subjects when practical, such as `fix: handle stale ADL state`.

Unless a separate written agreement says otherwise, intentional contributions are submitted under the Apache License 2.0.
