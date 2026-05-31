# SKILL: Backend Node.js · v2026.11
> Load when: Node.js/Express/Fastify/Hono/NestJS backend work.

## DETECT FIRST
```bash
cat package.json | grep -E '"express|fastify|hono|nestjs|koa|sails"'
ls src/routes src/controllers src/services src/repositories 2>/dev/null
npx tsc --version 2>/dev/null || node -e "console.log(process.version)"
```

## LAYERED ARCHITECTURE
```
routes/      → HTTP only (parse, call service, respond) — zero logic
services/    → business logic (no HTTP, no DB direct) — pure functions preferred
repositories/→ DB queries only — Prisma/Drizzle/Kysely queries
middleware/  → auth, validation, logging, error handling
lib/         → shared utilities, config, types
```

## FRAMEWORK-SPECIFIC SETUP

### Express
```typescript
// Route — thin wrapper, no business logic
router.post('/messages', authenticate, validate(MessageSchema), asyncHandler(async (req, res) => {
  const msg = await messageService.create(req.user.id, req.body);
  res.status(201).json(msg);
}));

// asyncHandler — prevents unhandled promise rejections
const asyncHandler = (fn: RequestHandler): RequestHandler =>
  (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);

// Validation middleware with Zod
const validate = (schema: ZodSchema) => (req: Request, res: Response, next: NextFunction) => {
  const r = schema.safeParse(req.body);
  if (!r.success) return res.status(400).json({ errors: r.error.flatten() });
  req.body = r.data;
  next();
};

// Global error handler (last middleware)
app.use((err: Error, _req: Request, res: Response, _: NextFunction) => {
  const status = err instanceof AppError ? err.statusCode : 500;
  const message = err instanceof AppError ? err.message : 'Internal server error';
  res.status(status).json({ error: message });
});
```

### Fastify
```typescript
// Fastify — faster, schema-based, built-in validation
import Fastify from 'fastify';
const app = Fastify({ logger: true });

app.post('/messages', {
  schema: {
    body: { type: 'object', required: ['content'], properties: { content: { type: 'string' } } },
    response: { 201: { type: 'object', properties: { id: { type: 'string' } } } },
  },
  preHandler: [authenticate],
}, async (req, rep) => {
  const msg = await messageService.create(req.user.id, req.body);
  return rep.code(201).send(msg);
});
```

### Hono — edge-ready, smallest bundle
```typescript
import { Hono } from 'hono';
import { bearerAuth } from 'hono/bearer-auth';
import { z } from 'zod';
import { zValidator } from '@hono/zod-validator';

const app = new Hono();
app.use('/api/*', bearerAuth({ token: process.env.API_TOKEN! }));
app.post('/messages', zValidator('json', MessageSchema), async (c) => {
  const body = c.req.valid('json');
  const msg = await messageService.create(c.get('userId'), body);
  return c.json(msg, 201);
});
```

## CONNECTION POOLING (Prisma/Drizzle)
```typescript
// Prisma — single instance, connection pooling via PgBouncer-compatible mode
import { PrismaClient } from '@prisma/client';
const globalForPrisma = globalThis as unknown as { prisma: PrismaClient };
export const db = globalForPrisma.prisma ?? new PrismaClient({
  log: process.env.NODE_ENV === 'development' ? ['query'] : ['error'],
});
if (process.env.NODE_ENV !== 'production') globalForPrisma.prisma = db;

// Drizzle — pool config
import { drizzle } from 'drizzle-orm/node-postgres';
import { Pool } from 'pg';
const pool = new Pool({ connectionString: process.env.DATABASE_URL, max: 20, idleTimeoutMillis: 30000 });
export const db = drizzle(pool, { logger: process.env.NODE_ENV === 'development' });
```

## GRACEFUL SHUTDOWN
```typescript
// Prevent dropped connections and data loss
async function shutdown(signal: string) {
  logger.info({ signal }, 'Shutting down gracefully');
  server.close(() => {
    logger.info('HTTP server closed');
    db.$disconnect().then(() => process.exit(0));
  });
  setTimeout(() => { logger.error('Forced shutdown'); process.exit(1); }, 30_000).unref();
}
process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
```

