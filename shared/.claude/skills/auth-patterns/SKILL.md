# SKILL: Auth Patterns · v2026.10
> Load when: implementing authentication, authorization, or session management.
> Covers: OAuth 2.0, OpenID Connect, JWT, sessions, RBAC, MFA, SSO, passkeys

## DETECT FIRST
```bash
# Check which auth is in use
cat package.json | grep -E "passport|next-auth|auth0|supabase|firebase|clerk|lucia|kinde"
cat pubspec.yaml | grep -E "supabase|firebase_auth|auth0|appwrite"
grep -r "signIn\|signUp\|signOut\|login\|register" lib/ --include="*.dart" -l | head -5
grep -r "signIn\|signUp\|signOut\|login\|register" src/ --include="*.tsx" -l | head -5
```

---

## AUTH FLOW PATTERNS

### Session-based (traditional)
```typescript
// Server creates session, stores in DB/Redis, returns cookie
// ✅ Simple, revocable, no client-side token parsing
// ❌ Server state, scaling requires shared session store
POST /auth/login → { sessionId, cookie }
// Every request: verify cookie → lookup session → authorize
```

### JWT-based (stateless)
```typescript
// Server signs a token, client stores it, server verifies on each request
// ✅ No server session state, scales horizontally trivially
// ❌ Can't revoke without blocklist, token size, key rotation needed
// JWT payload
{
  "sub": "user_123",
  "email": "user@example.com",
  "role": "admin",
  "iat": 1700000000,
  "exp": 1700003600
}

// Verify middleware
function authenticate(req: Request, res: Response, next: NextFunction) {
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (!token) return res.status(401).json({ error: 'Unauthorized' });
  try {
    req.user = jwt.verify(token, process.env.JWT_SECRET!);
    next();
  } catch {
    return res.status(401).json({ error: 'Invalid token' });
  }
}
```

### OAuth 2.0 + OpenID Connect (third-party auth)
```typescript
// Authorization Code Flow (PKCE for mobile/SPA)
// 1. Client → Auth Provider: /authorize?response_type=code&...
// 2. User authenticates on provider's page
// 3. Auth Provider → Client: callback with authorization code
// 4. Client → Auth Provider: POST /token with code (exchanges for access_token + id_token)
// 5. Client uses access_token to call APIs

// PKCE (Proof Key for Code Exchange) — mandatory for mobile/SPA
const codeVerifier = generateRandomString(128);
const codeChallenge = await sha256(codeVerifier);
// Send codeChallenge in authorize request
// Send codeVerifier in token request — provider verifies match
```

### Supabase Auth (if detected)
```dart
// Built-in: email/password, OAuth (Google, Apple, GitHub), phone OTP, magic link
// All behind RLS — never trust client-side role alone

// Sign in
final result = await supabase.auth.signInWithPassword(email: email, password: password);

// Auth state listener
supabase.auth.onAuthStateChange.listen((event) {
  if (event.event == AuthChangeEvent.signedIn) {
    // Navigate to main app
  }
});

// OAuth
await supabase.auth.signInWithOAuth(Provider.google);
```

### Firebase Auth (if detected)
```dart
// Built-in: email/password, OAuth, phone, anonymous, custom tokens
// Security rules control data access — never trust client

await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
// OnAuthStateChanged listener for auth state stream
```

---

## AUTHORIZATION PATTERNS

### RBAC (Role-Based Access Control)
```typescript
// Roles: admin, moderator, user, guest
// Each role has permissions
const ROLES = {
  admin:    ['read', 'write', 'delete', 'manage_users'],
  moderator:['read', 'write', 'delete_own'],
  user:     ['read', 'write_own'],
  guest:    ['read'],
} as const;

function authorize(required: string[]) {
  return (req: Request, res: Response, next: NextFunction) => {
    const userRole = req.user.role;
    const hasAll = required.every(p => ROLES[userRole].includes(p));
    if (!hasAll) return res.status(403).json({ error: 'Forbidden' });
    next();
  };
}
```

### ABAC (Attribute-Based Access Control) — more granular
```typescript
// Policy: "Users can edit their own messages but not others'"
function canEditMessage(user: User, message: Message): boolean {
  if (user.role === 'admin') return true;
  if (message.authorId === user.id) return true;
  return false;
}
```

### Supabase RLS (Row-Level Security — if detected)
```sql
-- Every table MUST have RLS. No exceptions.
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

-- User can read messages in rooms they belong to
CREATE POLICY "user_messages_read" ON messages
  FOR SELECT USING (
    room_id IN (SELECT room_id FROM room_members WHERE user_id = auth.uid())
  );

-- User can send messages as themselves
CREATE POLICY "user_messages_insert" ON messages
  FOR INSERT WITH CHECK (sender_id = auth.uid());
```

---

## MFA / 2FA

### TOTP (Time-based One-Time Password)
```typescript
// Generate secret → show QR code → user scans in authenticator app
// Verify: user enters 6-digit code → server checks TOTP validity
import { authenticator } from 'otplib';

const secret = authenticator.generateSecret();
const token = authenticator.generate(secret);          // server
const isValid = authenticator.check(userInput, secret); // verify
```

### SMS / Email OTP
```typescript
// Generate 6-digit code, store with expiry (5 min), send, verify
// ⚠️ SMS is least secure — SS7 attacks, SIM swap
// ⚠️ Email OTP is more secure but slower
```

### Passkeys (WebAuthn) — newest, most secure
```typescript
// Platform authenticator (FaceID, TouchID, Windows Hello)
// Replaces passwords entirely — phishing-resistant
// Public key stored on server, private key on device
// Sign in: device signs challenge with private key → server verifies with public key
```

---

## SECURITY RULES

| Rule | Why |
|------|-----|
| Never store passwords in plaintext | bcrypt/argon2 with cost ≥ 12 |
| JWTs: short expiry (15min access, 7d refresh) | Limit window if compromised |
| Refresh token rotation | Old refresh token becomes invalid after use |
| Rate limit auth endpoints | 5 req/min per IP for login |
| Session invalidation on logout | Sign out from ALL devices |
| MFA for admin accounts | Critical protection |
| No sensitive data in JWT payload | JWT is signed, not encrypted |
| Key rotation every 90 days | Limit impact of key compromise |
| Audit log all auth events | Detect brute force / abuse |

---

## COMMON PITFALLS

- Storing JWT in localStorage (XSS vulnerable) — use httpOnly cookie
- No CSRF protection on cookie-based auth — use SameSite=Strict + CSRF token
- Trusting client-side role for authorization — always verify server-side
- Token in URL (exposed in server logs, referrer header)
- No rate limiting on auth endpoints (brute force)
- Infinite session lifetime (no expiry = permanent access if compromised)
- Email verification skipped in production (anyone can sign up as anyone)
