# SKILL: Security Audit · Flutter/Mobile · v2026.9
> Load when: running /devsecops, reviewing PRs with auth/crypto/network changes, or pre-release.

---

## QUICK SCAN

```bash
gitleaks detect --source . --no-git --verbose | grep -E "finding|RuleID" | head -20
flutter pub outdated --json | python3 -c "import sys,json; d=json.load(sys.stdin); print(f'Discontinued: {len([p for p in d.get(\"packages\",[]) if p.get(\"isDiscontinued\")])}')"
```

---

## OWASP MOBILE TOP 10 CHECKLIST

- [ ] M01 Improper Platform Usage: no private API calls, no root detection bypass
- [ ] M02 Insecure Data Storage: no tokens in SharedPreferences, use flutter_secure_storage
- [ ] M03 Insecure Communication: HTTPS only, certificate pinning (httpClient.badCertificateCallback = false)
- [ ] M04 Insecure Authentication: session timeout on app background, biometric lock for sensitive screens
- [ ] M05 Insufficient Cryptography: AES-256-GCM, not ECB; key in secure enclave not source
- [ ] M06 Insecure Authorization: RLS on every table, server-side permission check for all mutations
- [ ] M07 Client Code Quality: no `print()` in prod, no debug flags gating auth logic
- [ ] M08 Code Tampering: code obfuscation (`--obfuscate --split-debug-info`), APK signature verification
- [ ] M09 Reverse Engineering: ProGuard/R8 rules, no API keys in source (env only)
- [ ] M10 Extraneous Functionality: no debug endpoints in release build, no admin bypass

---

## DART/FLUTTER PATTERNS TO FLAG

```bash
# Critical — fail audit if any found
grep -rn "http://" lib/ --include="*.dart" | grep -v "localhost\|127.0.0.1\|//TODO"
# ↑ HTTP (not HTTPS) in production code

grep -rn "kDebugMode\s*==" lib/ --include="*.dart"
# ↑ Auth logic gated on debug mode only

grep -rn "allowBadCertificates\|badCertificateCallback.*true" lib/
# ↑ Certificate validation disabled

grep -rn "SharedPreferences" lib/ | grep -iE "token|key|secret|password"
# ↑ Sensitive data in SharedPreferences — use flutter_secure_storage

grep -rn "\.insert\b\|\.upsert\b" lib/ | grep "\${"
# ↑ String interpolation in DB queries — SQL injection risk

grep -rn "print(" lib/ | grep -v "//\|^\s*//"
# ↑ Print statements in production code

grep -rn "service_role" lib/ dart_tool/
# ↑ Service role key in app — critical vulnerability
```

---

## SUPABASE SECURITY AUDIT QUERIES

```sql
-- 1. Tables without RLS
SELECT tablename FROM pg_tables WHERE schemaname = 'public'
AND tablename NOT IN (SELECT tablename FROM pg_policies WHERE schemaname = 'public');

-- 2. Overly permissive policies (qual = 'true')
SELECT tablename, policyname, cmd, qual FROM pg_policies
WHERE qual = 'true' OR with_check = 'true';

-- 3. Superusers (should only be postgres)
SELECT usename, usesuper FROM pg_user WHERE usesuper = true;

-- 4. Unconfirmed accounts older than 7 days
SELECT email, created_at FROM auth.users
WHERE email_confirmed_at IS NULL AND created_at < NOW() - INTERVAL '7 days';

-- 5. Recent failed logins (brute force detection)
SELECT ip_address, count(*) as failures
FROM auth.audit_log_entries
WHERE payload->>'action' = 'login_failed'
AND created_at > NOW() - INTERVAL '24 hours'
GROUP BY ip_address HAVING count(*) > 10 ORDER BY failures DESC;
```

---

## PRE-RELEASE SECURITY GATE

All must pass before production release:

```
[ ] gitleaks: 0 findings
[ ] flutter pub outdated: no discontinued packages
[ ] HTTP URLs in code: 0 (except localhost in dev)
[ ] SharedPreferences + sensitive data: 0 matches
[ ] Print statements in lib/: 0 (except dev guards)
[ ] Certificate pinning: verified
[ ] Service role key: NOT in app code or git
[ ] RLS audit query: empty result (no tables without RLS)
[ ] flutter build --release --obfuscate: success
[ ] Rate limiting: configured on auth + sensitive endpoints
[ ] Session timeout on app background: configured
[ ] flutter_secure_storage used for all tokens
```
