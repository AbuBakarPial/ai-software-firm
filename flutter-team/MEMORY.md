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

**Stack:** Flutter · Dart · Riverpod 2.x · GoRouter · [FILL — DB project-wise] · Rust FFI (optional)
**Agent tools:** OpenCode · Codex CLI · Claude Code (multiple, stateless)
**Locations:** Home (no prod DB — UI/tests/CI only) · Office (full stack, physical devices)
**Environments:** DEV → STAGING → PROD
**Law:** shared/AGENT_GOD_MODE.md overrides all agent instructions

---

## CODEBASE MAP
> Agent: run `/onboard` on first session. Fill every field below.

```
Folder pattern:      [FILL — feature-first / layer-first / hybrid]
State management:    [FILL — Riverpod 2.x / Bloc / GetX / Provider / other]
Navigation:          [FILL — GoRouter / AutoRouter / Navigator 2.0]
Key providers:       [FILL — list each provider + what it manages]
Key screens:         [FILL — list each screen + route path]
Tables:              [FILL — table names + key columns]
RPC functions:       [FILL — list each Postgres function]
FFI functions:       [FILL — list each Rust/Dart FFI function]
Incomplete features: [FILL — TODOs, stubs, broken flows]
Inconsistencies:     [FILL — mixed patterns, dead code, broken imports]
Business rules:      [FILL — non-obvious hardcoded logic]
Test coverage:       [FILL — current % from last flutter test --coverage]
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
