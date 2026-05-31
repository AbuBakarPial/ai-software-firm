# SKILL: API Design · Flutter/Mobile · v2026.9
> Load when: designing Supabase queries, Postgres RPC functions, REST API contracts, or Edge Functions.

---

## SUPABASE (PostgREST) — Dart

```dart
// Always specify exact columns — never select *
final messages = await supabase
    .from('messages')
    .select('id, content, sender_id, created_at, message_type')
    .eq('room_id', roomId)
    .order('created_at')
    .range(offset, offset + pageSize - 1)  // cursor pagination
    .withConverter((data) => data.map(Message.fromJson).toList());

// Upsert — always specify onConflict
await supabase.from('presence').upsert({
  'user_id': userId,
  'room_id': roomId,
  'last_seen': DateTime.now().toIso8601String(),
}, onConflict: 'user_id, room_id');

// Filter with count
final res = await supabase
    .from('messages')
    .select('*', const FetchOptions(count: CountOption.exact))
    .eq('room_id', roomId);
final count = res.count;  // total matching rows
```

### Pagination

```dart
// Cursor-based (recommended for realtime data)
Future<Page<Message>> getMessages(String roomId,
    {String? cursor, int limit = 50}) async {
  var query = supabase
      .from('messages')
      .select('id, content, sender_id, created_at')
      .eq('room_id', roomId)
      .order('created_at', ascending: false)
      .limit(limit);
  if (cursor != null) query = query.lt('created_at', cursor);
  final data = await query;
  return Page(
    items: data.map(Message.fromJson).toList(),
    cursor: data.isNotEmpty ? data.last['created_at'] as String : null,
  );
}

// Offset-based (for static lists)
final data = await supabase
    .from('messages')
    .select('id, content, created_at')
    .eq('room_id', roomId)
    .order('created_at', ascending: false)
    .range(offset, offset + pageSize - 1);
```

---

## POSTGRES RPC FUNCTIONS

```sql
-- For complex queries needing transaction or performance
CREATE OR REPLACE FUNCTION get_conversation_summary(
  p_user_id UUID,
  p_limit INTEGER DEFAULT 20
)
RETURNS TABLE (
  room_id UUID,
  last_message TEXT,
  last_message_at TIMESTAMPTZ,
  unread_count BIGINT,
  peer_id UUID,
  peer_name TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Explicit auth check (never trust caller)
  IF auth.uid() != p_user_id THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  RETURN QUERY
  SELECT r.id, m.content, m.created_at,
    COUNT(m2.id) FILTER (WHERE m2.read_at IS NULL) as unread_count,
    u.id, u.display_name
  FROM rooms r
  JOIN messages m ON m.id = r.last_message_id
  JOIN room_members rm ON rm.room_id = r.id AND rm.user_id != p_user_id
  JOIN users u ON u.id = rm.user_id
  LEFT JOIN messages m2 ON m2.room_id = r.id AND m2.read_at IS NULL
  WHERE r.id IN (SELECT room_id FROM room_members WHERE user_id = p_user_id)
  ORDER BY m.created_at DESC
  LIMIT p_limit;
END;
$$;
```

```dart
// Call RPC from Flutter
final result = await supabase.rpc('get_conversation_summary', params: {
  'p_user_id': supabase.auth.currentUser!.id,
  'p_limit': 20,
});
```

---

## EDGE FUNCTIONS (Deno/TypeScript)

```typescript
// supabase/functions/send-notification/index.ts
import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok')

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) return new Response('Unauthorized', { status: 401 })

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } }
    )
    const { data: { user }, error } = await supabase.auth.getUser()
    if (error || !user) return new Response('Unauthorized', { status: 401 })

    // Validate input
    const body = await req.json()
    if (!body.recipient_id || typeof body.recipient_id !== 'string') {
      return Response.json({ error: 'recipient_id required' }, { status: 400 })
    }

    return Response.json({ success: true })
  } catch (err) {
    console.error('Edge function error:', err)
    return Response.json({ error: 'Internal server error' }, { status: 500 })
  }
})
```

---

## API RULES

- **No `select *` in production** — always specify column list
- **Pagination required** for any list endpoint — max page size 100
- **Cursor-based pagination** over offset for realtime data (messages)
- **All inputs validated** server-side regardless of client validation
- **Error messages** never expose DB structure, file paths, or stack traces
- **Idempotency keys** for any operation that sends notifications or charges
- **Timestamps** always UTC ISO 8601 (`timestamptz`, not `timestamp`)
- **IDs** always UUID, never sequential integers (enumeration attack)
- **Rate limiting** on all public endpoints — use Supabase RLS or Edge Function middleware
