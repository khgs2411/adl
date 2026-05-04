#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

for test_file in "$ROOT"/tests/*_test.sh(N); do
  print -r -- "Running ${test_file:t}"
  "$test_file"
done

print -r -- "All tests passed."
