# ADL Transport And Platform Support Design

## Status

Draft for implementation planning.

## Question

Can ADL support terminals beyond Ghostty, and can it run beyond macOS?

Short answer: yes, ADL is not conceptually bound to Ghostty. The current implementation is bound to Ghostty because `scripts/adl` hardwires `GHOSTTY="$SCRIPT_DIR/ghostty-macos"` and calls that adapter directly from role capture, send, notification, and doctor paths. The protocol state already points in the right direction: sessions store `ADL_ARCHITECT_ADAPTER`, `ADL_DEV_ADAPTER`, and terminal ids separately from run state.

The right V2 is not "support every terminal." The right V2 is a small transport contract with Ghostty as the baseline adapter, then one additional low-risk adapter or a tmux layer.

## Current Code Facts

Inspected source paths:

- `scripts/adl`
- `scripts/ghostty-macos`
- `tests/ghostty_adapter_test.sh`
- `tests/cli_state_test.sh`
- `tests/panel_message_test.sh`
- `tests/doctor_test.sh`

Current coupling:

- `scripts/adl` sets `GHOSTTY="$SCRIPT_DIR/ghostty-macos"`.
- `capture_role` calls `$GHOSTTY capture-focused <role>`.
- `create_session` and `architect_reconnect` capture and persist Architect terminal metadata.
- `send_dev` sends the Architect request to `ADL_DEV_TERMINAL_ID`.
- `dev_connect` captures and persists Dev terminal metadata.
- `notify_architect_dev_connected` wakes Architect after Dev connects.
- `notify_dev` wakes Architect after Dev reports.
- `doctor_ghostty` is adapter-specific.
- Tests already fake or dry-run the adapter through `ADL_GHOSTTY_DRY_RUN=1`, fake `ghostty-macos`, and `ADL_SCRIPT_ROOT`.

Useful state keys:

- `ADL_ARCHITECT_OS`
- `ADL_ARCHITECT_TERMINAL`
- `ADL_ARCHITECT_ADAPTER`
- `ADL_ARCHITECT_TERMINAL_ID`
- `ADL_ARCHITECT_LABEL`
- `ADL_DEV_OS`
- `ADL_DEV_TERMINAL`
- `ADL_DEV_ADAPTER`
- `ADL_DEV_TERMINAL_ID`
- `ADL_DEV_LABEL`

These keys mean existing `.adl` state can survive a V2 adapter split without changing the run/report protocol.

## Minimal Transport Contract

ADL needs less from a terminal than a general automation framework.

Required commands:

```text
capture-focused <role>
send <terminal-id> <message>
doctor <role>
```

Required `capture-focused` output:

```text
ADL_<ROLE>_ADAPTER='<adapter-name>'
ADL_<ROLE>_TERMINAL_ID='<opaque-target-id>'
ADL_<ROLE>_LABEL='<human-readable-label>'
```

The protocol adds per-role metadata outside the adapter payload:

- OS: normalized from `uname` as `macos`, `linux`, `windows`, or `unknown`
- terminal: derived from the selected adapter, for example `ghostty`, `tmux`, or `terminal-app`
- adapter: the exact selected transport executable name
- terminal id: opaque adapter target, such as a Ghostty id, tmux pane id, or Terminal.app tty
- label: human-readable adapter label when available

Required `send` behavior:

- deliver one line of text to the target session
- submit it as if Enter was pressed
- fail non-zero when the target cannot be found or input cannot be delivered
- never parse, inspect, or approve Dev output

Required `doctor` behavior:

- report adapter executable/config state
- report whether focused capture works
- report permission or dependency failures plainly

Optional future commands:

```text
list-targets
validate-target <terminal-id>
focus <terminal-id>
```

Do not add optional commands in the first V2 slice unless a selected adapter cannot be made reliable without them.

## Protocol vs Adapter Responsibilities

Protocol/state responsibilities stay in `scripts/adl`:

- session lifecycle
- pin creation and matching
- run creation and supersession
- prompt/report validation
- `.adl/` state layout
- `ADL_*` env key validation
- acceptance-shaped Dev report contract
- user-facing errors and recovery instructions

Adapter responsibilities move behind a transport wrapper:

