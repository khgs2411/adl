# Native Terminal Support Feasibility

## Status

Research/design note. No production adapter work in this slice.

## User Request

Support:

- native macOS Terminal
- Windows PowerShell / Windows Terminal
- Linux native bash terminal

Important distinction: bash, zsh, and PowerShell are shells. They execute commands once input reaches them. ADL transport needs a targetable terminal/session/pane plus a way to send text and Enter to that target. Shell support and terminal transport support are separate concerns.

## Current Baseline

Supported/default:

- `ghostty-macos`
- installed runtime transport config, chosen during install/update and stored with the installed ADL skill

Experimental:

- `tmux` with `ADL_TRANSPORT=tmux`
- `terminal-macos` with `ADL_TRANSPORT=terminal-macos`

The `tmux` path is the first practical cross-platform layer because it gives ADL stable pane ids and `send-keys` semantics without depending on GUI automation.

Installer detection is deliberately conservative:

- macOS may offer `ghostty-macos` when Ghostty signals or app support are available, `terminal-macos` for Terminal.app, and `tmux` when installed
- Linux/WSL may offer `tmux` when installed
- Windows should not offer generic GUI terminal support without a concrete adapter
- automation can pass `--transport <adapter>` or `ADL_INSTALL_TRANSPORT=<adapter>`

The selected adapter is stored per role in `.adl/session.env`, alongside `ADL_<ROLE>_OS`, `ADL_<ROLE>_TERMINAL`, `ADL_<ROLE>_TERMINAL_ID`, and `ADL_<ROLE>_LABEL`. This lets one session mix transports, such as Architect in Ghostty and Dev in Terminal.app.

## Shell Runtime vs Terminal Transport

Shell runtime support:

- zsh: already works wherever the installed ADL scripts can run.
- bash: should work for operator shell commands, but ADL scripts themselves are zsh scripts today.
- PowerShell: useful as a Windows shell runtime and command launcher, but it is not itself a terminal pane targeting API.

Terminal/session transport support:

- capture the current target
- persist a stable target id in `.adl/session.env`
- send one message plus Enter to that target later, possibly from another process
- fail clearly when the target is gone or inaccessible

ADL should not call something a transport unless it can meet that target-capture and later-send contract.

## macOS Terminal.app

Apple says Terminal is scriptable with AppleScript and its commands are described in Terminal's AppleScript dictionary. Apple also documents using `osascript` from Terminal.

Feasibility:

- Sending text to an existing target session appears feasible through AppleScript `do script ... in <tab/window>` patterns.
- Capturing the exact currently focused tab/session is feasible enough for an experimental adapter by using `selected tab of front window` and serializing that tab's `tty` value as the target id.
- Later sends can search Terminal windows/tabs for a matching `tty` and run `do script "<message>" in targetTab`.
- macOS Automation permission prompts will still apply because this uses AppleScript control of Terminal.

Recommendation:

- Add `terminal-macos` as an experimental adapter behind `ADL_TRANSPORT=terminal-macos`.
- Keep Ghostty as the production baseline unless Terminal.app receives enough real-world use to prove reliability.
- Allow install/setup to configure Terminal.app only for macOS Terminal environments or explicit operator choice.

Prototype questions:

- Verify live that Terminal.app `tty` remains stable for an open tab across later `osascript` calls.
- Verify live that `do script "<message>" in targetTab` sends to the existing tab without spawning a new window/tab.
- Verify permission errors are understandable for macOS Automation setup.

Verdict:

- Experimental adapter added; still not default.

## Windows PowerShell And Windows Terminal

PowerShell:

- PowerShell remoting can run commands on remote computers, create persistent PSSessions, and start an interactive remoting session.
- That is command/session remoting, not a way to inject input into an existing Windows Terminal pane.
- PowerShell should be treated as a shell/runtime option, not a terminal transport.

Windows Terminal:

- Microsoft documents `wt.exe` for opening windows, tabs, panes, targeting windows, focusing tabs, and moving focus.
- The command-line surface can create or target Windows Terminal windows, but the docs do not provide a reliable "send this text into an existing arbitrary pane by id" contract equivalent to `tmux send-keys`.
- `wt.exe --window` can target a window, not an existing pane as an ADL terminal id.

Recommendation:

- Do not build a direct Windows Terminal adapter first.
- Prefer WSL + tmux as the first Windows story because it uses the already-supported tmux transport contract.
- Treat a native Windows adapter as future work requiring either an official Windows Terminal control API suitable for pane input, or a small external helper that can own its own target panes.

Verdict:

- PowerShell: shell runtime, not a transport.
- Windows Terminal direct: prototype candidate only if a reliable pane input API/helper is chosen.
- WSL + tmux: experimental path now.

