# SKILL: Commit Convention · v2026.8
> Load when: writing commit messages or setting up commit hooks.

---

## CONVENTIONAL COMMITS (mandatory)

Format: `type(scope): description`

```bash
# Types
feat      # new feature
fix       # bug fix  
security  # security fix (always mention CVE if applicable)
perf      # performance improvement
refactor  # code change, no feature or fix
test      # adding or fixing tests
ci        # CI/CD pipeline changes
docs      # documentation only
chore     # tooling, deps, config (no production code)
revert    # reverting a commit

# Scopes (this project)
auth      # authentication, sessions
chat      # messaging, rooms
call      # WebRTC voice/video
crypto    # Rust FFI encryption
realtime  # Supabase realtime
db        # database migrations, RLS
ui        # design system, widgets
router    # navigation
ci        # pipeline
infra     # Docker, Nginx, deployment
```

---

## EXAMPLES

```bash
# Good commits
feat(chat): add read receipts with double-tick indicator
fix(auth): handle token refresh race condition on app resume
security: pin TLS certificate for Supabase endpoint
perf(realtime): batch message inserts to reduce Postgres round-trips
test(crypto): add zeroize verification for session key disposal
ci: add Gitleaks secret scanning to pipeline
refactor(chat): extract MessageBubble into shared widget
docs: add RUNBOOK.md with Supabase restore procedure
chore(deps): upgrade flutter_riverpod to 2.6.1

# Bad commits
fix: fixed stuff                    ← no scope, vague
feat: many changes                  ← multiple concerns, split it
WIP                                 ← never commit WIP to main
updated code                        ← describes nothing
```

---

## COMMIT SIZE RULES

- **One logical change per commit** — if "and" appears in message, split it
- **Max diff:** 300 lines for a single commit (larger = split into logical steps)
- **Never mix:** refactor + feature in same commit
- **Never mix:** formatting + logic in same commit (one of each is fine if separate commits)

---

## PRE-COMMIT HOOKS

```bash
# .git/hooks/pre-commit (or use lefthook/husky)
#!/bin/bash
set -e

# 1. Format check
dart format --set-exit-if-changed --output=none lib/ test/
echo "✓ Format OK"

# 2. Analyze
flutter analyze --no-fatal-infos 2>&1 | grep -E "^error" && exit 1 || true
echo "✓ Analyze OK"

# 3. Secret scan
gitleaks detect --source . --staged --exit-code 1 2>/dev/null
echo "✓ No secrets"

# 4. Commit message format (via commit-msg hook)
echo "✓ Pre-commit passed"
```

```bash
# .git/hooks/commit-msg
#!/bin/bash
PATTERN="^(feat|fix|security|perf|refactor|test|ci|docs|chore|revert)(\(.+\))?: .{1,72}$"
MSG=$(cat "$1")

if ! echo "$MSG" | grep -qE "$PATTERN"; then
  echo "✗ Commit message format invalid."
  echo "  Required: type(scope): description"
  echo "  Example:  feat(chat): add read receipts"
  exit 1
fi
```

---

## INSTALL LEFTHOOK (recommended over plain hooks)

```bash
# Install
brew install lefthook  # macOS
# or: go install github.com/evilmartians/lefthook@latest

# lefthook.yml
pre-commit:
  parallel: true
  commands:
    format:
      run: dart format --set-exit-if-changed --output=none lib/ test/
    analyze:
      run: flutter analyze --no-fatal-infos
    secrets:
      run: gitleaks detect --source . --staged --exit-code 1

commit-msg:
  commands:
    conventional:
      run: |
        MSG=$(cat {1})
        PATTERN="^(feat|fix|security|perf|refactor|test|ci|docs|chore|revert)(\(.+\))?: .{1,72}$"
        if ! echo "$MSG" | grep -qE "$PATTERN"; then
          echo "Invalid commit format. Use: type(scope): description"
          exit 1
        fi

# Initialize
lefthook install
```

---

## VERSIONING (Semantic)

```
MAJOR.MINOR.PATCH

MAJOR: breaking change (API contract, auth schema change)
MINOR: new feature, backward compatible
PATCH: bug fix, security patch, minor improvement

Pre-release: v1.2.0-alpha.1, v1.2.0-beta.2, v1.2.0-staging
Release:     v1.2.0
```

```bash
# GitLab: tag triggers production pipeline
git tag v1.2.0
git push origin v1.2.0

# Staging pipeline
git tag v1.2.0-staging
git push origin v1.2.0-staging
```
