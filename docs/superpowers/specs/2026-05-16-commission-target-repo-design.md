# Commission Target Repository Protocol Design

## Purpose

Commission is a sibling protocol to ADL for delegating work on the Commissioner's repository to another agent session. The Consumer may start in any directory, including its own unrelated repository, but the commissioned work target is always the Commissioner's current repository unless the Commissioner explicitly chooses another target later.

Example: Team A owns a todo-list app and is already busy. Team A starts Commission from the todo-list repo and asks Team B to add checklist support. Team B may currently sit in `~/team-b-repo`, but the request, implementation, report, and review all concern Team A's todo-list repo.

## Non-Negotiable Invariant

Consumer entry cwd is not the implementation target.

The protocol must distinguish:

- Commissioner root: the directory where `$commission` starts and where `.commission/` lives.
- Target repo: the repository the Consumer must modify. In this version it is the Commissioner root's git root, or the Commissioner cwd when no git root exists.
- Consumer entry cwd: the directory where `$commission-connect <pin>` was invoked. This is only a routing anchor for reconnect and notify.

The Consumer must never treat its entry cwd as the work target unless it is also the target repo.

## Scope

Build a first-class Commission runtime surface parallel to ADL:

- `scripts/commission`
- `scripts/commission-reset`
- `skills/commission`, `skills/commission-connect`, `skills/commission-reset`
- matching Claude Code skills under `skills-claude/`
- installer support for Codex and Claude runtimes
- Ghostty role support for `commissioner` and `consumer`
- focused shell tests for target-repo routing, install safety, skill text, reset, and diagnostics
- README usage docs

Do not modify installed runtime skills under `~/.codex/skills` or `~/.claude/skills` directly. The install step will propagate source templates later.

## Recommended Approach

Use a separate `commission` CLI rather than folding Commission into `scripts/adl`.

This keeps ADL's current one-repo Architect/Dev contract stable while allowing Commission to use a different state model. The two scripts may share patterns, but this release should avoid a shared library refactor. The first safe goal is a small, test-backed protocol, not framework extraction.

Rejected alternatives:

- Extend `adl` with cross-repo flags. This blurs ADL's existing `.adl/` truth model and risks regressions in the current loop.
- Let Consumer own `.commission/`. This breaks the review and history model: Team A needs the request, report, and review in Team A's repo.

## Protocol Model

Commissioner starts from the target repo:

```text
$commission
commission commissioner start
```

The CLI creates `.commission/` under the Commissioner root, captures the Commissioner transport, records the target repo, creates a pin, and writes a global pin route under `~/.commission/pins/<pin>.env`.

Consumer connects from any directory:

```text
$commission-connect <pin>
commission consumer connect <pin>
```

The CLI resolves the pin to the Commissioner root, records the Consumer transport and entry cwd, writes a Consumer route under `~/.commission/consumers/<consumer-entry-key>.env`, and prints:

- Target repo
- Pending request path, when one exists
- Report path
- Notify command

The Consumer skill must then conduct all implementation work with the target repo as its working directory. The Consumer entry cwd remains useful only for `commission consumer notify` if the agent invokes notify before moving into the target repo.

Commissioner sends a request:

```text
commission commissioner send-consumer --prompt-file .commission/staging/request.md
```

Required request sections:

- `Goal`
- `Target repo`
- `Slice`
- `Approved context`
- `Acceptance criteria`
- `In scope`
- `Out of scope`
- `Expected evidence`

The CLI copies the request into the active run and notifies the Consumer. If the Consumer is not connected, the run stays pending and is printed on connect.

Consumer reports:

```text
commission consumer notify
```

The report file lives in the Commissioner root under `.commission/sessions/<session>/runs/<run>/consumer-report.md`. Notify must work from either the target repo or the Consumer entry cwd.

Notify lookup must prefer the Consumer route for the current cwd before local `.commission/`. This prevents a Consumer starting from `~/team-b-repo` with its own valid `.commission/` from notifying Team B's unrelated local session instead of Team A's commissioned run.

Commissioner reviews:

```text
commission commissioner review --verdict accepted|accepted-with-notes|passed-back|blocked --review-file .commission/staging/review.md
```

Review records are stored under the active run. A reported run is evidence, not approval.

## State Layout

Commissioner root:

