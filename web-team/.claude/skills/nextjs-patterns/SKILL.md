# SKILL: Next.js Patterns · v2026.11
> Load when: building Next.js App Router features, API routes, server actions, or optimizing performance.
> FIRST: cat node_modules/next/package.json | grep '"version"' — detect exact version before assuming API.

## DETECT FIRST
```bash
cat package.json | grep '"next"'          # version
ls app/ src/app/ 2>/dev/null              # App Router
ls pages/ src/pages/ 2>/dev/null          # Pages Router (legacy)
cat next.config.js next.config.ts 2>/dev/null | head -30
```

---

## SERVER vs CLIENT — Decision Tree

```
Default: Server Component — fetches data, renders HTML, no JS bundle cost
Add `'use client'` ONLY when you need:
  - useState / useReducer / useRef
  - useEffect / useLayoutEffect
  - Browser APIs (window, document, localStorage)
  - Event handlers (onClick, onChange) that need client state
  - Third-party client-only libs

NEVER add `'use client'` to:
  - Layout files (layout.tsx) — breaks all children
  - Loading/error boundary files (these have their own rules)
  - Components that only render static content

Push `'use client'` to leaf nodes — keep the tree server-first.
```

---

## DATA FETCHING

### Parallel — never waterfall
```typescript
// ✅ Parallel: both requests fire simultaneously
const [user, posts] = await Promise.all([
  getUser(id),
  getPosts(id),
]);

// ❌ Waterfall: posts waits for user
const user = await getUser(id);
const posts = await getPosts(id);
```

### Cache strategy — explicit on every fetch
```typescript
// ISR — revalidate every hour
const data = await fetch(url, { next: { revalidate: 3600 } });

// SSR — always fresh
const data = await fetch(url, { cache: 'no-store' });

// Static — build time only
const data = await fetch(url);  // default: cached forever

// On-demand revalidation by tag
const data = await fetch(url, { next: { tags: ['user', `user:${id}`] } });
// Revalidate: revalidateTag('user') — invalidates all tagged
```

### Direct DB access in Server Components (no API layer needed)
```typescript
// app/dashboard/page.tsx
import { db } from '@/lib/db';
import { auth } from '@/lib/auth';

export default async function DashboardPage() {
  const session = await auth();
  if (!session) redirect('/login');

  // Direct DB call — no API round-trip
  const [stats, recentActivity] = await Promise.all([
    db.query.stats.findFirst({ where: eq(stats.userId, session.user.id) }),
    db.query.activity.findMany({
      where: eq(activity.userId, session.user.id),
      orderBy: [desc(activity.createdAt)],
      limit: 10,
    }),
  ]);

  return <Dashboard stats={stats} activity={recentActivity} />;
}
```

---

## SERVER ACTIONS

```typescript
// app/actions/user.ts
'use server';

import { revalidatePath, revalidateTag } from 'next/cache';
import { redirect } from 'next/navigation';
import { z } from 'zod';
import { auth } from '@/lib/auth';
import { db } from '@/lib/db';

const updateProfileSchema = z.object({
  name: z.string().min(1).max(100).trim(),
  bio: z.string().max(500).trim().optional(),
});

export async function updateProfile(formData: FormData) {
  // 1. Auth check — ALWAYS first
  const session = await auth();
  if (!session) throw new Error('Unauthorized');

  // 2. Validate
  const parsed = updateProfileSchema.safeParse(Object.fromEntries(formData));
  if (!parsed.success) {
    return { error: parsed.error.flatten() };
  }

  // 3. Mutate
  await db.user.update({
    where: { id: session.user.id },
    data: parsed.data,
  });

  // 4. Invalidate cache
  revalidatePath('/profile');
  revalidateTag(`user:${session.user.id}`);

  return { success: true };
}
```

```typescript
// Client component using action
'use client';

import { updateProfile } from '@/app/actions/user';
import { useActionState } from 'react';

export function ProfileForm({ user }: { user: User }) {
  const [state, action, isPending] = useActionState(updateProfile, null);

  return (
    <form action={action}>
      <input name="name" defaultValue={user.name} />
      {state?.error?.fieldErrors?.name && (
        <p role="alert" className="text-red-500">{state.error.fieldErrors.name}</p>
      )}
      <button type="submit" disabled={isPending}>
        {isPending ? 'Saving...' : 'Save'}
      </button>
    </form>
  );
}
```

---

## ROUTING — App Router Patterns

