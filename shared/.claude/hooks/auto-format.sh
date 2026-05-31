#!/bin/bash
# auto-format.sh — PostToolUse hook
# Runs formatter after every file write/edit

INPUT=$(cat)
FILE=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('path', d.get('file_path','')))" 2>/dev/null)

if [ -z "$FILE" ] || [ ! -f "$FILE" ]; then
  exit 0
fi

EXT="${FILE##*.}"

case "$EXT" in
  dart)
    dart format "$FILE" --line-length=100 2>/dev/null
    # Run dart analyze on the file (silent unless error)
    dart analyze "$FILE" --no-fatal-infos 2>/dev/null | grep -E "error|warning" || true
    ;;
  rs)
    rustfmt "$FILE" 2>/dev/null
    ;;
  js|ts|jsx|tsx)
    npx prettier --write "$FILE" 2>/dev/null
    ;;
  py)
    black "$FILE" 2>/dev/null || autopep8 --in-place "$FILE" 2>/dev/null
    ;;
  json)
    python3 -c "import sys,json; f=open('$FILE'); d=json.load(f); f.close(); open('$FILE','w').write(json.dumps(d,indent=2))" 2>/dev/null
    ;;
  yaml|yml)
    # No auto-format for YAML (risky) — just validate
    python3 -c "import yaml; yaml.safe_load(open('$FILE'))" 2>/dev/null || echo "WARN: Invalid YAML in $FILE"
    ;;
  sh)
    chmod +x "$FILE" 2>/dev/null
    ;;
esac

# Secret scan on written files
if command -v gitleaks &> /dev/null; then
  gitleaks detect --source "$FILE" --no-git 2>/dev/null && true || {
    echo "⚠️  POTENTIAL SECRET DETECTED in $FILE — verify before committing"
  }
fi

exit 0
