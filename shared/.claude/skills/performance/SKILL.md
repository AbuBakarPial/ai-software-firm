# SKILL: Performance · v2026.11
> Load when: performance investigation, optimization, profiling, or bundle analysis.

## MEASURE FIRST — never optimize without data
```bash
# Flutter
flutter run --profile
flutter pub global activate devtools && dart devtools

# Web — Lighthouse
npx lighthouse https://your-url --output json --preset=desktop
npx lighthouse https://your-url --output json --preset=experimental  # INP, LCP sub-parts

# Web — profiling
# Chrome DevTools → Performance tab → record interaction
# React DevTools → Profiler → record → look for >16ms renders

# Node.js
node --prof server.js && node --prof-process isolate-*.log > profile.txt
clinic doctor -- node server.js          # holistic diagnosis
clinic flame -- node server.js           # flamegraph

# Python
python -m cProfile -o profile.cprof my_script.py
# py-spy: py-spy record -o profile.svg --pid PID --duration30

# Database
EXPLAIN (ANALYZE, BUFFERS) SELECT ...;
```

## CORE WEB VITALS — deep dive

### LCP (Largest Contentful Paint) — target < 2.5s
```bash
# What contributes: hero image, headline text, hero video poster
# Measure: PerformanceObserver + LCP API
```
```typescript
// Fixes:
// 1. Preload hero image
<link rel="preload" as="image" href="/hero.webp" fetchpriority="high" />
// 2. Optimize images — WebP/AVIF, responsive srcset, CDN
// 3. Server-side render hero content (no client waterfall)
// 4. Minify CSS — eliminate render-blocking resources
// 5. Use CSS content-visibility: auto for below-fold sections
```

### INP (Interaction to Next Paint) — target < 100ms (replaces FID 2024+)
```typescript
// Causes: long tasks > 50ms, heavy event handlers, forced layout
// Fixes:
// 1. Decompose long tasks with setTimeout/scheduler.yield()
function processItems(items: Item[]) {
  let i = 0;
  function chunk() {
    const end = Math.min(i + 50, items.length);
    for (; i < end; i++) processItem(items[i]);
    if (i < items.length) setTimeout(chunk, 0);
  }
  chunk();
}
// 2. Avoid forced layout — batch DOM reads before writes
// 3. Use passive event listeners for scroll/touch
// 4. Debounce resize/scroll handlers
// 5. content-visibility: auto for off-screen sections
```

### CLS (Cumulative Layout Shift) — target < 0.1
```css
/* Fixes: */
img, video, iframe { aspect-ratio: attr(width) / attr(height); }
/* Always set width/height on images: <img width="400" height="300" /> */
/* Ads: reserve space with min-height */
/* Fonts: font-display: swap + preload critical fonts */
/* Dynamic content: skeleton UI with fixed dimensions */
```

## FLUTTER PERFORMANCE

### Frame budget — 16ms per frame (60fps), 8ms (120fps)
```dart
// Measure: flutter run --profile, then DevTools → Frame Rendering tab
// Look for: jank (>16ms frames), rebuild count, widget repaint rate

// ✅ Const constructors everywhere
const MyWidget();           // zero rebuild cost, canonical instance
const EdgeInsets.all(16);

// ✅ RepaintBoundary for heavy subtrees
RepaintBoundary(child: AnimatedWidget())

// ✅ ListView.builder — never ListView(children: [...])
ListView.builder(itemCount: items.length, itemBuilder: (ctx, i) => ItemTile(items[i]))

// ✅ Image caching at display size
CachedNetworkImage(imageUrl: url, memCacheWidth: 200, memCacheHeight: 200)

// ✅ Heavy work off main thread
final result = await compute(parseJson, rawJson);

// ✅ Use AnimatedList / SliverAnimatedList for insert/remove animations
// ✅ Keys! Use ValueKey / ObjectKey on list items for correct diffing

// ❌ Killers:
setState in initState          → use addPostFrameCallback
Timer.periodic no dispose      → cancel in dispose() / ref.onDispose
Building widget tree in build  → extract to const fields
Opacity widget                 → use AnimatedOpacity or ColoredBox with alpha
```

### Flutter — widget rebuild debugging
```
// Add to build():
if (kDebugMode) print('Rebuild: ${runtimeType} ${hashCode}');

// DevTools → Rebuild Counts tab
// Shows exact count per widget type — hunt the highest
```

## WEB PERFORMANCE — React/Next.js

### React rendering optimization
```tsx
// Profile first: React DevTools → Profiler → record → look for >16ms renders
// Memoize only with profiler evidence:
const expensiveValue = useMemo(() => computeExpensive(data), [data]);
const stableCallback = useCallback(() => doThing(id), [id]);

// Server Components first — zero client JS by default
// Move state to server: server actions, search params
// Dynamic import for heavy client components
const HeavyChart = dynamic(() => import('./HeavyChart'), { ssr: false, loading: () => <Skeleton /> });

// Bundle analysis:
// npx @next/bundle-analyzer
// npx vite-bundle-visualizer
// Webpack: npx webpack-bundle-analyzer stats.json
```

