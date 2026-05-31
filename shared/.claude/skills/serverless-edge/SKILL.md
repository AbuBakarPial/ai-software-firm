# SKILL: Serverless & Edge · v2026.10
> Load when: deploying to serverless platforms, writing edge functions, or using serverless databases.
> Covers: Vercel Edge, Cloudflare Workers, Lambda, serverless DBs (Neon, Turso), cold starts

## DETECT FIRST
```bash
cat package.json | grep -E "vercel|@cloudflare|aws-lambda|serverless|neon|turso|planetscale|sst|wrangler"
ls vercel.json wrangler.toml serverless.yml 2>/dev/null
grep -r "export const config.*runtime.*edge\|runtime:.*edge" app/ --include="*.tsx" -l | head -3
```

---

## EDGE FUNCTIONS OVERVIEW

| Platform | Runtime | Cold Start | Max Duration | Regions |
|----------|---------|-----------|-------------|---------|
| Vercel Edge | Edge (V8) | ~5ms | 30s (hobby), 300s (pro) | Global (default) |
| Vercel Serverless | Node.js | ~50-500ms | 10s (hobby), 900s (pro) | Single region |
| Cloudflare Workers | V8 Isolates | ~1ms | 30s (free), 15min (paid) | 300+ locations |
| AWS Lambda | Node/Python/Go/Rust | ~200ms-1s | 15min | Per-region |
| Deno Deploy | Deno (V8) | ~5ms | 60s | 30+ locations |

### What runs well on Edge
- Authentication checks (JWT verify, session lookup)
- API request validation (Zod parsing)
- URL rewrites/redirects
- A/B testing routing
- Static asset serving
- Realtime small payloads (WebSocket upgrade)
- Cache API responses at edge

### What does NOT run on Edge
- Heavy computation (image processing, PDF generation)
- Database queries with connection pooling (most ORMs)
- Long-running WebSocket connections
- File system access
- Native Node.js modules (fs, crypto with randomUUID, etc.)

---

## VERCEL EDGE FUNCTIONS

### Setup
```typescript
// app/api/chat/route.ts — automatically deployed as Edge by Vercel
export const runtime = 'edge';  // ← this enables Edge runtime

export async function POST(req: Request) {
  const body = await req.json();
  const parsed = MessageSchema.safeParse(body);
  if (!parsed.success) {
    return Response.json({ error: parsed.error.flatten() }, { status: 400 });
  }

  // Edge-compatible DB query (via HTTP, not TCP)
  const result = await neonQuery(
    'SELECT * FROM messages WHERE room_id = $1',
    [parsed.data.roomId],
  );

  return Response.json(result, {
    status: 200,
    headers: {
      'Cache-Control': 's-maxage=60, stale-while-revalidate=120',
    },
  });
}

// Edge config — cache, regions, duration
export const config = {
  runtime: 'edge',
  regions: ['iad1'],  // deploy to specific region(s)
};
```

### Vercel Configuration
```json
// vercel.json
{
  "functions": {
    "app/api/chat/*.ts": {
      "maxDuration": 30,
      "memory": 1024
    }
  }
}
```

---

## CLOUDFLARE WORKERS

### Setup
```typescript
// wrangler.toml
name = "api"
main = "src/index.ts"
compatibility_date = "2026-05-01"

[env.production]
vars = { SUPABASE_URL = "https://project.supabase.co" }
```

```typescript
// src/index.ts — Cloudflare Worker
import { z } from 'zod';

const MessageSchema = z.object({
  roomId: z.string().uuid(),
  content: z.string().min(1).max(4096),
});

export default {
  async fetch(req: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const url = new URL(req.url);
    const headers = {
      'Access-Control-Allow-Origin': '*',
      'Content-Type': 'application/json',
    };

    if (req.method === 'POST' && url.pathname === '/api/messages') {
      const body = await req.json();
      const parsed = MessageSchema.safeParse(body);
      if (!parsed.success) {
        return new Response(JSON.stringify({ error: parsed.error }), {
          status: 400, headers,
        });
      }

      // KV store (edge-native key-value)
      await env.MESSAGES_KV.put(
        `msg:${crypto.randomUUID()}`,
        JSON.stringify(parsed.data),
        { expirationTtl: 86400 },
      );

      return new Response(JSON.stringify({ success: true }), {
        status: 201, headers,
      });
    }

    return new Response('Not Found', { status: 404 });
  },
};
```

### Durable Objects (stateful edge)
```typescript
// Durable Objects — single-writer consistency at edge
export class ChatRoom implements DurableObject {
  private messages: Message[] = [];

  async fetch(req: Request): Promise<Response> {
    if (req.method === 'POST') {
      const msg = await req.json() as Message;
      this.messages.push(msg);
      return new Response(JSON.stringify(msg), { status: 201 });
    }
    return new Response(JSON.stringify(this.messages));
  }
}
```

