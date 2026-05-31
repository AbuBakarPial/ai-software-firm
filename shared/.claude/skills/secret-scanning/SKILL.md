---
name: secret-scanning
description: >
  Use during /devsecops, /review, and before any git push. Covers gitleaks setup,
  CI integration, pre-commit hooks, and triage of findings.
---

# Secret Scanning

## Local scan (run before every commit)

```bash
# Scan staged files only (fast, pre-commit)
gitleaks protect --staged --redact

# Scan entire repo history (run once on new projects)
gitleaks detect --redact

# Scan specific path
gitleaks detect --source ./lib --redact
```

## What gitleaks catches

High-signal rules already built in: AWS keys, GCP tokens, Supabase keys, Stripe secrets,
JWT secrets, private keys (RSA/EC/DSA), GitHub tokens, Slack webhooks, Firebase config.

## False positive handling

Create `.gitleaks.toml` in project root:

```toml
[extend]
useDefault = true

[[allowlists]]
description = "test fixtures and example values"
paths = [
  "test/fixtures/.*",
  ".*\\.example$",
  ".*\\.sample$"
]
regexes = [
  "EXAMPLE_KEY",
  "your-api-key-here"
]
```

## /devsecops checklist addition

Add to every /devsecops run:
```
[ ] gitleaks detect --redact → 0 findings
[ ] grep -r "SUPABASE_URL\s*=" lib/ → empty (use --dart-define or .env)
[ ] grep -r "apiKey\s*=" lib/ → empty
[ ] pubspec.yaml has no hardcoded URLs in dependencies
```

## Triage severity

| Finding | Action |
|---------|--------|
| Real secret in history | `git filter-repo`, rotate key immediately, force push |
| Real secret in unstaged | Remove, add to .gitignore, never commit |
| Test fixture false positive | Add allowlist rule above |
| Dart-define value exposed | Move to CI env var, not code |
