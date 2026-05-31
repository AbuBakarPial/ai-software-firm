# SKILL: Security Audit · v2026.8
> Load when: running /devsecops, reviewing PRs with auth/crypto/network changes, or pre-release.

---

## QUICK AUDIT CHECKLIST (run before every release)

```bash
#!/bin/bash
echo "=== SECURITY AUDIT ==="

# 1. Secret scan
echo "[1/6] Scanning for secrets..."
gitleaks detect --source . --no-git --verbose 2>&1 | grep -E "finding|RuleID" | head -20

# 2. Flutter dependencies
echo "[2/6] Flutter dependency audit..."
flutter pub outdated --json 2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
discontinued = [p for p in data.get('packages',[]) if p.get('isDiscontinued')]
print(f'Discontinued packages: {len(discontinued)}')
for p in discontinued: print(f'  ✗ {p[\"package\"]}')
"

# 3. Rust dependencies
echo "[3/6] Rust dependency audit..."
cargo audit 2>&1 | grep -E "error\[|warning\[" | head -20

# 4. RLS audit
echo "[4/6] Supabase RLS check..."
echo "Run manually in Supabase SQL editor:"
echo "SELECT tablename FROM pg_tables WHERE schemaname='public'"
echo "AND tablename NOT IN (SELECT tablename FROM pg_policies WHERE schemaname='public');"

# 5. Docker image scan
echo "[5/6] Container scan..."
trivy image --exit-code 1 --severity CRITICAL supabase/postgres:latest 2>&1 | tail -10

# 6. Nginx config check
echo "[6/6] Nginx security headers..."
curl -sI https://your-domain.com | grep -E "Strict-Transport|X-Frame|X-Content|Referrer"

echo "=== AUDIT COMPLETE ==="
```

---

## OWASP TOP 10 FLUTTER/SUPABASE MAPPING

| OWASP Risk | Flutter manifestation | Check |
|------------|----------------------|-------|
| A01 Broken Access Control | Missing RLS policies | SQL audit query (Section 4, SECURITY_HARDENING.md) |
| A02 Cryptographic Failures | Storing tokens in SharedPreferences | `grep -r "SharedPreferences" lib/ \| grep -i "token\|key\|secret"` |
| A03 Injection | String interpolation in Supabase queries | `grep -r "\.eq(\|\.filter(\|\.rpc(" lib/` → no raw user input |
| A04 Insecure Design | No rate limiting | Nginx rate limit config present? |
| A05 Security Misconfiguration | Service role key in app code | `grep -r "service_role" lib/ dart_tool/` → must be empty |
| A06 Vulnerable Components | Outdated deps | `flutter pub outdated` |
| A07 Auth Failures | No session invalidation on logout | `supabase.auth.signOut()` calls `scope: SignOutScope.global`? |
| A08 Software Integrity | Unsigned APK | Release signed with keystore, not debug key |
| A09 Logging Failures | Sensitive data in logs | `grep -r "debugPrint\|print(" lib/ \| grep -iE "password\|token\|key"` |
| A10 SSRF | Arbitrary URL fetch | `http.get(userInput)` patterns → must not exist |

---

## DART/FLUTTER SPECIFIC PATTERNS TO FLAG

```bash
# Critical findings — fail the audit if any found
grep -rn "http://" lib/ --include="*.dart" | grep -v "localhost\|127.0.0.1\|//TODO\|//"
# ↑ HTTP (not HTTPS) in production code

grep -rn "kDebugMode\s*==" lib/ --include="*.dart"
# ↑ Auth logic gated on debug mode only

grep -rn "allowBadCertificates\|badCertificateCallback.*true" lib/ --include="*.dart"
# ↑ Certificate validation disabled

grep -rn "SharedPreferences" lib/ --include="*.dart" | grep -iE "token|key|secret|password"
# ↑ Sensitive data in SharedPreferences

grep -rn "\.insert\b" lib/ --include="*.dart" | grep "\${"
# ↑ String interpolation in DB queries

grep -rn "print(" lib/ --include="*.dart" | grep -v "//\|^\s*//"
# ↑ Print statements left in production code
```

---

## RUST FFI SECURITY PATTERNS

```bash
# Check for missing zeroize
grep -rn "struct.*Key\|struct.*Secret\|struct.*Password" src/ | grep -v "#\[derive"
# ↑ Key structs without zeroize derive

# Check for unwrap in FFI boundary
grep -rn "\.unwrap()" src/ffi/ | grep -v "#\[cfg(test)\]"
# ↑ Panic risk at FFI boundary — use match or ? operator

# Check no_mangle functions log sensitive data
grep -A 20 "#\[no_mangle\]" src/ | grep -iE "println!\|dbg!\|log::"
# ↑ Logging at FFI boundary — verify no key material logged
```

---

## SUPABASE SECURITY AUDIT QUERIES

```sql
-- 1. Tables without RLS
SELECT tablename 
FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename NOT IN (
  SELECT tablename FROM pg_policies WHERE schemaname = 'public'
);
-- Expected: empty result

-- 2. Overly permissive policies
SELECT tablename, policyname, cmd, qual 
FROM pg_policies 
WHERE qual = 'true' OR with_check = 'true';
-- Flag any policy with qual='true' (allows all rows)

-- 3. Check for superusers (should only be postgres)
SELECT usename, usesuper FROM pg_user WHERE usesuper = true;

-- 4. Check auth.users for unconfirmed accounts older than 7 days
SELECT email, created_at 
FROM auth.users 
WHERE email_confirmed_at IS NULL 
AND created_at < NOW() - INTERVAL '7 days';

-- 5. Recent failed logins (brute force detection)
SELECT ip_address, count(*) as failures
FROM auth.audit_log_entries
WHERE payload->>'action' = 'login_failed'
AND created_at > NOW() - INTERVAL '24 hours'
GROUP BY ip_address
HAVING count(*) > 10
ORDER BY failures DESC;
```

---

## PRE-RELEASE SECURITY GATE

All must pass before production release:

```
[ ] gitleaks: 0 findings
[ ] cargo audit: 0 critical/high
[ ] flutter pub outdated: no discontinued packages
[ ] Trivy: 0 CRITICAL in base images
[ ] RLS audit query: empty result
[ ] HTTP URLs in code: 0 (except localhost in dev)
[ ] SharedPreferences + sensitive data: 0 matches
[ ] Print statements in lib/: 0 (except dev guards)
[ ] Certificate pinning: verified with mitmproxy (MITRE T1071 / NIST PR.DS)
[ ] Root detection: tested on rooted test device (MITRE T1012 / NIST DE.CM)
[ ] Rate limiting: nginx config present and tested (MITRE ATLAS / NIST AI RMF)
[ ] Service role key: NOT in app code or git (MITRE T1552 / NIST PR.AC)
[ ] Five-Framework Alignment: verified full mapping to MITRE ATT&CK, NIST CSF 2.0, MITRE ATLAS, MITRE D3FEND, and NIST AI RMF
```
