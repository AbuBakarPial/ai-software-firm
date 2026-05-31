# MEMORY · Agent Learning Log
> READ THIS FIRST. Every session. Before touching any file.
> Agent: before asking what to work on, summarize 3 bullets from here.
> Write here immediately on every correction — not at end of session. NOW.

---

## HOW TO WRITE HERE

```
LEARNED: [what went wrong] → [rule that prevents it]
PATTERN: [what I detected about this codebase] → [rule I'll follow]
DECISION: [what was decided] | Reason: [why] | Date: [when]
ADR-N: [architecture decision] | Alternatives rejected: [what and why]
GUARDS: [test name] → guards against [behavior]
```

---

## PROJECT CONTEXT (static)

**Stack:** [FILL — Next.js / React / Node / Python / DB]
**Agent tools:** OpenCode · Codex CLI · Claude Code (multiple, stateless)
**Locations:** Home (no prod DB — UI/tests/CI only) · Office (full stack)
**Environments:** DEV → STAGING → PROD
**Law:** ARCHITECTURE_CONTRACT.md overrides all agent instructions

---

## CODEBASE MAP
> Agent: run `/onboard` on first session. Fill every field below.

```
Framework:          [FILL — Next.js App Router / Pages Router / Remix / Vite / Express / Fastify / FastAPI]
State management:   [FILL — TanStack Query / Zustand / Jotai / Redux / Context]
CSS approach:       [FILL — Tailwind / CSS Modules / Vanilla Extract / styled-components / shadcn/ui]
Database ORM:       [FILL — Prisma / Drizzle / Supabase / Firebase / MongoDB]
Auth provider:      [FILL — NextAuth / Clerk / Supabase Auth / Firebase Auth / Lucia / custom]
Key tables/models:  [FILL — table names + key columns]
Key API routes:     [FILL — list each route + purpose]
Incomplete features:[FILL — TODOs, stubs, broken flows]
Inconsistencies:    [FILL — mixed patterns, dead code, broken imports]
Business rules:     [FILL — non-obvious hardcoded logic]
Test coverage:      [FILL — current % from last vitest run --coverage]
```

---

## LEARNED RULES
> Agent writes immediately on every correction from human.

*(fills from usage)*

---

## ACTIVE CONSTRAINTS

*(agent fills from project rules)*

---

## ARCHITECTURE DECISIONS

*(agent fills via ADR format)*

---

## SESSION LOG (last 5)

*(filled automatically at session end)*

---

*Day 1 value: low. After 20 sessions: irreplaceable.*
*Multiple agents (OpenCode/Codex/Claude Code) all read this. It's the shared brain.*