- identify the focused terminal/pane/session
- return an opaque target id
- deliver a wake-up command to that target
- translate platform permission failures into transport errors
- provide adapter-specific doctor details

The adapter must not know ADL run semantics. It should only capture a target and send a string.

## Platform Matrix

| Target | Classification | Reason |
| --- | --- | --- |
| macOS Ghostty | Viable now | Current baseline. Ghostty exposes a native AppleScript dictionary with windows, tabs, terminals, focused terminal lookup, `input text`, and `send key`. Current adapter already uses this shape. |
| macOS Terminal.app | Viable with adapter work | Apple documents Terminal as scriptable with AppleScript and `osascript`. Likely enough for opening/running commands, but targeting the exact focused tab/session and sending input to an existing session needs a dedicated adapter and hands-on verification. |
| macOS iTerm2 | Viable with adapter work | iTerm2 has an official Python API for controlling the app and sessions. This is likely richer than Terminal.app, but introduces Python/API setup and permission considerations. |
| Linux X11 terminal automation | Possible but weak | `xdotool` can get active windows, activate windows, type text, and send keys under X11. It is window-level synthetic input, not terminal-session-aware, so pane targeting is weaker than Ghostty/iTerm/tmux. |
| Linux Wayland terminal automation | Not recommended for first-class V2 | Wayland intentionally limits global synthetic input. `ydotool` works through `/dev/uinput` and normally requires a daemon and elevated input-device permissions. That is too invasive for default ADL. |
| Windows Terminal / PowerShell | Possible but weak | `wt.exe` can create tabs/panes and target windows, but the official command-line surface is process/window creation, not reliable injection into an existing focused pane. A robust adapter likely needs a different control layer. |
| WSL | Viable with adapter work through tmux or Windows Terminal | Microsoft documents Windows/Linux interop and running Windows executables from WSL. WSL can call `wt.exe`, but pane targeting remains weak. WSL plus tmux is a stronger protocol layer. |
| tmux | Viable with adapter work; best cross-platform candidate | tmux can target panes, send keys, and capture pane content through its own command surface. It avoids GUI automation and works on macOS, Linux, and inside WSL where tmux is available. |

## Recommended V2 Scope

V2 should support:

1. Ghostty as the unchanged baseline.
2. A transport abstraction inside `scripts/adl`.
3. One new non-Ghostty adapter, preferably tmux.

Why tmux first:

- It is terminal-emulator independent.
- It is cross-platform across macOS/Linux and practical inside WSL.
- Its pane ids are already opaque terminal targets.
- It can send a line plus Enter without GUI permissions.
- It can be tested headlessly more easily than GUI apps.

Keep experimental:

- Terminal.app adapter until exact focused-session targeting is verified.
- iTerm2 adapter until dependency and permission flow is designed.
- X11 adapter because window-level typing is fragile.
- Wayland adapter because `/dev/uinput` permissions and daemon setup are too invasive.
- Windows Terminal direct adapter until a reliable existing-pane input strategy exists.

## Proposed Implementation Plan

### Slice 1: Extract Transport Contract, Preserve Ghostty

Likely files:

- `scripts/adl`
- `scripts/ghostty-macos`
- new `scripts/transports/ghostty-macos` or keep existing path with a wrapper
- `tests/cli_state_test.sh`
- `tests/ghostty_adapter_test.sh`
- `tests/doctor_test.sh`
- `tests/panel_message_test.sh`

Behavior:

- Add installed runtime transport config adjacent to that runtime's installed `adl` skill directory, for example `.adl-config` with `ADL_TRANSPORT='<adapter>'`. Codex and Claude installs can have different configs.
- The normal CLI default reads installed runtime config; `ADL_TRANSPORT=<adapter>` remains a one-command override.
- If no env override and no installed config exist, fail clearly and ask the operator to reinstall/update with a transport choice or set `ADL_TRANSPORT`.
- Resolve adapter path from a small allowlist.
- Keep `ADL_TRANSPORT=auto` only as an explicit diagnostic/setup helper.
- Replace direct `$GHOSTTY ...` calls with `transport_capture`, `transport_send`, and `transport_doctor`.
- Keep `ghostty-macos` as the production baseline.
- Persist selected adapter metadata per role, so Architect can be Ghostty while Dev is Terminal.app or tmux.
- Keep existing `.adl` sessions valid when `ADL_*_ADAPTER='ghostty-macos'`.
- If an existing session adapter is unsupported by the current install, fail with a reconnect instruction rather than mutating state.

