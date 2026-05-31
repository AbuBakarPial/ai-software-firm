# ERRORS · Agent Failure Log
> READ THIS before every session. Never repeat a logged failure.
> Agent: write here immediately after any failed command or wrong output.

---

## HOW TO WRITE HERE

```
## ERROR-[N]
Date:    [YYYY-MM-DD]
Tool:    [OpenCode / Codex / Claude Code / other]
Action:  [what was attempted]
Error:   [exact error message]
Cause:   [why it happened]
Fix:     [what resolved it]
Guard:   [rule added to MEMORY.md to prevent recurrence]
```

---

## KNOWN ENVIRONMENT QUIRKS
> Pre-seeded. Agent reads these before touching the stack.

### Next.js
- `use client` on Server Component layout = broken layout — keep layout as Server Component, use `use client` only on leaf components
- Dynamic `generateMetadata` not called on client navigations — use `generateMetadata` export, not `useEffect`
- Route handler `Request` object consumed once — clone if reading body and headers separately

### TypeScript
- `as` type assertions suppress real errors — use Zod `.parse()` or type guards instead
- `any` in generic positions defeats type safety — use `unknown` + type narrowing

### TanStack Query
- `staleTime: 0` (default) = refetch on every mount — set to at least 30s for stable data
- Cache key mismatch = stale data shown — queryKey must be unique per entity+params

### Prisma / Drizzle
- `select *` returns all columns including sensitive ones — always `.select()` explicitly
- N+1 queries in serial resolvers — use `include` or `batch` loader

### Deployment
- Environment variable not set in Vercel = silent 500 at runtime — always check `NEXT_PUBLIC_*` and server vars separately
- `next build` fails after dependency update — clear `.next` cache and rebuild
- Bundle includes dev dependencies — check `next.config.js` transpilePackages

---

## ERROR LOG

*(agent writes here — grows from real usage)*
