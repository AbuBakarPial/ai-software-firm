---
name: fastlane
description: >
  Use when shipping Flutter to Play Store or App Store, bumping build numbers,
  managing signing certs, or setting up mobile CI/CD. Do not use for web deploys.
---

# Fastlane — Mobile Store Delivery

## Required env vars (CI secrets, never hardcode)

```
FLUTTER_BUILD_NUMBER      # auto-increment: $CI_PIPELINE_IID or date +%s
SUPABASE_URL              # dart-define passthrough
SUPABASE_ANON_KEY         # dart-define passthrough
APP_BUNDLE_ID             # e.g. com.yourco.appname
PLAY_STORE_JSON_KEY       # Google service account JSON (base64 or path)
APPLE_ID                  # Apple developer email
ITC_TEAM_ID               # App Store Connect team
TEAM_ID                   # Apple Developer team
MATCH_GIT_URL             # Private repo for match certs
APP_STORE_CONNECT_API_KEY_PATH  # .p8 key file path
```

## Lanes

| Lane | What it does |
|------|-------------|
| `android internal` | Build AAB → Play Store internal track |
| `android promote_prod` | Promote internal → production (10% rollout) |
| `ios beta` | Build IPA → TestFlight |
| `ios promote_prod` | Submit TestFlight build to App Store review |

## Signing — use match, never manual

```bash
# First time setup (creates certs + profiles in private git repo)
bundle exec fastlane match init
bundle exec fastlane match appstore --app-identifier $APP_BUNDLE_ID

# CI (read-only, uses existing certs)
bundle exec fastlane match appstore --readonly
```

## Build number convention

```bash
# Use pipeline number (GitLab) or timestamp
export FLUTTER_BUILD_NUMBER=$CI_PIPELINE_IID
# or: export FLUTTER_BUILD_NUMBER=$(date +%Y%m%d%H%M)
```

## Gemfile (required — pin fastlane version)

```ruby
source "https://rubygems.org"
gem "fastlane", "~> 2.220"
gem "cocoapods"
```

Run `bundle exec fastlane [lane]` always — never bare `fastlane`.

## /ship checklist addition

```
[ ] FLUTTER_BUILD_NUMBER incremented
[ ] bundle exec fastlane android internal → no errors
[ ] Play Store internal track shows new build
[ ] bundle exec fastlane ios beta → no errors
[ ] TestFlight shows new build
[ ] Promote only after QA sign-off on internal/TestFlight
```
