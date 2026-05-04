#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/tests/assert.sh"

skill_text="$(cat "$ROOT/skills/adl/SKILL.md")"
connect_skill_text="$(cat "$ROOT/skills/adl-connect/SKILL.md")"

assert_contains "$skill_text" "adl architect reconnect" "Architect skill should document reconnect command"
assert_contains "$skill_text" "\$adl reconnect" "Architect skill should document skill-level reconnect invocation"
assert_contains "$skill_text" "ADL is ready. Connect Dev with \$adl-connect <pin>, then I will send the first handoff." "Architect skill should wait for Dev before first handoff"
assert_contains "$skill_text" "unless the user explicitly asks to queue a pending handoff" "Architect skill should preserve explicit pending-handoff override"
assert_contains "$skill_text" ".adl/staging/" "Architect skill should use staging for handoff preparation"
assert_contains "$connect_skill_text" "After a successful connection, ADL notifies Architect that Dev is connected and ready." "Dev connect skill should document architect ready notification"
assert_contains "$connect_skill_text" "wait for the first" "Dev connect skill should tell Dev to wait for first handoff"
