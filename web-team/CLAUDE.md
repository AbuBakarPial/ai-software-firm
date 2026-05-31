# WEB TEAM DIRECTIVE · v2026.10
> Load AFTER shared/AGENT_GOD_MODE.md. Web-specific laws on top of universal laws.
> Stack: React · Next.js · TypeScript · TanStack · Node.js/Python backend · PostgreSQL/Supabase/Prisma

---

## STEP 0 — DETECT BEFORE WRITING ANY CODE (mandatory)

```bash
cat package.json | python3 -m json.tool | grep -A 5 '"dependencies"'
ls -la src/ app/ pages/ components/ 2>/dev/null | head -20
find src -type d | sort 2>/dev/null || find app -type d | sort
grep -r "useState\|useReducer\|zustand\|redux\|jotai\|valtio\|recoil" src --include="*.tsx" -l | head -5
grep -r "react-router\|next/navigation\|tanstack.*router" src --include="*.tsx" -l | head -5
ls prisma/ drizzle/ 2>/dev/null
```

Write ALL findings to MEMORY.md under `CODEBASE MAP`.

---

## WEB LAWS

| # | Law |
|---|-----|
| W1 | TypeScript strict mode — no `any`, no `as unknown as X` without comment |
| W2 | Match detected folder structure — never impose App Router if Pages Router found |
| W3 | Match detected state lib — never introduce second one |
| W4 | Server Components default (Next.js) — `"use client"` only when needed |
| W5 | No `useEffect` for derived state — compute in render |
| W6 | Fetch in Server Components — never in client components unless real-time |
| W7 | Zod for all external data validation — no raw JSON.parse |
| W8 | Error boundaries on every async boundary |
| W9 | `key` prop = stable ID, never array index |
| W10 | CSS: use existing system (Tailwind/CSS Modules/styled-components) — never mix |

---

## REACT PATTERNS

```tsx
// ✅ Server Component (Next.js App Router default)
async function UserProfile({ id }: { id: string }) {
  const user = await db.user.findUnique({ where: { id } });
  if (!user) notFound();
  return <ProfileCard user={user} />;
}

// ✅ Client Component — only when interactive
'use client';
function LikeButton({ postId }: { postId: string }) {
  const [liked, setLiked] = useState(false);
  const toggle = useOptimistic(liked, (_, next) => next); // React 19
  return <button onClick={() => toggle(!liked)}>{liked ? '❤️' : '🤍'}</button>;
}

// ✅ Data fetching with TanStack Query (if detected)
function Messages({ roomId }: { roomId: string }) {
  const { data, isPending, error } = useQuery({
    queryKey: ['messages', roomId],
    queryFn: () => fetchMessages(roomId),
    staleTime: 30_000,
  });
  if (isPending) return <MessagesSkeleton />;
  if (error) return <ErrorView error={error} />;
  return <MessageList messages={data} />;
}

// ✅ Mutation with optimistic update
const mutation = useMutation({
  mutationFn: sendMessage,
  onMutate: async (newMsg) => {
    await queryClient.cancelQueries({ queryKey: ['messages', roomId] });
    const prev = queryClient.getQueryData(['messages', roomId]);
    queryClient.setQueryData(['messages', roomId], (old) => [newMsg, ...old]);
    return { prev };
  },
  onError: (_, __, ctx) => queryClient.setQueryData(['messages', roomId], ctx.prev),
  onSettled: () => queryClient.invalidateQueries({ queryKey: ['messages', roomId] }),
});
```

---

## NEXT.JS APP ROUTER PATTERNS

```tsx
// app/layout.tsx — root layout
export default function RootLayout({ children }: { children: React.ReactNode }) {
  return <html lang="en"><body><Providers>{children}</Providers></body></html>;
}

// Metadata
export const metadata: Metadata = { title: 'App', description: '...' };

// Route handlers — app/api/[route]/route.ts
export async function POST(req: Request) {
  const body = await req.json();
  const parsed = MessageSchema.safeParse(body);
  if (!parsed.success) return Response.json({ error: parsed.error }, { status: 400 });
  const result = await db.message.create({ data: parsed.data });
  return Response.json(result, { status: 201 });
}

// Parallel routes for tabs
// app/@sidebar/page.tsx + app/@main/page.tsx → app/layout.tsx receives both

// Error boundary
'use client';
export default function Error({ error, reset }: { error: Error; reset: () => void }) {
  return <div><p>{error.message}</p><button onClick={reset}>Retry</button></div>;
}
```

---

## TANSTACK PATTERNS

```tsx
// TanStack Router (if detected)
const Route = createRoute({
  getParentRoute: () => rootRoute,
  path: '/chat/$roomId',
  loader: ({ params }) => queryClient.ensureQueryData(messagesQuery(params.roomId)),
  component: ChatPage,
});

// TanStack Form (if detected)
const form = useForm({
  defaultValues: { message: '' },
  validators: { onChange: MessageSchema },
  onSubmit: async ({ value }) => mutation.mutateAsync(value),
});
```

---

## BACKEND PATTERNS

### Node.js / Express / Fastify
```typescript
// Route with validation + error handling
app.post('/api/messages', 
  authenticate,          // middleware
  validate(MessageSchema),
  async (req, res) => {
    const msg = await messageService.create(req.user.id, req.body);
    res.status(201).json(msg);
  }
);

// Service layer — no DB in routes
class MessageService {
  async create(userId: string, data: CreateMessageDto): Promise<Message> {
    return this.db.message.create({ data: { ...data, userId } });
  }
}
```

