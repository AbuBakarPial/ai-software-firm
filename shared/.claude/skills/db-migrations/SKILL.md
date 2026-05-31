# SKILL: Database Migrations · v2026.11
> Load when: adding/altering tables, writing migrations, seeding data, or planning zero-downtime schema changes.
> Covers: Prisma, Alembic, Flyway, raw SQL, zero-downtime patterns, rollback, Supabase migrations

## DETECT FIRST
```bash
# Which migration tool?
ls prisma/migrations/ 2>/dev/null && echo "Prisma"
ls alembic/ alembic.ini 2>/dev/null && echo "Alembic"
ls db/migrations/ flyway.conf 2>/dev/null && echo "Flyway"
ls supabase/migrations/ 2>/dev/null && echo "Supabase CLI"
cat package.json | grep -E "knex|db-migrate|typeorm|drizzle"
cat pubspec.yaml | grep -E "drift|sqflite"

# Current state
npx prisma migrate status 2>/dev/null
alembic current 2>/dev/null
```

---

## CARDINAL RULES

| Rule | Why |
|------|-----|
| **Never edit a committed migration** | Other devs/envs already ran it — you'll break history |
| **One logical change per migration** | Atomic rollback, readable history |
| **Migrations run in CI before deploy** | Never migrate prod manually |
| **Always write DOWN migration** | Rollback must be possible |
| **Test migration on prod data clone** | Prod has edge cases staging doesn't |
| **Zero-downtime for columns/tables used by live traffic** | See expand-contract pattern below |

---

## PRISMA (Node.js)

```bash
# Create migration (generates SQL, does NOT run it)
npx prisma migrate dev --name add_user_avatar_url --create-only

# Review generated SQL before applying
cat prisma/migrations/20260531_add_user_avatar_url/migration.sql

# Apply in dev
npx prisma migrate dev

# Apply in production (never use migrate dev in prod)
npx prisma migrate deploy

# Check status
npx prisma migrate status

# Rollback — Prisma has no built-in rollback
# Write a new migration that reverses the change
```

```prisma
// schema.prisma — adding nullable column first (safe), backfill, then make required
model User {
  id        String   @id @default(cuid())
  email     String   @unique
  avatarUrl String?  // ← Step 1: nullable
  // Step 2 (after backfill): avatarUrl String
  createdAt DateTime @default(now())
}
```

---

## ALEMBIC (Python/SQLAlchemy)

```bash
# Init
alembic init alembic

# Generate auto-detected migration
alembic revision --autogenerate -m "add_user_avatar_url"

# Always review — autogenerate misses: computed columns, partial indexes, custom types
cat alembic/versions/<hash>_add_user_avatar_url.py

# Apply
alembic upgrade head

# Rollback one
alembic downgrade -1

# Rollback to specific
alembic downgrade abc123def456

# History
alembic history --verbose
```

```python
# alembic/versions/abc123_add_user_avatar_url.py
from alembic import op
import sqlalchemy as sa

def upgrade() -> None:
    op.add_column('users', sa.Column('avatar_url', sa.String(500), nullable=True))
    # Backfill if needed
    op.execute("UPDATE users SET avatar_url = '' WHERE avatar_url IS NULL")
    # Then tighten constraint in separate migration

def downgrade() -> None:
    op.drop_column('users', 'avatar_url')
```

---

## SUPABASE MIGRATIONS

```bash
# Create migration file
supabase migration new add_user_avatar_url

# Edit supabase/migrations/<timestamp>_add_user_avatar_url.sql
# Apply to local
supabase db reset  # wipes + replays all migrations

# Apply to remote (staging/prod)
supabase db push --linked

# Check diff (schema drift detection)
supabase db diff --linked

# Pull remote changes into local
supabase db pull
```

```sql
-- supabase/migrations/20260531120000_add_user_avatar_url.sql
-- UP (no explicit down in Supabase CLI — write reversible migrations)

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS avatar_url TEXT;

-- Backfill default
UPDATE public.users SET avatar_url = '' WHERE avatar_url IS NULL;

-- Update RLS policies if column affects them
-- (always check: does this column need row-level security?)
```

---

## ZERO-DOWNTIME: EXPAND-CONTRACT PATTERN

**Never** do `ALTER TABLE ... DROP COLUMN` on a live table. Use this sequence:

