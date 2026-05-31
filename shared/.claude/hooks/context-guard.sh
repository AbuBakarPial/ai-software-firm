#!/bin/bash
# context-guard.sh — PreToolUse hook
# Warns agent when context is bloated; blocks file-dumps into context.
# Exit 2 = block the tool call and force agent to compact first.

TOOL_NAME="${TOOL_NAME:-}"
TOOL_INPUT="${TOOL_INPUT:-}"

# Block full-file reads on large files (>500 lines floods context)
if [[ "$TOOL_NAME" == "Read" || "$TOOL_NAME" == "Bash" ]]; then
  # Detect cat on large files
  if echo "$TOOL_INPUT" | grep -qE "cat .+(\.dart|\.ts|\.tsx|\.go|\.py)\b"; then
    FILE=$(echo "$TOOL_INPUT" | grep -oE "[^ ]+\.(dart|ts|tsx|go|py)" | head -1)
    if [ -f "$FILE" ]; then
      LINES=$(wc -l < "$FILE")
      if [ "${LINES:-0}" -gt 500 ]; then
        echo "⚠️  Context guard: $FILE has $LINES lines. Use grep/head/tail instead of cat."
        echo "    grep -n 'pattern' $FILE"
        echo "    head -50 $FILE / tail -50 $FILE"
        exit 2
      fi
    fi
  fi

  # Block recursive find with no depth limit (floods context with file lists)
  if echo "$TOOL_INPUT" | grep -qE "find \. -name \*\.(dart|ts|go|py)$"; then
    echo "⚠️  Context guard: unbounded find. Add -maxdepth 3 or pipe to head -20."
    exit 2
  fi
fi

exit 0