```
app/
├── layout.tsx              ← root layout (never 'use client')
├── page.tsx                ← /
├── loading.tsx             ← automatic Suspense wrapper (show for every route)
├── error.tsx               ← error boundary (must be 'use client')
├── not-found.tsx           ← 404
├── (auth)/                 ← route group — no URL segment
│   ├── login/page.tsx      ← /login
│   └── signup/page.tsx     ← /signup
├── (app)/                  ← route group — separate layout for authenticated
│   ├── layout.tsx          ← auth check here
│   ├── dashboard/page.tsx
│   └── settings/page.tsx
└── api/
    └── webhooks/
        └── route.ts        ← external webhook only — use server actions for internal
```

```typescript
// Dynamic segments + generateStaticParams (SSG for known IDs)
// app/blog/[slug]/page.tsx
export async function generateStaticParams() {
  const posts = await getAllPostSlugs(); // called at build time
  return posts.map(p => ({ slug: p.slug }));
}

// generateMetadata — every dynamic page
export async function generateMetadata({ params }: { params: { slug: string } }): Promise<Metadata> {
  const post = await getPost(params.slug);
  return {
    title: `${post.title} | Blog`,
    description: post.excerpt.slice(0, 160),
    openGraph: {
      title: post.title,
      description: post.excerpt,
      images: [{ url: post.ogImage, width: 1200, height: 630 }],
    },
    alternates: { canonical: `https://example.com/blog/${params.slug}` },
  };
}
```

---

## PERFORMANCE

```typescript
// next/image — always, never raw <img>
import Image from 'next/image';

<Image
  src={user.avatar}
  alt={user.name}
  width={64}
  height={64}
  priority    // ← add on LCP image (hero/above-fold)
  className="rounded-full"
/>

// next/font — always, never CDN Google Fonts
import { Inter, JetBrains_Mono } from 'next/font/google';
const inter = Inter({ subsets: ['latin'], variable: '--font-inter' });

// Dynamic import — lazy load heavy components
const RichTextEditor = dynamic(() => import('@/components/RichTextEditor'), {
  loading: () => <div className="h-64 bg-muted animate-pulse rounded" />,
  ssr: false,  // client-only components
});

// Bundle analysis — before adding any new dependency
// ANALYZE=true next build → check chunk sizes in .next/analyze/
```

---

## STREAMING — Incremental page loading

```typescript
// app/dashboard/page.tsx — stream slow data
import { Suspense } from 'react';

export default function DashboardPage() {
  return (
    <div>
      <h1>Dashboard</h1>
      {/* Fast: renders immediately */}
      <UserHeader />
      {/* Slow: streams in when ready */}
      <Suspense fallback={<StatsSkeleton />}>
        <Stats />     {/* async Server Component */}
      </Suspense>
      <Suspense fallback={<ActivitySkeleton />}>
        <RecentActivity />
      </Suspense>
    </div>
  );
}
```

---

## API ROUTES — External Only

```typescript
// app/api/webhooks/stripe/route.ts
import { headers } from 'next/headers';
import Stripe from 'stripe';

export async function POST(req: Request) {
  const body = await req.text(); // raw body for signature verification
  const signature = headers().get('stripe-signature') ?? '';

  let event: Stripe.Event;
  try {
    event = stripe.webhooks.constructEvent(body, signature, process.env.STRIPE_WEBHOOK_SECRET!);
  } catch {
    return Response.json({ error: 'Invalid signature' }, { status: 400 });
  }

  switch (event.type) {
    case 'checkout.session.completed':
      await handleCheckout(event.data.object);
      break;
  }

  return Response.json({ received: true });
}
```

---

## COMMON PITFALLS

| Pitfall | Fix |
|---------|-----|
| `useEffect` for data fetching | Server Component or TanStack Query |
| `'use client'` on layout.tsx | Remove — breaks entire subtree |
| Not awaiting `cookies()` / `headers()` | These are now async in Next.js 15 |
| API routes for internal mutations | Use Server Actions instead |
| Raw `<img>` tag | `next/image` — always |
| Google Fonts via CDN link tag | `next/font/google` — always |
| `params` accessed without await | In Next 15: `const { id } = await params` |
| No `loading.tsx` → no streaming | Add `loading.tsx` on every route |
| Parallel routes not wrapped in Suspense | Each slot needs Suspense boundary |
| Missing `revalidateTag` after mutation | Stale data served until next build |
