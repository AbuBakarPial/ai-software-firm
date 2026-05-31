# SECRET SCANNING — CI PATCHES
Add these stages to your existing CI files. Additions only — do not replace existing stages.

## GITLAB: add to .gitlab-ci.yml

1. Add `secrets` to the stages list:
   `stages: [lint, test, secrets, build, security, deploy]`

2. Add this job:
```yaml
secret-scan:
  stage: secrets          # runs before build — fail fast
  image: zricethezav/gitleaks:latest
  script:
    - gitleaks detect --source . --redact --exit-code 1
  allow_failure: false    # hard block — no secrets reach build
```

## GITHUB ACTIONS: add to .github/workflows/ci.yml

Add this job alongside your existing jobs:
```yaml
  secret-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }
      - uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          GITLEAKS_LICENSE: ${{ secrets.GITLEAKS_LICENSE }}
```

## LOCAL PRE-COMMIT (optional)

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.18.4
    hooks:
      - id: gitleaks
```
Install: `pip install pre-commit && pre-commit install`
