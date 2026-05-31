#!/bin/bash
# block-dangerous.sh — PreToolUse hook
# Blocks destructive commands before Claude runs them
# Exit 2 = block the tool call, show message to Claude

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('command',''))" 2>/dev/null)

# Patterns to block
DANGEROUS_PATTERNS=(
  "rm -rf /"
  "rm -rf ~"
  "rm -rf \$HOME"
  "git push --force"
  "git push -f "
  "git push -f$"
  "DROP TABLE"
  "DROP DATABASE"
  "truncate.*--"
  "chmod -R 777"
  "> /dev/sda"
  "dd if=/dev/zero"
  "mkfs\."
  "format "
)

for pattern in "${DANGEROUS_PATTERNS[@]}"; do
  if echo "$COMMAND" | grep -qiE "$pattern"; then
    echo "BLOCKED: Dangerous command detected: $pattern"
    echo "Command was: $COMMAND"
    echo "If this is intentional, confirm explicitly before proceeding."
    exit 2
  fi
done

# Block writes to production env files without confirmation
PROD_ENV_PATTERNS=(
  "\.env\.prod"
  "main_production\.dart"
  "key\.properties"
  "google-services\.json"
)

# Allow only read operations on prod files
if echo "$COMMAND" | grep -qiE "(echo|cat|tee|write).*\.(env\.prod|key\.properties)"; then
  echo "BLOCKED: Direct write to production config file."
  echo "Edit production configs manually or via CI/CD variables only."
  exit 2
fi

exit 0
