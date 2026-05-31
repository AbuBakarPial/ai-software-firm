#!/bin/bash
# rtk-rewrite.sh — PreToolUse hook
# Auto-prefixes long-output commands with rtk for token compression
# Requires: cargo install rtk --git https://github.com/rtk-ai/rtk

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('command',''))" 2>/dev/null)

# Only rewrite if rtk is installed
if ! command -v rtk &> /dev/null; then
  exit 0  # rtk not installed, pass through unchanged
fi

# Commands that benefit from rtk compression
VERBOSE_COMMANDS=(
  "^git log"
  "^git diff"
  "^git status"
  "^flutter analyze"
  "^flutter test"
  "^cargo test"
  "^cargo build"
  "^npm test"
  "^pytest"
  "^find \."
  "^grep -r"
)

for pattern in "${VERBOSE_COMMANDS[@]}"; do
  if echo "$COMMAND" | grep -qE "$pattern"; then
    # Output rewritten command for Claude to use
    REWRITTEN="rtk $COMMAND"
    echo "$INPUT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
d['command'] = 'rtk ' + d.get('command', '')
print(json.dumps(d))
"
    exit 0
  fi
done

exit 0
