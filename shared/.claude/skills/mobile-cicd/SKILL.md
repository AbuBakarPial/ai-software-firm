# SKILL: Mobile CI/CD · v2026.10
> Load when: building, signing, or deploying mobile apps to stores.
> Covers: Android Play Store, iOS App Store, TestFlight, Fastlane, code signing

## DETECT FIRST
```bash
ls android/ ios/ 2>/dev/null
cat fastlane/Fastfile 2>/dev/null
ls .github/workflows/release*.yml 2>/dev/null
```

---

## ANDROID (Play Store)

### Keystore Management
```bash
# Generate keystore (ONE TIME)
keytool -genkey -v -keystore release.jks -keyalg RSA -keysize 2048 \
  -validity 10000 -alias upload

# ⚠️ NEVER commit keystore to git
# Store in: password manager + CI/CD vault
# CI/CD: base64 encode → store as protected CI variable

# android/key.properties (in .gitignore)
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=../release.jks
```

### Build Gradle Config
```gradle
// android/app/build.gradle
android {
    signingConfigs {
        release {
            storeFile file(System.getenv("KEYSTORE_PATH") ?: "release.jks")
            storePassword System.getenv("STORE_PASSWORD")
            keyAlias System.getenv("KEY_ALIAS")
            keyPassword System.getenv("KEY_PASSWORD")
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled true
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
    }
}
```

### Play Store Release
```bash
# 1. Build signed AAB (Android App Bundle — preferred over APK for Play Store)
flutter build appbundle --release

# 2. Upload to Play Console
# Internal testing track → Closed alpha → Open beta → Production
# Each track: staged rollout (start 10%, increase gradually)

# 3. Versioning (pubspec.yaml)
version: 1.2.0+3  # versionName + versionCode (increment versionCode each build)
```

### Google Play Pre-launch Report
```bash
# Auto-runs when you upload to Play Console
# Checks: crashes, ANRs, performance, accessibility
# Fix all issues before promoting to production
```

---

## iOS (App Store)

### Certificate Management (Fastlane Match)
```bash
# Fastlane Match: stores all signing certs in encrypted git repo or S3
# One command to setup any machine — no manual certificate management
fastlane match init    # one-time setup
fastlane match development
fastlane match adhoc
fastlane match appstore

# Match stores:
# - Certificates (p12)
# - Provisioning profiles
# All encrypted with a passphrase you control
```

### Fastfile
```ruby
# fastlane/Fastfile
default_platform(:ios)

platform :ios do
  desc "Build and upload to TestFlight"
  lane :beta do
    match(type: :adhoc)
    build_app(scheme: "YourApp", export_method: "ad-hoc")
    upload_to_testflight(
      skip_waiting_for_build_processing: true,
      changelog: "Bug fixes and performance improvements"
    )
  end

  desc "Submit to App Store Review"
  lane :release do
    match(type: :appstore)
    build_app(scheme: "YourApp", export_method: "app-store")
    upload_to_app_store(
      skip_metadata: false,
      skip_screenshots: true,
      submit_for_review: true,
      automatic_release: false  # manual release after approval
    )
  end

  desc "Increment build number"
  lane :bump do
    increment_build_number(xcodeproj: "ios/Runner.xcodeproj")
  end
end

platform :android do
  desc "Build and upload to Play Store Internal Testing"
  lane :internal do
    gradle(task: "bundleRelease")
    upload_to_play_store(track: 'internal')
  end
end
```

### Appfile
```ruby
# fastlane/Appfile
app_identifier("com.yourcompany.yourapp")
apple_id("your@appleid.com")
team_id("YOUR_TEAM_ID")
itc_team_id("YOUR_ITC_TEAM_ID")
```

### CI/CD for iOS (GitHub Actions)
```yaml
# .github/workflows/ios-beta.yml
name: iOS Beta
on: { push: { branches: [main] } }
jobs:
  build:
    runs-on: macos-latest  # ⚠️ requires macOS runner
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
      - run: npm ci
      - run: |
          gem install bundler
          bundle install
          bundle exec fastlane beta
        env:
          MATCH_PASSWORD: ${{ secrets.MATCH_PASSWORD }}
          APP_STORE_CONNECT_API_KEY: ${{ secrets.APP_STORE_CONNECT_API_KEY }}
```

---

## FASTLANE ESSENTIALS

```bash
# Setup
gem install fastlane
fastlane init          # interactive setup

# Common lanes
fastlane beta          # TestFlight
fastlane release       # App Store
fastlane internal      # Play Store internal testing
fastlane run bump      # increment build number

# Environment variables stored in CI
# MATCH_PASSWORD     → encrypts match repo
# APP_STORE_CONNECT_API_KEY → API key for App Store Connect
# KEYSTORE_BASE64    → Android keystore (base64)
# STORE_PASSWORD     → keystore password
# KEY_ALIAS          → keystore alias
# KEY_PASSWORD       → key password
```

---

## FLUTTER BUILD VARIANTS

```bash
# Dev (debug, no minification)
flutter build apk --debug --dart-define=ENV=development

# Staging (RELEASE mode, staging server)
flutter build apk --release --dart-define=ENV=staging

# Production (RELEASE mode, signed)
flutter build appbundle --release --dart-define=ENV=production

# iOS variants
flutter build ios --release --no-codesign  # CI builds without certs
flutter build ipa --release                 # local builds with certs
```

---

## DISTRIBUTION OPTIONS

| Method | Android | iOS | Use case |
|--------|---------|-----|----------|
| TestFlight | N/A | ✅ | iOS beta testers (Apple-controlled) |
| Firebase App Distribution | ✅ | ✅ | Internal team testing |
| Play Store Internal Testing | ✅ | N/A | Android beta (up to 100 testers) |
| Play Store Closed Alpha | ✅ | N/A | Wider Android beta |
| Play Store Open Beta | ✅ | N/A | Public Android beta |
| App Store TestFlight | N/A | ✅ | Up to 10,000 iOS beta testers |
| Direct APK/IPA | ✅ | ❌ | Sideloading (enterprise only for iOS) |

---

## RELEASE PROCESS

```
1. Bump version (pubspec.yaml + git tag)
2. Build for all targets
3. Deploy to staging track (TestFlight / Internal Testing)
4. Run smoke tests (manual or automated)
5. 🔴 QUARANTINE 24-48 hours — monitor crash reports
6. No critical issues → promote to production
7. Monitor rollout at 1% → 5% → 25% → 100%
8. If crash rate > 0.1% → rollback immediately
```

---

## CODESIGN RULES

- Never share private keys/certificates outside your team
- Use Fastlane Match for iOS — one encrypted repo, all machines
- Android keystore: one person generates, restores from backup
- Rotate certificates annually (set calendar reminder)
- Revoke compromised certificates immediately
- Use separate distributions certs for dev/ad-hoc/app-store
