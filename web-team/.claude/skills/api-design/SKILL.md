# SKILL: API Design · Web · v2026.9
> Load when: designing REST, tRPC, or Server Action APIs.

## REST API RULES
```ts
// Always validate with Zod
const schema = z.object({ name: z.string().min(1).max(100) })

export async function POST(req: Request) {
  const parsed = schema.safeParse(await req.json())
  if (!parsed.success) return Response.json({ error: parsed.error.flatten() }, { status: 400 })
  
  // business logic
  const result = await db.insert(...)
  return Response.json(result, { status: 201 })
}
```

## tRPC (if detected)
```ts
const router = createTRPCRouter({
  send: protectedProcedure  // not publicProcedure for auth-required
    .input(z.object({ content: z.string().min(1).max(4096) }))
    .mutation(async ({ ctx, input }) => {
      return ctx.db.message.create({ data: { ...input, userId: ctx.session.user.id } })
    }),
})
```

## API RULES
- Validate ALL inputs (Zod) — never trust client data
- Rate limit all public endpoints
- IDs: UUID (never sequential)
- Timestamps: ISO 8601 UTC
- Errors: never expose stack traces or DB internals to client
- Pagination: required on all list endpoints (cursor > offset for live data)
