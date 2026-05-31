# SECURITY HARDENING · Flutter + Supabase + Rust FFI
Version: 1.0.0 | Status: Mandatory | Applies to: All agents and developers

---

## 1. CERTIFICATE PINNING (Flutter → Supabase)

**Required before any public network exposure.**

```dart
// lib/core/network/pinned_http_client.dart
import 'dart:io';
import 'package:http/io_client.dart';

HttpClient buildPinnedClient(List<String> allowedSHA256Fingerprints) {
  final client = HttpClient()
    ..badCertificateCallback = (cert, host, port) {
      final fingerprint = _sha256Fingerprint(cert);
      return allowedSHA256Fingerprints.contains(fingerprint);
    };
  return client;
}
```

**Checklist:**
- [ ] Pin SHA-256 fingerprints of your Supabase TLS cert
- [ ] Pin Nginx/reverse-proxy cert separately if different chain
- [ ] Rotate pinned certs 30 days before expiry
- [ ] Test with Charles Proxy / mitmproxy — should hard-fail, not warn
- [ ] Emergency unpin mechanism via remote config (not hardcoded)

---

## 2. KEY MANAGEMENT · Rust FFI Crypto

**In-memory key zeroing — mandatory after use.**

```rust
// Zeroize keys immediately after use
use zeroize::Zeroize;

fn derive_session_key(master: &mut [u8; 32]) -> SessionKey {
    let key = derive(master);
    master.zeroize(); // ← mandatory
    key
}
```

**Rules:**
- [ ] `zeroize` crate on ALL key material structs (`#[derive(Zeroize, ZeroizeOnDrop)]`)
- [ ] Keys NEVER logged, never in error messages, never in Dart strings longer than session
- [ ] Key material passed as `SecureBytes` / locked memory, not `String`
- [ ] Flutter `Uint8List` holding keys: fill with zeros after use
- [ ] No key material in `MEMORY.md`, `ERRORS.md`, or any log file

---

## 3. ROOT / JAILBREAK DETECTION

**Messenger apps must detect compromised devices.**

```yaml
# pubspec.yaml
dependencies:
  flutter_jailbreak_detection: ^1.10.0
```

```dart
// lib/core/security/device_integrity.dart
import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';

Future<void> enforceDeviceIntegrity() async {
  final jailbroken = await FlutterJailbreakDetection.jailbroken;
  final developerMode = await FlutterJailbreakDetection.developerMode;
  
  if (jailbroken) {
    // Log to GlitchTip, then terminate
    await _reportIntegrityViolation('jailbroken');
    exit(0); // hard exit — no graceful fallback
  }
  
  if (developerMode && kReleaseMode) {
    await _reportIntegrityViolation('developer_mode_release');
    exit(0);
  }
}
```

**Call in:** `main_production.dart` before `runApp()`.

---

## 4. SUPABASE HARDENING

### Row Level Security — Non-Negotiable
```sql
-- Every table MUST have RLS enabled
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

-- Users see only their own messages
CREATE POLICY "user_messages" ON messages
  USING (auth.uid() = sender_id OR auth.uid() = recipient_id);

-- Audit: run this monthly
SELECT tablename FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename NOT IN (
  SELECT tablename FROM pg_policies WHERE schemaname = 'public'
);
-- Result must be empty
```

### Auth Hardening
- [ ] JWT expiry ≤ 1 hour for access tokens
- [ ] Refresh token rotation enabled
- [ ] Email OTP / MFA enforced for admin accounts
- [ ] Supabase anon key exposed to app — this is expected, but restrict with RLS
- [ ] Service role key NEVER in Flutter code or git. CI/CD vault only.
- [ ] Disable email confirmations? Only in dev. Enable in staging/prod.

### Network Hardening (Supabase + Nginx)
```nginx
# /etc/nginx/sites-available/supabase
server {
    listen 443 ssl http2;
    
    # TLS
    ssl_certificate /etc/letsencrypt/live/your-domain/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256;
    
    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header Referrer-Policy strict-origin-when-cross-origin;
    
    # Rate limiting
    limit_req zone=api burst=20 nodelay;
    limit_req_status 429;
    
    # Hide Supabase internals
    proxy_hide_header X-Powered-By;
    
    location / {
        proxy_pass http://localhost:8000;
    }
}

# Rate limit zone (in http block)
limit_req_zone $binary_remote_addr zone=api:10m rate=30r/m;
```

---

## 5. APP SIGNING + KEY MANAGEMENT