### Image optimization
```tsx
// Next.js Image — always
import Image from 'next/image';
<Image src={url} alt={alt} width={400} height={300} loading="lazy" priority={isHero} />

// Static images: import, let Next optimize at build time
import hero from '../public/hero.webp';
<Image src={hero} alt="Hero" priority />

// Manual: responsive srcset + WebP/AVIF via picture element
<picture>
  <source srcSet="/img.avif" type="image/avif" />
  <source srcSet="/img.webp" type="image/webp" />
  <img src="/img.jpg" alt="" width="800" height="600" loading="lazy" />
</picture>
```

### Bundle splitting
```tsx
// Route-based: Next.js App Router — automatic per-route
// Component-based: dynamic() for modal, chart, editor, etc.
// Library splitting: dynamic(() => import('moment'))  // or import('date-fns') for tree-shakeable
// Webpack: splitChunks.cacheGroups for shared vendor code
```

### Caching strategy
| Layer | Strategy | TTL |
|-------|----------|-----|
| Static assets | CDN + immutable Cache-Control | 1y |
| API responses | CDN + stale-while-revalidate | 1min |
| SSR pages | CDN + s-maxage | 10s |
| ISR pages | Next.js revalidate | varies |
| DB queries | Redis (upstash/vercel-kv) | 30s–5min |
| React Query | staleTime + gcTime | per query |

## DATABASE PERFORMANCE

### Query optimization
```sql
-- Always EXPLAIN ANALYZE before optimizing
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM messages WHERE room_id = $1 AND deleted_at IS NULL ORDER BY created_at DESC LIMIT 50;

-- Index every foreign key + frequently filtered column
CREATE INDEX CONCURRENTLY idx_messages_room_created ON messages(room_id, created_at DESC);
CREATE INDEX CONCURRENTLY idx_messages_author ON messages(author_id);

-- Cursor-based pagination — never OFFSET for large tables
-- Bad:  SELECT * FROM messages LIMIT 50 OFFSET 10000  (scans 10050 rows)
-- Good: SELECT * FROM messages WHERE id < $cursor ORDER BY id DESC LIMIT 50

-- Covering index for common queries
CREATE INDEX CONCURRENTLY idx_messages_list ON messages(room_id, created_at DESC) INCLUDE (content, author_id);

-- Avoid SELECT *
SELECT id, content, created_at, author_id FROM messages WHERE room_id = $1;
```

### Connection pooling
```typescript
// Prisma: PgBouncer-compatible connection string
DATABASE_URL="postgresql://user:pass@host:6543/db?pgbouncer=true&connection_limit=10"
// Drizzle/raw: pool size = CPU cores * 2 + 1 (rule of thumb)
new Pool({ max: 10, idleTimeoutMillis: 30000 });
```

### N+1 detection
```typescript
// Prisma: enable query logging
new PrismaClient({ log: ['query', 'warn', 'error'] });
// Look for repeated identical queries in logs
// Fix: use include / select with nested relations, or batch findMany
```

## NETWORK PERFORMANCE
- HTTP/2 or HTTP/3 — multiplexing, server push (h2, h3)
- CDN for static assets + API edge caching (Cloudflare, Fastly, Vercel Edge)
- Brotli compression (level 5–6) — better than gzip
- Preconnect to origins: `<link rel="preconnect" href="https://api.example.com" />`
- Preload critical resources: `<link rel="preload" href="/font.woff2" as="font" crossorigin />`
- Font-display: swap — prevent invisible text during load
- Resource hints: prefetch next page, preconnect to third-party

## MONITORING
```bash
# Real User Monitoring (RUM)
# web-vitals library → send to analytics (GA4, Plausible, PostHog)
npm install web-vitals

# Synthetic monitoring (Lighthouse CI)
npx lhci autorun

# APM (choose one per platform)
# Web: Sentry, DataDog RUM, New Relic Browser
# Flutter: Sentry, Firebase Performance
# Backend: OpenTelemetry → Prometheus + Grafana or Datadog
```

## TARGETS (Google/Meta baseline — 2026)
| Metric | Good | Needs improvement | Poor |
|--------|------|-------------------|------|
| LCP | < 2.5s | 2.5–4.0s | > 4.0s |
| INP | < 100ms | 100–200ms | > 200ms |
| CLS | < 0.1 | 0.1–0.25 | > 0.25 |
| TTFB | < 800ms | 800–1800ms | > 1800ms |
| Flutter cold start | < 2s | 2–4s | > 4s |
| Flutter 60fps | < 16ms | 16–32ms | > 32ms |
| API p95 | < 200ms | 200–500ms | > 500ms |
| API p99 | < 500ms | 500–2000ms | > 2000ms |
| Lighthouse score | > 90 | 70–90 | < 70 |
| Bundle size (JS) | < 200KB | 200–500KB | > 500KB |

## WORKFLOW
```
1. Measure → establish baseline (Lighthouse, DevTools, profiler)
2. Identify worst offender (highest time, largest file, most jank)
3. Optimize one thing → remeasure
4. Repeat until targets met
5. Add performance regression test (CI → Lighthouse CI, threshold)
```
