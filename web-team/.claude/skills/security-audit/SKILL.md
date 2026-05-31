# SKILL: Security Audit · Web · v2026.11
> Load when: pre-release, auth changes, new API endpoints, or /devsecops command.
> Covers: OWASP Top 10 web, Next.js-specific, API security, secrets, headers, rate limiting

## QUICK SCAN (run before every release)
```bash
#!/bin/bash
echo "=== WEB SECURITY AUDIT ==="

# 1. Secret scan
echo "[1/5] Scanning for secrets..."
gitleaks detect --source . --exit-code 1 --no-git 2>&1 | grep -E "finding|RuleID" | head -20

# 2. Dependency audit
echo "[2/5] Dependency vulnerabilities..."
npm audit --audit-level high
# Check for known critical packages
npx audit-ci --high

# 3. Bundle analysis — check for secrets baked into client bundle
echo "[3/5] Bundle analysis..."
ANALYZE=true next build 2>&1 | grep -E "warning|Warning" | head -20

# 4. OWASP ZAP quick scan (requires running app)
echo "[4/5] OWASP ZAP baseline (staging only)..."
# docker run -t owasp/zap2docker-stable zap-baseline.py -t https://staging.example.com

# 5. TypeScript strict check
echo "[5/5] Type safety..."
npx tsc --noEmit

echo "=== AUDIT COMPLETE ==="
```

---

## OWASP TOP 10 — Next.js/React Mapping

| Risk | Web manifestation | Check | Fix |
|------|-------------------|-------|-----|
| A01 Broken Access Control | Routes accessible without auth | `grep -r "middleware" src/` — every `/api` and protected route covered? | Centralize auth in `middleware.ts` |
| A02 Crypto Failures | Tokens in localStorage or URL | `grep -r "localStorage" src/ \| grep -iE "token\|key\|auth"` | httpOnly cookies only |
| A03 Injection | Raw SQL, eval(), dangerouslySetInnerHTML | `grep -r "dangerouslySetInnerHTML\|eval(" src/` | Zod validation + parameterized queries |
| A04 Insecure Design | No rate limiting on auth | Check `/api/auth/*` routes | `next-rate-limit` or Upstash Ratelimit |
| A05 Misconfiguration | Missing security headers | `curl -sI https://domain.com \| grep -E "CSP\|HSTS\|X-Frame"` | Add headers in `next.config.js` |
| A06 Vulnerable Components | Outdated deps with CVEs | `npm audit` | Pin + update; run weekly |
| A07 Auth Failures | No session invalidation on logout | `signOut()` clears cookies server-side? | NextAuth `signOut` + invalidate session server-side |
| A08 Integrity Failures | No SRI on CDN scripts | `grep -r "cdn\|unpkg\|cdnjs" public/` | Add `integrity=` attribute |
| A09 Logging | PII in logs | `grep -r "console.log\|logger" src/ \| grep -iE "email\|password\|token"` | Log user IDs only |
| A10 SSRF | Arbitrary URL fetch | `grep -r "fetch(req\|fetch(url" src/app/api/ ` | Allowlist valid domains |

---

## NEXT.JS SPECIFIC SECURITY

### middleware.ts — Protect every route centrally
```typescript
// middleware.ts (root)
import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';

const PUBLIC_ROUTES = new Set(['/', '/login', '/signup', '/api/auth']);
const ADMIN_ROUTES = ['/admin', '/api/admin'];

export function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;

  // CSRF: reject non-GET API requests without proper origin
  if (pathname.startsWith('/api/') && !['GET', 'HEAD', 'OPTIONS'].includes(request.method)) {
    const origin = request.headers.get('origin');
    const host = request.headers.get('host');
    if (origin && !origin.endsWith(host ?? '')) {
      return NextResponse.json({ error: 'Forbidden' }, { status: 403 });
    }
  }

  // Auth gate
  if (PUBLIC_ROUTES.has(pathname) || pathname.startsWith('/api/auth')) {
    return NextResponse.next();
  }

  const token = request.cookies.get('session')?.value;
  if (!token) {
    return NextResponse.redirect(new URL('/login', request.url));
  }

  // Admin gate
  if (ADMIN_ROUTES.some(r => pathname.startsWith(r))) {
    // Verify admin role from JWT claims
    const payload = verifyToken(token);
    if (payload?.role !== 'admin') {
      return NextResponse.json({ error: 'Forbidden' }, { status: 403 });
    }
  }

  return NextResponse.next();
}

export const config = {
  matcher: ['/((?!_next/static|_next/image|favicon.ico).*)'],
};
```