### Android
- [ ] Keystore stored in password manager + encrypted backup (not git)
- [ ] Separate keystores for debug / release
- [ ] `key.properties` in `.gitignore`
- [ ] GitLab CI: keystore as Protected + Masked CI variable (base64 encoded)

### iOS  
- [ ] Provisioning profiles stored in GitLab (encrypted)
- [ ] Fastlane Match recommended for team management
- [ ] Rotation plan: document expiry dates in RUNBOOK.md

---

## 6. DATA IN TRANSIT + AT REST

- [ ] All API calls HTTPS only — `http://` URLs in code = build failure (lint rule)
- [ ] WebSocket connections: `wss://` only in staging/prod
- [ ] WebRTC: DTLS-SRTP enforced (Supabase Realtime handles this, verify config)
- [ ] Local SQLite (if used): encrypt with SQLCipher
- [ ] SharedPreferences: no sensitive data. Use `flutter_secure_storage` for tokens
- [ ] Supabase Postgres: encrypted at rest (default in Docker setup — verify)

---

## 7. DEPENDENCY SECURITY

```bash
# Run before every release
flutter pub outdated --json | jq '.packages[] | select(.isDiscontinued)'
flutter pub audit  # when available

# Dart dependencies — check pub.dev security advisories
# Rust FFI deps
cargo audit

# Docker images
trivy image supabase/postgres:latest
trivy image supabase/gotrue:latest
```

- [ ] No dependencies with known CVEs in prod
- [ ] Pin exact versions in `pubspec.lock` committed to git
- [ ] Dependabot / Renovate enabled on GitLab repo

---

## 8. SECRETS SCANNING

```bash
# Pre-commit hook
gitleaks detect --source . --verbose

# CI gate (add to .gitlab-ci.yml)
secrets-scan:
  stage: security
  script:
    - gitleaks detect --source . --exit-code 1
  rules:
    - if: $CI_PIPELINE_SOURCE == "push"
```

**Patterns to block:**
- `SUPABASE_SERVICE_ROLE_KEY`
- `supabase_admin`
- Any 40+ char base64 string in source files
- `-----BEGIN RSA PRIVATE KEY-----`

---

## 9. SECURITY AUDIT SCHEDULE

| Frequency | Action |
|-----------|--------|
| Every commit | Gitleaks pre-commit hook |
| Every PR | `/devsecops` checklist in AGENT_GOD_MODE |
| Every release | `cargo audit` + `flutter pub audit` + Trivy |
| Monthly | RLS audit query (Section 4) |
| Quarterly | Rotate Supabase service role key |
| Annually | Full pentest (OWASP ZAP on staging) |

---

## 10. INCIDENT RESPONSE

**If key material leaked:**
1. Rotate immediately — don't investigate first, rotate first
2. Invalidate all active sessions (Supabase → Auth → Users → Sign out all)
3. Check GlitchTip for anomalous activity in past 72h
4. Document in ERRORS.md with timeline
5. Notify affected users if PII potentially exposed (legal requirement)

**If Supabase DB compromised:**
→ See RUNBOOK.md Section 4

---

## 11. COMPLIANCE & THREAT FRAMEWORK MAPPING

To align with modern AI-native cybersecurity standards, our security hardening protocols map directly across five industry standard frameworks: **MITRE ATT&CK, NIST CSF 2.0, MITRE ATLAS, MITRE D3FEND, and NIST AI RMF**.

| Hardening Protocol | MITRE ATT&CK | NIST CSF 2.0 | MITRE ATLAS | MITRE D3FEND | NIST AI RMF |
|---|---|---|---|---|---|
| **Section 1: Cert Pinning** | T1071 (C2 Channel) | PR.DS (Data Security) | AML.T0047 | D3-NTA (Net Traffic Anal.) | MEASURE-2.6 (Input Valid.) |
| **Section 2: Rust Key Zeroing** | T1003 (OS Cred Dump) | PR.DS (Protect Data) | AML.T0014 | D3-MUK (Mem Encrypt.) | GOVERN-1.2 (Privilege) |
| **Section 3: Device Integrity** | T1012 (Query Registry) | DE.CM (Monitoring) | AML.T0038 | D3-EDA (Device Audit) | MEASURE-2.4 (Runtime Def.) |
| **Section 4: Supabase RLS** | T1083 (File Discovery) | PR.AC (Access Control) | AML.T0002 | D3-ADA (Access Audit) | GOVERN-2.1 (Policies) |
| **Section 8: Secrets Scanning** | T1552 (Unsecured Creds) | ID.RA (Risk Assess) | AML.T0017 | D3-SCA (Credential Scan) | MEASURE-1.1 (Static Scan) |

---

*Security is not a feature. It's a precondition.*
