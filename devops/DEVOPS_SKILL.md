# SKILL: DevOps Checklist · v2026.8
> Load when: setting up CI/CD, deploying, or running /ship command.
> Stack: GitLab CI/CD + Docker + Flutter + Rust FFI

---

## GITLAB CI/CD — FULL PIPELINE

```yaml
# .gitlab-ci.yml
image: debian:bookworm-slim

variables:
  FLUTTER_VERSION: "3.27.0"
  RUST_VERSION: "1.78.0"
  FF_USE_FASTZIP: "true"
  CACHE_COMPRESSION_LEVEL: "fastest"

stages:
  - validate
  - security
  - test
  - build
  - deploy

# ─── CACHE TEMPLATES ───────────────────────────────────────────
.flutter_cache: &flutter_cache
  cache:
    key: flutter-${FLUTTER_VERSION}-${CI_COMMIT_REF_SLUG}
    paths:
      - .flutter/
      - .pub-cache/
    policy: pull-push

.rust_cache: &rust_cache
  cache:
    key: rust-${RUST_VERSION}-${CI_COMMIT_REF_SLUG}
    paths:
      - target/
      - ~/.cargo/registry/
    policy: pull-push

# ─── VALIDATE ──────────────────────────────────────────────────
format-check:
  stage: validate
  <<: *flutter_cache
  script:
    - dart format --set-exit-if-changed --output=none lib/ test/
  rules:
    - if: $CI_PIPELINE_SOURCE == "push"

analyze:
  stage: validate
  <<: *flutter_cache
  script:
    - flutter analyze --no-fatal-infos
  rules:
    - if: $CI_PIPELINE_SOURCE == "push"

# ─── SECURITY ──────────────────────────────────────────────────
secrets-scan:
  stage: security
  image: zricethezav/gitleaks:latest
  script:
    - gitleaks detect --source . --exit-code 1
  rules:
    - if: $CI_PIPELINE_SOURCE == "push"

dependency-audit:
  stage: security
  <<: *flutter_cache
  script:
    - flutter pub outdated --json > pub_outdated.json
    - python3 ci/check_discontinued.py pub_outdated.json
    - cargo audit
  artifacts:
    reports:
      junit: audit-results.xml
    expire_in: 1 week

container-scan:
  stage: security
  image:
    name: aquasec/trivy:latest
    entrypoint: [""]
  script:
    - trivy image --exit-code 1 --severity CRITICAL --no-progress supabase/postgres:15
  rules:
    - if: $CI_COMMIT_BRANCH == "main"

# ─── TEST ──────────────────────────────────────────────────────
unit-tests:
  stage: test
  <<: *flutter_cache
  script:
    - flutter test --coverage --reporter json > test-results.json
    - dart pub global activate cobertura
    - dart pub global run cobertura convert --input coverage/lcov.info --output coverage/cobertura.xml
  coverage: '/lines\s*:\s*(\d+\.\d+)\%/'
  artifacts:
    reports:
      coverage_report:
        coverage_format: cobertura
        path: coverage/cobertura.xml
      junit: test-results.json
    expire_in: 1 week
  rules:
    - if: $CI_PIPELINE_SOURCE == "push"

rust-tests:
  stage: test
  <<: *rust_cache
  script:
    - cargo test --all-features -- --test-threads=4
    - cargo clippy -- -D warnings
  rules:
    - if: $CI_PIPELINE_SOURCE == "push"
    - changes:
        - "rust/**/*"

# ─── BUILD ─────────────────────────────────────────────────────
build-android-dev:
  stage: build
  <<: *flutter_cache
  script:
    - flutter build apk --debug
        --dart-define=SUPABASE_URL=$DEV_SUPABASE_URL
        --dart-define=SENTRY_DSN=$DEV_SENTRY_DSN
  artifacts:
    paths:
      - build/app/outputs/apk/debug/app-debug.apk
    expire_in: 3 days
  rules:
    - if: $CI_COMMIT_BRANCH != "main"

build-android-release:
  stage: build
  <<: *flutter_cache
  environment: production
  script:
    - echo "$KEYSTORE_BASE64" | base64 -d > android/app/keystore.jks
    - flutter build apk --release
        --dart-define=SUPABASE_URL=$PROD_SUPABASE_URL
        --dart-define=SENTRY_DSN=$PROD_SENTRY_DSN
  after_script:
    - rm -f android/app/keystore.jks  # always clean up keystore
  artifacts:
    paths:
      - build/app/outputs/apk/release/app-release.apk
    expire_in: 30 days
  rules:
    - if: $CI_COMMIT_TAG =~ /^v\d+\.\d+\.\d+$/

# ─── DEPLOY ────────────────────────────────────────────────────
deploy-staging:
  stage: deploy
  environment:
    name: staging
    url: https://staging.your-domain.com
  script:
    - echo "Upload APK to staging distribution (Firebase App Distribution / internal)"
    - curl -X POST "$FIREBASE_APP_DIST_URL" -F "apkPath=@build/app/outputs/apk/release/app-release.apk"
  needs: ["build-android-release"]
  rules:
    - if: $CI_COMMIT_TAG =~ /^v\d+\.\d+\.\d+-staging$/

notify-release:
  stage: deploy
  image: curlimages/curl:latest
  script:
    - >
      curl -X POST $SLACK_WEBHOOK
      -H 'Content-type: application/json'
      -d "{\"text\":\"Release $CI_COMMIT_TAG shipped ✓\"}"
  rules:
    - if: $CI_COMMIT_TAG =~ /^v\d+\.\d+\.\d+$/
```

