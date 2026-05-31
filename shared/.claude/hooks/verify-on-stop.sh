#!/bin/bash
# verify-on-stop.sh — Stop hook
# Runs before Claude marks a task as done
# Exit 2 = prevent Claude from stopping, force it to fix issues

# Skip if explicitly set (for /compact mid-task)
if [ "${SKIP_VERIFY:-}" = "1" ]; then
  exit 0
fi

FAILURES=()

# 1. Dart analyze (no errors allowed)
if find . -name "*.dart" -newer .last_verify 2>/dev/null | head -1 | grep -q .; then
  RESULT=$(flutter analyze --no-fatal-infos 2>&1 | tail -5)
  if echo "$RESULT" | grep -qE "^error"; then
    FAILURES+=("Flutter analyze: errors found")
    echo "$RESULT"
  fi
fi

# 2. Dart format check (no unformatted files)
if find . -name "*.dart" -not -path "*/build/*" -newer .last_verify 2>/dev/null | head -1 | grep -q .; then
  UNFORMATTED=$(dart format --set-exit-if-changed --output=none . 2>&1 | grep "Formatted" | grep -v "0 files")
  if [ -n "$UNFORMATTED" ]; then
    FAILURES+=("Unformatted Dart files: $UNFORMATTED")
  fi
fi

# 3. No new TODO/FIXME/HACK introduced without tracking
NEW_TODOS=$(git diff --cached 2>/dev/null | grep "^+" | grep -E "TODO|FIXME|HACK|XXX" | grep -v "^+++" | wc -l)
if [ "$NEW_TODOS" -gt 0 ]; then
  echo "⚠️  $NEW_TODOS new TODO/FIXME found in staged changes — acknowledge these are tracked"
fi

# 4. No secrets in staged files
if command -v gitleaks &> /dev/null; then
  LEAK=$(gitleaks detect --source . --no-git 2>&1 | grep -c "finding" || true)
  if [ "${LEAK:-0}" -gt 0 ]; then
    FAILURES+=("Potential secrets detected — run: gitleaks detect --source . --verbose")
  fi
fi

# Report failures
if [ ${#FAILURES[@]} -gt 0 ]; then
  echo ""
  echo "❌ Cannot mark done — verification failed:"
  for f in "${FAILURES[@]}"; do
    echo "  • $f"
  done
  echo ""
  echo "Fix the above issues before completing this task."
  touch .last_verify
  exit 2
fi

touch .last_verify
echo "✓ Verification passed"
exit 0