## STRUCTURED LOGGING (Pino)
```typescript
import pino from 'pino';
export const logger = pino({
  level: process.env.LOG_LEVEL ?? 'info',
  transport: process.env.NODE_ENV === 'development' ? { target: 'pino-pretty' } : undefined,
  redact: ['req.headers.authorization', 'req.body.password'],
});

// Request logging middleware
app.use(pinoHttp({ logger }));
```

## HEALTH CHECKS
```typescript
// Kubernetes/cloud-native health endpoints
app.get('/health/live', (_, res) => res.json({ status: 'ok' }));
app.get('/health/ready', async (_, res) => {
  try {
    await db.$queryRaw`SELECT 1`;
    res.json({ status: 'ok', db: 'connected' });
  } catch (e) {
    res.status(503).json({ status: 'error', db: e.message });
  }
});
```

## DEPENDENCY INJECTION (awilix — lightweight)
```typescript
import { createContainer, asClass, asFunction } from 'awilix';
const container = createContainer();
container.register({
  messageService: asClass(MessageService).singleton(),
  messageRepository: asClass(MessageRepository).singleton(),
  db: asFunction(() => db).singleton(),
});
// In route: const msgService = req.di.resolve('messageService');
```

## BACKGROUND JOBS (BullMQ)
```typescript
import { Queue, Worker } from 'bullmq';
const queue = new Queue('notifications', { connection: { host: 'localhost', port: 6379 } });
await queue.add('send-email', { userId: '123', template: 'welcome' }, { attempts: 3, backoff: { type: 'exponential', delay: 1000 } });

const worker = new Worker('notifications', async job => {
  logger.info({ jobId: job.id, data: job.data }, 'Processing job');
  await sendEmail(job.data);
}, { connection: { host: 'localhost', port: 6379 } });
```

## TESTING
```typescript
// Integration tests with supertest
import request from 'supertest';
import app from '../app';
import db from '../lib/db';
// Fixture: beforeAll → seed database, afterAll → truncate
describe('POST /api/messages', () => {
  it('returns 201 with valid body', async () => {
    const res = await request(app).post('/api/messages').send({ content: 'Hello' }).set('Authorization', 'Bearer test-token');
    expect(res.status).toBe(201);
    expect(res.body).toHaveProperty('id');
  });
  it('returns 400 without body', async () => {
    const res = await request(app).post('/api/messages').send({});
    expect(res.status).toBe(400);
  });
});

// Vitest config
import { defineConfig } from 'vitest/config';
export default defineConfig({
  test: { globals: true, environment: 'node', setupFiles: ['./test/setup.ts'], globalSetup: './test/global-setup.ts' },
});
```

## DATABASE (Prisma & Drizzle)
```typescript
// Always select specific fields — never bare findMany()
const msgs = await db.message.findMany({
  select: { id: true, content: true, createdAt: true, author: { select: { name: true } } },
  where: { roomId, deletedAt: null },
  orderBy: { createdAt: 'desc' },
  take: 50,
});
// Transactions
await db.$transaction([
  db.message.create({ data }),
  db.room.update({ where: { id: roomId }, data: { updatedAt: new Date() } }),
]);
```

## SECURITY (always enforce)
- `helmet()` — security headers (CSP, HSTS, X-Frame-Options)
- `cors({ origin: allowlist })` — explicit allowlist, never `*`
- Rate limiting: `express-rate-limit` (auth: 5/min, API: 100/min)
- Zod validation on every route — never trust `req.body`
- Parameterized queries / ORM — never string concat SQL
- Secrets: `process.env` only via validated env schema (`@t3-oss/env-core` or `envalid`)
- `cookie-parser` with `{ signed: true }` for session cookies
- CSRF protection with `csrf-csrf` double-submit pattern