---

## SERVERLESS DATABASES

### Neon (serverless PostgreSQL — Vercel Edge compatible)
```typescript
import { neon } from '@neondatabase/serverless';

// HTTP-based — works in edge runtime (no TCP needed)
const sql = neon(process.env.DATABASE_URL!);

// Query via HTTP
const messages = await sql`
  SELECT id, content, created_at
  FROM messages
  WHERE room_id = ${roomId}
  ORDER BY created_at DESC
  LIMIT 50
`;
```

### Turso (serverless SQLite — edge-native)
```typescript
import { createClient } from '@libsql/client';

const db = createClient({
  url: process.env.TURSO_DATABASE_URL!,
  authToken: process.env.TURSO_AUTH_TOKEN,
});

const messages = await db.execute({
  sql: 'SELECT id, content, created_at FROM messages WHERE room_id = ? ORDER BY created_at DESC LIMIT 50',
  args: [roomId],
});
```

### Supabase (serverless Postgres via REST)
```typescript
// Works on edge — uses HTTP, not TCP
const supabase = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_ANON_KEY!,
  { global: { headers: { Authorization: `Bearer ${token}` } } },
);

const { data } = await supabase
  .from('messages')
  .select('id, content, created_at')
  .eq('room_id', roomId)
  .order('created_at', { ascending: false })
  .limit(50);
```

### PlanetScale (serverless MySQL)
```typescript
import { connect } from '@planetscale/database';

const conn = connect({ url: process.env.DATABASE_URL! });

const results = await conn.execute(
  'SELECT id, content, created_at FROM messages WHERE room_id = ? ORDER BY created_at DESC LIMIT 50',
  [roomId],
);
```

---

## COLD START OPTIMIZATION

```typescript
// 1. Minimize dependencies — each import adds ~50ms
// ❌ Bad
import { createClient } from '@supabase/supabase-js';
import { z } from 'zod';
import jwt from 'jsonwebtoken';

// ✅ Good — use built-in Web APIs where possible
const encoder = new TextEncoder();
const key = await crypto.subtle.importKey('raw', secret, { name: 'HMAC', hash: 'SHA-256' }, false, ['verify']);
const valid = await crypto.subtle.verify('HMAC', key, signature, encoder.encode(payload));
```

### Warm-up Strategies
```typescript
// Vercel: Cron job to keep function warm
// vercel.json
{
  "crons": [
    { "path": "/api/warmup", "schedule": "*/5 * * * *" }
  ]
}

// Cloudflare: Workers stay warm naturally (no action needed)
// AWS Lambda: Provisioned Concurrency (paid)
```

---

## EDGE-SAFE PATTERNS

### ✅ Edge-safe
```typescript
// Web Crypto (built-in)
const hash = await crypto.subtle.digest('SHA-256', data);

// Fetch API (built-in)
const response = await fetch('https://api.example.com', { headers });

// WebSocket (Cloudflare + Vercel support)
const ws = new WebSocket('wss://example.com');

// KV / D1 / R2 (Cloudflare storage)
await env.KV.put('key', 'value');

// Neon HTTP (serverless Postgres via HTTP)
const result = await sql`SELECT 1`;
```

### ❌ NOT edge-safe
```typescript
// Node.js fs module
import fs from 'fs';           // ❌

// TCP-based database drivers
import { Client } from 'pg';   // ❌ — needs TCP socket

// Long-running processes
setInterval(() => {}, 1000);   // ❌ — edge functions have short timeout

// Express/Fastify patterns
app.listen(3000);              // ❌ — edge is request/response model
```

---

## EDGE DEPLOYMENT COMMANDS

```bash
# Vercel
vercel deploy --prod
vercel env pull
vercel logs --follow

# Cloudflare
npx wrangler deploy
npx wrangler tail            # realtime logs
npx wrangler kv:key put key value --binding=KV

# Serverless Framework (multi-cloud)
serverless deploy --stage prod
serverless logs -f hello
```

---

## EDGE PRODUCTION CHECKLIST

- [ ] No Node.js-specific APIs (fs, net, tls, crypto (subtle is OK))
- [ ] Database connection via HTTP (Neon, Turso, Supabase REST)
- [ ] Cold start time measured (target < 50ms)
- [ ] Appropriate region selection (closest to users)
- [ ] Cache-Control headers set on all responses
- [ ] Rate limiting implemented (edge-native or via platform)
- [ ] Secrets via environment variables (platform-native)
- [ ] Graceful degradation when DB is slow (timeouts, fallbacks)
- [ ] Bundle size optimized (import only what's needed)
- [ ] Runtime logging (console.log goes to platform logs)
- [ ] Error responses are structured JSON, not HTML