## Linux Native Bash Terminal

Bash:

- Bash is a shell and has no stable concept of "focused terminal pane" or "send input to another existing terminal emulator pane."
- A process running bash can know its own TTY, but ADL needs cross-process target capture and later delivery to Architect/Dev panes.

Native Linux options:

- tmux: best first-class Linux path. It gives pane ids and `send-keys`, is terminal-emulator independent, and is already implemented experimentally.
- X11 with xdotool: possible but weak. It can target windows and synthesize typing/keys, but it is window-level automation, not shell/session-aware. It is fragile for panes and focus.
- Wayland/global input: not recommended as a first-class transport. Modern Wayland environments intentionally reduce global input injection. Tools such as ydotool use Linux uinput, which means a daemon/input-device permissions rather than normal terminal automation.
- Raw TTY writes: not recommended. Writing to `/dev/pts/*` is not equivalent to user input for an interactive shell and has security/permissions/line discipline problems.

Recommendation:

- Linux should be tmux-first.
- Do not prototype native terminal-emulator adapters until there is a specific terminal with a stable pane/session control API.
- Keep X11/Wayland routes out of default docs except as explicit "not recommended" or "experimental helper" research.

Verdict:

- Bash: shell runtime, not a transport.
- Linux native GUI terminal: not recommended generically.
- Linux tmux: experimental and best first target.

## Revised Support Roadmap

Supported/default:

- `ghostty-macos`: current production baseline.
- installed transport config: deterministic runtime default chosen by the operator during install/update.

Experimental:

- `tmux`: opt-in with `ADL_TRANSPORT=tmux`; recommended for Linux and WSL users who can run both panes in tmux.
- `terminal-macos`: experimental macOS Terminal.app adapter using `tty` targeting and AppleScript.

Prototype candidate:

- `windows-helper`: future Windows path if it owns panes or uses an official pane input API.

Not recommended:

- `bash` as a transport: shell only.
- `powershell` as a transport: shell/remoting runtime only.
- Generic Linux terminal emulator automation: no uniform target/send API.
- X11 `xdotool` as first-class support: focus/window fragility.
- Wayland/uinput injection as first-class support: too invasive for ADL defaults.
- Raw TTY injection: security and correctness risk.

## Recommended Next Implementation Slice

Next slice: keep `terminal-macos` bounded while adding per-role auto-detected transport metadata.

Likely files:

- `scripts/terminal-macos`
- `tests/terminal_macos_adapter_test.sh`
- `scripts/adl` allowlist addition only if the prototype can satisfy the contract
- README note only if the prototype passes

Prototype acceptance:

- fake or recorded AppleScript fixture proves output format matches `ADL_<ROLE>_ADAPTER` and `ADL_<ROLE>_TERMINAL_ID`
- `.adl/session.env` records role-specific OS, terminal, adapter, terminal id, and label metadata
- mixed transports route sends through the stored recipient adapter rather than the current process adapter
- installed config is used by default, `ADL_TRANSPORT=<adapter>` overrides it for one command, and missing config fails with setup guidance
- live manual check, if approved separately, verifies selected Terminal tab capture
- live manual check, if approved separately, verifies later send to the stored target without opening a new tab/window

Do not implement Windows Terminal or generic Linux GUI automation before the Terminal.app prototype and tmux hardening are complete.

## Source Notes

- Apple Terminal AppleScript docs: https://support.apple.com/en-lamr/guide/terminal/trml1003
  - Terminal is scriptable with AppleScript and can be automated via `osascript`.
- Windows Terminal command-line docs: https://learn.microsoft.com/en-us/windows/terminal/command-line-arguments
  - `wt.exe` supports window targeting, new tabs/panes, and focus commands; it does not document an ADL-style existing-pane text injection contract.
- PowerShell remoting docs: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_remote
  - PowerShell supports remote commands, persistent sessions, and interactive remoting, but these are command/session remoting concepts rather than terminal pane targeting.
- Linux uinput docs: https://www.kernel.org/doc/html/latest/input/uinput.html
  - uinput can emulate input devices from userspace, which explains why Wayland input injection tools tend to need input-device level privileges.
- xdotool manual: https://man.archlinux.org/man/xdotool.1.en
  - X11 automation can synthesize window input, but remains window/focus-level automation.
- ydotool manual: https://man.archlinux.org/man/ydotool.1.en
  - ydotool uses uinput/daemon-style input simulation.
- tmux advanced-use wiki: https://github.com/tmux/tmux/wiki/Advanced-Use
  - tmux supports pane targeting and `send-keys`, matching ADL's transport contract better than generic GUI terminal automation.