Test strategy:

- Keep all current Ghostty dry-run tests passing.
- Add a fake adapter fixture named something other than Ghostty to prove `scripts/adl` is not hardwired.
- Assert `ADL_ARCHITECT_ADAPTER` and `ADL_DEV_ADAPTER` persist the selected adapter.
- Assert send paths call the selected adapter.
- Assert mixed transports route Architect handoffs through stored Dev adapter and Dev reports through stored Architect adapter.
- Assert installed config is used by default, env override wins, and missing config fails with setup guidance.
- Assert explicit auto detection still selects Terminal.app from macOS `TERM_PROGRAM=Apple_Terminal`, tmux from `TMUX`, and fails when ambiguous if retained.
- Assert doctor routes to the selected adapter.

### Slice 2: Add tmux Adapter As Experimental

Likely files:

- `scripts/tmux`
- `tests/tmux_adapter_test.sh`
- README usage note for `ADL_TRANSPORT=tmux`

Minimal tmux assumptions:

- Architect and Dev are in tmux panes.
- The adapter captures the current pane id.
- The adapter sends text to a pane and then Enter.

Migration behavior:

- Existing Ghostty sessions continue using `ADL_*_ADAPTER='ghostty-macos'`.
- New sessions use installed runtime config unless `ADL_TRANSPORT=tmux` or another explicit adapter is set.
- Reconnect can switch the captured role to the currently selected transport only when the operator explicitly runs reconnect.

### Slice 3: Bounded Terminal.app Prototype

Likely files:

- `scripts/terminal-macos`
- `tests/terminal_macos_adapter_test.sh`
- README usage note for `ADL_TRANSPORT=terminal-macos`

Minimal Terminal.app assumptions:

- Architect and Dev are existing Terminal.app tabs.
- The adapter captures `tty of selected tab of front window`.
- The adapter sends by finding a tab with the stored tty and running the message in that tab.
- macOS Automation permission errors are transport failures with reconnect guidance.

Migration behavior:

- Terminal.app remains experimental.
- Auto detection may select it only for macOS Apple Terminal environments.
- Unsupported Windows/Linux GUI terminals remain out of scope until they expose a stable pane/session targeting API.

## Source Notes

- Ghostty AppleScript documentation: https://ghostty.org/docs/features/applescript
  - Notes: Ghostty exposes an AppleScript object model with windows, tabs, terminals, focused terminal lookup, `input text`, and `send key`; macOS Automation permissions apply.
- Apple Terminal AppleScript documentation: https://support.apple.com/en-asia/guide/terminal/trml1003
  - Notes: Apple says Terminal is scriptable with AppleScript and can be automated with `osascript`.
- iTerm2 Python API documentation: https://iterm2.com/python-api/
  - Notes: iTerm2 provides a Python package/API for controlling and extending iTerm2 behavior.
- xdotool manual: https://man.archlinux.org/man/xdotool.1.en
  - Notes: xdotool supports active-window lookup and window activation on X11.
- ydotool manual: https://man.archlinux.org/man/ydotool.1.en
  - Notes: ydotool simulates input through `/dev/uinput` and requires `ydotoold`.
- Windows Terminal command-line documentation: https://learn.microsoft.com/en-us/windows/terminal/command-line-arguments
  - Notes: `wt.exe` can create/target windows, tabs, and panes, including from WSL via `cmd.exe`, but this is not the same as reliable existing-pane text injection.
- WSL interoperability documentation: https://learn.microsoft.com/en-us/windows/wsl/filesystems
  - Notes: WSL can run Windows executables from Linux and Linux tools from Windows.
- tmux advanced-use wiki: https://github.com/tmux/tmux/wiki/Advanced-Use
  - Notes: tmux supports `send-keys` to a pane and `capture-pane`.

## Decision

ADL should not chase GUI automation parity across every terminal first. The next implementation should extract a tiny transport contract while preserving Ghostty behavior, then add tmux as the first experimental cross-platform adapter.

This gives ADL a path beyond macOS/Ghostty without weakening the current working baseline.