```text
.commission/
  active-session
  commission.log
  staging/
  sessions/<session-id>/
    session.env
    consumer-brief.md
    runs/<run-id>/
      consumer-prompt.md
      consumer-report.md
      commissioner-review.md
      run.env
```

Global routing index:

```text
~/.commission/
  pins/<pin>.env
  consumers/<consumer-entry-key>.env
```

The global index stores only reconnect pointers: pin, session id, Commissioner root, target repo, and Consumer entry cwd. It must not store request or report contents.

Route files use single-quoted env assignments with whitelisted keys:

```text
~/.commission/pins/<pin>.env
COMMISSION_PIN='<pin>'
COMMISSION_SESSION_ID='<session-id>'
COMMISSION_COMMISSIONER_ROOT='<absolute-commissioner-root>'
COMMISSION_TARGET_REPO='<absolute-target-repo>'

~/.commission/consumers/<consumer-entry-key>.env
COMMISSION_CONSUMER_ENTRY_CWD='<absolute-consumer-entry-cwd>'
COMMISSION_SESSION_ID='<session-id>'
COMMISSION_COMMISSIONER_ROOT='<absolute-commissioner-root>'
COMMISSION_TARGET_REPO='<absolute-target-repo>'
```

`<consumer-entry-key>` is the `/usr/bin/cksum` first field of the absolute Consumer entry cwd. The same keying rule is used for reset cleanup and notify lookup.

Lookup precedence:

| Command | Lookup rule |
| --- | --- |
| `consumer connect <pin>` | Always resolve `~/.commission/pins/<pin>.env` first; ignore local `.commission/` in Consumer entry cwd. |
| `consumer notify` | If `~/.commission/consumers/<current-cwd-key>.env` exists, use that route first. Otherwise use local `.commission/` only when it belongs to the current cwd. |
| `status` | Reports local `.commission/` only. It does not follow Consumer routes. |
| `doctor` | Reports local state plus installed runtime marker for the script's actual install root. |

This version supports multiple sequential runs in one session, with exactly one active run at a time. The first run id is `001`; later requests use the next numeric id and may supersede a pending active run.

## Safety Rules

- Installer must back up unrelated existing skills for all new skill names before replacing them.
- Installer must write a per-skill managed marker into every installed skill directory. `adl/.adl-framework` and `commission/.commission-framework` remain group doctor markers, but backup decisions must use per-target managed markers so unrelated `commission-connect` or `commission-reset` skills are protected.
- Runtime scripts must reject unsafe env keys, newlines in env values, and malformed state files.
- `commission-reset "$PWD/.commission"` may remove only the current directory's `.commission/` and matching global routes for that Commissioner root.
- Consumer connect must prefer the pin route over any local `.commission/` in the Consumer entry cwd. A stale `.commission/` in `~/team-b-repo` must not block connecting to Team A's repo.
- Consumer notify must prefer the Consumer route for the current cwd over local `.commission/`, so a valid Team B `.commission/` cannot steal Team A's report notification.
- `commission doctor` must report the marker for the runtime it is actually installed under, Codex or Claude.
- Existing ADL behavior and tests must remain unchanged.

## Error Handling

- Missing or expired pin: tell Consumer to ask Commissioner for a fresh pin.
- Missing Consumer route on notify: tell Consumer to reconnect with `$commission-connect <pin>`.
- Consumer and Commissioner captured as the same Ghostty terminal: fail with a refresh instruction.
- Missing report: print the required report template and refuse notify.
- Prompt or report missing required sections: fail before changing run state.

## Testing Strategy

Add zsh integration tests that prove:

- Commissioner starts a session in Team A repo and records target repo.
- Consumer connects from Team B repo and receives Team A target repo.
- Consumer entry cwd with its own `.commission/` still resolves by pin to Team A.
- Consumer notify works from Team B entry cwd and from Team A target repo.
- No `.commission/` is created in Team B repo by connect.
- Installer backs up unrelated pre-existing `commission`, `commission-connect`, and `commission-reset` skills.
- Codex and Claude installs render correct skill paths and doctor marker paths.
- `./tests/run.sh` passes after the protocol is added.

## Success Criteria

- A Consumer starting in `~/team-b-repo` can implement a scoped request in Team A's repo without manual path guessing.
- Team A's repo owns all Commission request, report, review, and log state.
- Team B's repo remains free of protocol truth state.
- The install surface is safe for users who already have unrelated skills with the same names.
- The implementation is ready for `./.install.sh --minor` only after all tests pass.
