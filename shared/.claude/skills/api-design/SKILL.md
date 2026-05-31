# SKILL: API Design · v2026.8
> Load when: designing Supabase Edge Functions, Postgres RPC functions, or any API contracts.

---

## SUPABASE API PATTERNS

### REST (PostgREST)

```dart
// Always specify exact columns — never select *
final messages = await supabase
    .from('messages')
    .select('id, content, sender_id, created_at, message_type')
    .eq('room_id', roomId)
    .order('created_at')
    .range(offset, offset + pageSize - 1)  // pagination
    .withConverter((data) => data.map(Message.fromJson).toList());

// Upsert pattern
await supabase.from('presence').upsert({
  'user_id': userId,
  'room_id': roomId,
  'last_seen': DateTime.now().toIso8601String(),
}, onConflict: 'user_id, room_id');
```

### Postgres RPC Functions

```sql
-- For complex queries that need transaction or performance
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
SECURITY DEFINER  -- runs as owner, RLS applied via explicit checks
SET search_path = public
AS $$
BEGIN
  -- Explicit auth check (never trust caller)
  IF auth.uid() != p_user_id THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  RETURN QUERY
  SELECT 
    r.id,
    m.content,
    m.created_at,
    COUNT(m2.id) FILTER (WHERE m2.read_at IS NULL) as unread_count,
    u.id,
    u.display_name
  FROM rooms r
  JOIN messages m ON m.id = r.last_message_id
  JOIN room_members rm ON rm.room_id = r.id AND rm.user_id != p_user_id
  JOIN users u ON u.id = rm.user_id
  LEFT JOIN messages m2 ON m2.room_id = r.id AND m2.read_at IS NULL
  WHERE r.id IN (
    SELECT room_id FROM room_members WHERE user_id = p_user_id
  )
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

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',  // tighten in prod
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Verify auth
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
      return new Response(
        JSON.stringify({ error: 'recipient_id required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Business logic here...

    return new Response(
      JSON.stringify({ success: true }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (err) {
    // Never expose internal errors to client
    console.error('Edge function error:', err)
    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
```

---

## API CONTRACT DOCUMENTATION FORMAT

Every API endpoint/function must be documented:

```markdown
### send_message

**Type:** Supabase RPC / Edge Function / PostgREST  
**Auth required:** Yes (JWT)  
**Rate limit:** 60 req/min per user

**Input:**
| Field | Type | Required | Validation |
|-------|------|----------|------------|
| room_id | UUID | ✓ | Must be room where caller is member |
| content | TEXT | ✓ | 1–4096 chars, no null bytes |
| message_type | ENUM | ✗ | 'text','image','voice' (default: 'text') |

**Output (200):**
```json
{ "id": "uuid", "created_at": "2026-01-01T12:00:00Z" }
```

**Errors:**
| Code | Reason |
|------|--------|
| 400 | Invalid input |
| 401 | Not authenticated |
| 403 | Not member of room |
| 429 | Rate limit exceeded |
| 500 | Internal error (no details exposed) |

**Side effects:**
- Triggers realtime broadcast on `room:{room_id}` channel
- Updates `rooms.last_message_id`
- Creates notification for recipient (async via Edge Function)
```

---

## API RULES

- **No* in production** — always specify column list
- **Pagination required** for any list endpoint — max page size 100
- **Cursor-based pagination** over offset for realtime data (messages)
- **All inputs validated** server-side regardless of client validation
- **Error messages** never expose DB structure, file paths, or stack traces
- **Idempotency keys** for any operation that sends notifications or charges
- **Timestamps** always UTC ISO 8601 (`timestamptz`, not `timestamp`)
- **IDs** always UUID, never sequential integers (enumeration attack)