### Security Headers — next.config.js
```javascript
// next.config.js
const securityHeaders = [
  { key: 'X-Frame-Options', value: 'DENY' },
  { key: 'X-Content-Type-Options', value: 'nosniff' },
  { key: 'X-DNS-Prefetch-Control', value: 'off' },
  { key: 'Strict-Transport-Security', value: 'max-age=63072000; includeSubDomains; preload' },
  { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
  { key: 'Permissions-Policy', value: 'camera=(), microphone=(), geolocation=(), interest-cohort=()' },
  {
    key: 'Content-Security-Policy',
    value: [
      "default-src 'self'",
      "script-src 'self' 'nonce-{NONCE}'",   // nonces injected per-request
      "style-src 'self' 'unsafe-inline'",      // Tailwind requires this
      "img-src 'self' data: blob: https:",
      "font-src 'self'",
      "connect-src 'self' https://api.example.com wss://api.example.com",
      "frame-ancestors 'none'",
    ].join('; '),
  },
];

module.exports = {
  async headers() {
    return [{ source: '/(.*)', headers: securityHeaders }];
  },
  // Never expose .env values to client unless NEXT_PUBLIC_ prefix
  // Audit: grep -r "process.env" src/ | grep -v "NEXT_PUBLIC_" | grep -v "server"
};
```

### Rate Limiting — Upstash (serverless-compatible)
```typescript
// lib/rate-limit.ts
import { Ratelimit } from '@upstash/ratelimit';
import { Redis } from '@upstash/redis';

export const authRateLimit = new Ratelimit({
  redis: Redis.fromEnv(),
  limiter: Ratelimit.slidingWindow(5, '15 m'), // 5 attempts per 15 min
  analytics: true,
  prefix: 'auth',
});

export const apiRateLimit = new Ratelimit({
  redis: Redis.fromEnv(),
  limiter: Ratelimit.slidingWindow(100, '1 m'),
  analytics: true,
  prefix: 'api',
});

// In API route
export async function POST(req: NextRequest) {
  const ip = req.headers.get('x-forwarded-for') ?? 'anonymous';
  const { success, limit, reset, remaining } = await authRateLimit.limit(ip);

  if (!success) {
    return NextResponse.json(
      { error: 'Too many requests' },
      {
        status: 429,
        headers: {
          'X-RateLimit-Limit': String(limit),
          'X-RateLimit-Remaining': String(remaining),
          'X-RateLimit-Reset': String(reset),
          'Retry-After': String(Math.ceil((reset - Date.now()) / 1000)),
        },
      }
    );
  }
  // proceed
}
```

### Input Validation — Zod everywhere
```typescript
// EVERY API route validates input with Zod — no exceptions
import { z } from 'zod';

const createUserSchema = z.object({
  email: z.string().email().max(254).toLowerCase().trim(),
  password: z.string().min(8).max(128),
  name: z.string().min(1).max(100).trim(),
});

export async function POST(req: NextRequest) {
  const body = await req.json().catch(() => null);
  if (!body) return NextResponse.json({ error: 'Invalid JSON' }, { status: 400 });

  const parsed = createUserSchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json(
      { error: 'Validation failed', details: parsed.error.flatten() },
      { status: 422 }
    );
  }
  // parsed.data is now type-safe
}
```

### Environment Variable Audit
```bash
# Audit: no server secrets exposed to client bundle
grep -r "process.env" src/ --include="*.tsx" --include="*.ts" |
  grep -v "NEXT_PUBLIC_" |
  grep -v "// server" |
  grep -v "route.ts\|actions.ts\|middleware.ts\|server" |
  grep "process.env"
# Any results here = potential secret exposure in client bundle
```

---

## AUTHENTICATION — Secure Patterns

```typescript
// Cookies: httpOnly + secure + sameSite — never localStorage
const cookieOptions = {
  httpOnly: true,           // no JS access — prevents XSS token theft
  secure: process.env.NODE_ENV === 'production',
  sameSite: 'lax' as const, // CSRF protection
  path: '/',
  maxAge: 60 * 60 * 24 * 7, // 1 week
};

// Session invalidation — server-side token revocation list or DB
async function logout(sessionId: string) {
  await db.session.delete({ where: { id: sessionId } }); // invalidate server-side
  // Then clear cookie
  cookies().delete('session');
}
```

---

## PRE-RELEASE CHECKLIST

```
[ ] gitleaks detect: 0 findings
[ ] npm audit: 0 critical/high
[ ] All API routes validate input with Zod
[ ] All protected routes covered in middleware.ts
[ ] No tokens in localStorage (httpOnly cookies only)
[ ] Security headers returning on all pages (curl -sI)
[ ] Rate limiting on auth + sensitive endpoints
[ ] CORS configured — not wildcard (*) in production
[ ] No process.env secrets leaking to client bundle
[ ] Error responses don't expose stack traces or internal paths
[ ] dangerouslySetInnerHTML: 0 occurrences (or each justified)
[ ] No eval(), new Function(), document.write()
[ ] SRI attributes on any third-party CDN scripts
```