### Python / FastAPI (if detected)
```python
@router.post("/messages", response_model=MessageOut, status_code=201)
async def create_message(
    body: MessageCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> Message:
    return await message_service.create(db, current_user.id, body)
```

---

## DATABASE PATTERNS (Prisma / Drizzle / raw SQL)

```typescript
// Prisma — always use select to avoid over-fetching
const messages = await db.message.findMany({
  where: { roomId, deletedAt: null },
  select: { id: true, content: true, createdAt: true, author: { select: { name: true } } },
  orderBy: { createdAt: 'desc' },
  take: 50,
  cursor: cursor ? { id: cursor } : undefined,
});

// Transactions for multi-step ops
await db.$transaction(async (tx) => {
  const msg = await tx.message.create({ data });
  await tx.room.update({ where: { id: roomId }, data: { lastMessageAt: new Date() } });
});
```

---

## PERFORMANCE

- `React.memo` only with profiler evidence — premature memo hurts
- `useMemo`/`useCallback` only for expensive computations or stable refs
- Images: `next/image` always · fill lazy loading · WebP/AVIF
- Bundle: `next/dynamic` for heavy client components
- `Suspense` + streaming for slow data
- Route-level code splitting (automatic in Next.js App Router)
- No `console.log` in production — use structured logger

---

## TESTING (Web)

```typescript
// Unit test — Vitest
describe('MessageService', () => {
  it('creates message with userId', async () => {
    const msg = await service.create('user-1', { content: 'hello', roomId: 'room-1' });
    expect(msg.userId).toBe('user-1');
  });
});

// Component test — React Testing Library
test('shows skeleton while loading', () => {
  render(<MessageList roomId="r1" />);
  expect(screen.getByTestId('messages-skeleton')).toBeInTheDocument();
});

// E2E — Playwright
test('user can send message', async ({ page }) => {
  await page.goto('/chat/room-1');
  await page.fill('[data-testid="message-input"]', 'hello');
  await page.click('[data-testid="send-btn"]');
  await expect(page.getByText('hello')).toBeVisible();
});
```

---

## FOLDER STRUCTURE (detect — don't impose)

**Next.js App Router (if detected):**
```
app/
├── (auth)/login/page.tsx
├── (main)/dashboard/page.tsx
├── api/messages/route.ts
components/
├── ui/          (Button, Input, Card — primitives)
├── features/    (MessageList, ChatRoom — domain)
└── layouts/
lib/
├── db.ts
├── auth.ts
└── validations/
```

**React SPA (if detected):**
```
src/
├── features/    (auth/ chat/ settings/ — each has components/ hooks/ api/)
├── components/  (shared UI)
├── hooks/
├── lib/
└── types/
```

---

## SUBAGENTS (load on demand)

| Agent | File | When to use |
|-------|------|-------------|
| Architect | `.claude/agents/architect.md` | System design, ADRs, tech stack |
| Security | `.claude/agents/security.md` | Pre-release audit, auth changes |
| Reviewer | `.claude/agents/reviewer.md` | PR review, pre-merge gate |
| SEO | `.claude/agents/seo.md` | Web Vitals, metadata, structured data |

## WEB SKILLS — load on demand

| Task | Skill |
|------|-------|
| Next.js patterns | `.claude/skills/nextjs-patterns/SKILL.md` |
| React patterns | `.claude/skills/react-patterns/SKILL.md` |
| TanStack | `.claude/skills/tanstack/SKILL.md` |
| Design system | `.claude/skills/design-system-web/SKILL.md` |
| Backend Node | `.claude/skills/backend-node/SKILL.md` |
| Backend Python | `.claude/skills/backend-python/SKILL.md` |
| TDD / Testing | `.claude/skills/tdd/SKILL.md` |
| Security audit | `.claude/skills/security-audit/SKILL.md` |
| API design | `.claude/skills/api-design/SKILL.md` |
| DevOps checklist | `.claude/skills/devops-checklist/SKILL.md` |
| Commit | `.claude/skills/commit/SKILL.md` |
| Database (any DB) | `shared/.claude/skills/database/SKILL.md` |
| Performance | `shared/.claude/skills/performance/SKILL.md` |
| Auth | `shared/.claude/skills/auth-patterns/SKILL.md` |
| GraphQL | `shared/.claude/skills/graphql/SKILL.md` |
| AI/LLM | `shared/.claude/skills/ai-integration/SKILL.md` |
| i18n | `shared/.claude/skills/i18n/SKILL.md` |
| K8s | `shared/.claude/skills/kubernetes/SKILL.md` |
| Message queues | `shared/.claude/skills/message-queues/SKILL.md` |
| Serverless/Edge | `shared/.claude/skills/serverless-edge/SKILL.md` |
| Observability | `shared/.claude/skills/observability/SKILL.md` |
| DB Migrations | `shared/.claude/skills/db-migrations/SKILL.md` |
| Resilience | `shared/.claude/skills/resilience/SKILL.md` |
| E2E Testing | `shared/.claude/skills/e2e-testing/SKILL.md` |
| Backend Go | `shared/.claude/skills/backend-go/SKILL.md` |
| Secret scanning | `shared/.claude/skills/secret-scanning/SKILL.md` |
| Worktree | `shared/.claude/skills/worktree/SKILL.md` |