### Phase 1: EXPAND (safe deploy)
```sql
-- Add new column nullable (old code ignores it, new code writes it)
ALTER TABLE orders ADD COLUMN status_v2 TEXT;
```

### Phase 2: BACKFILL (run as background job, not in migration)
```typescript
// Backfill in batches — never one giant UPDATE
async function backfillStatusV2() {
  let lastId = '';
  while (true) {
    const batch = await db.query(
      `UPDATE orders SET status_v2 = status
       WHERE id > $1 AND status_v2 IS NULL
       ORDER BY id LIMIT 1000
       RETURNING id`,
      [lastId]
    );
    if (batch.rows.length === 0) break;
    lastId = batch.rows[batch.rows.length - 1].id;
    await sleep(100); // backpressure — don't hammer DB
  }
}
```

### Phase 3: CONTRACT (after backfill verified)
```sql
-- Add NOT NULL constraint ONLY after backfill complete
ALTER TABLE orders ALTER COLUMN status_v2 SET NOT NULL;

-- Add constraint with validation in postgres 12+ (non-blocking)
ALTER TABLE orders ADD CONSTRAINT status_v2_not_empty CHECK (status_v2 <> '') NOT VALID;
ALTER TABLE orders VALIDATE CONSTRAINT status_v2_not_empty;
```

### Phase 4: CLEANUP (separate deploy, old column unused for 1+ week)
```sql
-- Now safe to drop old column
ALTER TABLE orders DROP COLUMN status;
ALTER TABLE orders RENAME COLUMN status_v2 TO status;
```

---

## INDEX MIGRATIONS — Non-blocking (Postgres)

```sql
-- WRONG: blocks table for minutes on large tables
CREATE INDEX idx_orders_user_id ON orders(user_id);

-- CORRECT: CONCURRENTLY — no table lock, safe on live traffic
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_orders_user_id ON orders(user_id);

-- Drop concurrently too
DROP INDEX CONCURRENTLY IF EXISTS idx_orders_user_id_old;
```

---

## FLUTTER — Drift (SQLite)

```dart
// database.dart
@DriftDatabase(tables: [Users, Messages])
class AppDatabase extends _$AppDatabase {
  AppDatabase(QueryExecutor e) : super(e);

  @override
  int get schemaVersion => 3; // bump on every migration

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        // v1 → v2: added avatar_url
        await m.addColumn(users, users.avatarUrl);
      }
      if (from < 3) {
        // v2 → v3: added message reactions table
        await m.createTable(reactions);
      }
    },
    beforeOpen: (OpeningDetails details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      // Verify schema integrity after migration
      if (details.hadUpgrade) {
        await validateDatabaseSchema();
      }
    },
  );
}
```

---

## CI/CD INTEGRATION

```yaml
# GitHub Actions — run migrations before deploy, never after
- name: Run migrations
  run: |
    npx prisma migrate deploy
    # OR: alembic upgrade head
    # OR: supabase db push --linked
  env:
    DATABASE_URL: ${{ secrets.DATABASE_URL }}

# Always in this order:
# 1. Run migrations (expand phase)
# 2. Deploy new code (reads both old + new schema)
# 3. After stable: run cleanup migration (contract phase)
```

---

## SEED DATA

```typescript
// prisma/seed.ts — idempotent seeds (safe to run multiple times)
const { PrismaClient } = require('@prisma/client');
const db = new PrismaClient();

async function main() {
  // upsert — never insert with hard-coded IDs that might conflict
  await db.role.upsert({
    where: { name: 'admin' },
    update: {},
    create: { name: 'admin', permissions: ['*'] },
  });
  await db.role.upsert({
    where: { name: 'user' },
    update: {},
    create: { name: 'user', permissions: ['read'] },
  });
}

main().catch(console.error).finally(() => db.$disconnect());
```

---

## CHECKLIST — Before every migration

```
[ ] Migration is additive (expand) not destructive (contract)?
[ ] Large table? Used CONCURRENTLY for indexes?
[ ] Has both up + down logic?
[ ] Tested on local clone of prod data?
[ ] Backfill separated from DDL (runs as background job)?
[ ] RLS policies updated for new columns/tables? (Supabase)
[ ] migration.sql reviewed — no implicit full-table rewrite?
[ ] CI will run migrate deploy before code deploy?
[ ] Rollback plan written and tested?
```
