# SKILL: Database Patterns · v2026.10
> Load when: choosing, configuring, or querying any database.
> FIRST: detect which DB/ORM the project uses. Match it.

## DETECT FIRST
```bash
# Check package.json / pubspec.yaml for DB deps
cat pubspec.yaml | grep -E "supabase|firebase|sqflite|drift|sembast|realm|hive"
cat package.json | grep -E "prisma|drizzle|typeorm|mongoose|supabase|firebase|knex|sequelize"
ls supabase/ prisma/ drizzle/ migrations/ 2>/dev/null
cat pubspec.yaml | grep -E "supabase_flutter|firebase_core|sqflite|drift" 2>/dev/null
```

## SUPABASE (detected)
```dart
// Always specify columns — never select *
final data = await supabase
    .from('messages')
    .select('id, content, created_at, sender_id')
    .eq('room_id', roomId)
    .order('created_at', ascending: false)
    .limit(50);

// RLS — every table must have row-level security
// Upsert with onConflict
await supabase.from('user_presence').upsert({
  'user_id': userId,
  'status': 'online',
  'last_seen': DateTime.now().toIso8601String(),
}, onConflict: 'user_id');
```

## FIREBASE (detected)
```dart
// Firestore — always use snapshots() for realtime
FirebaseFirestore.instance
    .collection('messages')
    .where('roomId', isEqualTo: roomId)
    .orderBy('createdAt', descending: true)
    .limit(50)
    .snapshots()
    .map((snap) => snap.docs.map((d) => Message.fromJson(d.data())));

// Security rules must validate auth + data
// Never use security rules that allow all reads/writes
```

## PRISMA (detected — Node.js)
```typescript
// Always use select to avoid over-fetching
const messages = await db.message.findMany({
  where: { roomId, deletedAt: null },
  select: { id: true, content: true, createdAt: true },
  orderBy: { createdAt: 'desc' },
  take: 50,
});

// Transactions
await db.$transaction([
  db.message.create({ data }),
  db.room.update({ where: { id: roomId }, data: { updatedAt: new Date() } }),
]);
```

## DRIZZLE (detected — Node.js)
```typescript
const messages = await db
  .select({ id: messages.id, content: messages.content })
  .from(messages)
  .where(eq(messages.roomId, roomId))
  .limit(50);
```

## LOCAL SQLITE (detected — Flutter)
```dart
// Use drift (moor) or sqflite — never raw SQL strings
// Always encrypt with sqlcipher if storing sensitive data
@DriftDatabase(tables: [Messages, Rooms])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final file = await getApplicationDocumentsDirectory();
    return NativeDatabase(File('${file.path}/app.db'), setup: (db) async {
      await db.execute('PRAGMA cipher_compatibility = 3'); // sqlcipher
    });
  });
}
```

## DATABASE RULES (universal)
- All queries parameterized — zero string interpolation
- Pagination required for any list endpoint
- Indexes on foreign keys + frequently filtered columns
- EXPLAIN ANALYZE before optimizing queries
- Never expose DB errors to client — catch and map to user-safe messages
- Migrations version-controlled, never edited after apply
- Backup schedule defined and tested before production