---

## CI/CD VARIABLES SETUP (GitLab)

Go to: **Settings → CI/CD → Variables**

| Variable | Environment | Protected | Masked | Value |
|----------|-------------|-----------|--------|-------|
| `SUPABASE_URL` | staging | ✓ | ✗ | `http://office-ip:8000` |
| `SUPABASE_URL` | production | ✓ | ✗ | `https://your-domain.com` |
| `PROD_SENTRY_DSN` | production | ✓ | ✓ | GlitchTip DSN |
| `DEV_SENTRY_DSN` | * | ✗ | ✗ | Home GlitchTip DSN |
| `KEYSTORE_BASE64` | production | ✓ | ✓ | `base64 < keystore.jks` |
| `KEY_ALIAS` | production | ✓ | ✓ | keystore alias |
| `KEY_PASSWORD` | production | ✓ | ✓ | keystore password |
| `STORE_PASSWORD` | production | ✓ | ✓ | store password |
| `FIREBASE_APP_DIST_URL` | staging | ✓ | ✗ | Firebase endpoint |
| `SLACK_WEBHOOK` | * | ✓ | ✓ | Slack webhook URL |

---

## DOCKER COMPOSE — PRODUCTION CHECKLIST

```bash
# Before starting Supabase in production:
[ ] All ports except 443 blocked at firewall (ufw/iptables)
[ ] Docker compose version pinned (not 'latest')
[ ] Supabase JWT secret changed from default
[ ] Postgres password changed from default
[ ] Dashboard disabled or behind VPN
[ ] Volume backups configured (Section 3, RUNBOOK.md)
[ ] Health check endpoints verified: /health returns 200

# Verify
docker-compose ps --format json | python3 -c "
import sys, json
for line in sys.stdin:
    c = json.loads(line)
    status = c.get('Health','unknown')
    name = c.get('Name','?')
    if status != 'healthy':
        print(f'WARN: {name} = {status}')
"
```

---

## RELEASE CHECKLIST

```bash
# 1. Tag format: vMAJOR.MINOR.PATCH[-staging]
git tag v1.2.0-staging  # staging release
git tag v1.2.0          # production release

# 2. Changelog entry — always before tagging
# CHANGELOG.md must have entry for the version

# 3. Verify pubspec.yaml version matches tag
grep "^version:" pubspec.yaml  # should match

# 4. Push tag (triggers CI/CD)
git push origin v1.2.0

# 5. Monitor pipeline
# GitLab → CI/CD → Pipelines → verify all stages green
```

---

## MONITORING + OBSERVABILITY

```dart
// Every error surface must report to GlitchTip
// lib/core/observability/app_observer.dart
class AppObserver extends StatefulWidget {
  @override
  void initState() {
    FlutterError.onError = (details) {
      SentryFlutter.captureException(
        details.exception,
        stackTrace: details.stack,
      );
    };
    
    PlatformDispatcher.instance.onError = (error, stack) {
      SentryFlutter.captureException(error, stackTrace: stack);
      return true;
    };
  }
}
```

**Dashboards to set up in GlitchTip:**
- Crash rate by version
- Auth error rate
- WebSocket disconnect rate
- API response time P50/P95/P99
- Active sessions count

---

## INFRASTRUCTURE AS CODE

```bash
# If/when you use IaC (Terraform/Ansible):
checkov -d . --framework terraform    # IaC security scan
tfsec .                               # Terraform security
ansible-lint playbook.yml             # Ansible lint

# Signed commits for all infra changes
git config commit.gpgsign true
```

---

## KUBERNETES (if used)
> Load `shared/.claude/skills/kubernetes/SKILL.md` for full K8s deployment patterns.

```bash
# Quick K8s deploy from CI
kubectl set image deployment/api api=registry/app:$CI_COMMIT_TAG -n prod
kubectl rollout status deployment/api -n prod
kubectl rollout undo deployment/api -n prod  # rollback
```

---

## MOBILE STORE RELEASES (Flutter)
> Load `shared/.claude/skills/mobile-cicd/SKILL.md` for full Play Store + App Store pipeline.

### CI/CD addition for store release
```yaml
# Append to your .gitlab-ci.yml or .github/workflows
store-release:
  stage: deploy
  script:
    - fastlane internal    # Play Store Internal Testing
    # or: fastlane beta    # TestFlight
  rules:
    - if: $CI_COMMIT_TAG =~ /^v\d+\.\d+\.\d+$/
  environment:
    name: production
```
