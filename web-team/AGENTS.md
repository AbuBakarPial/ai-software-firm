# WEB TEAM DIRECTIVE · v2026.11
> Load AFTER shared/AGENTS.md. Extends it.
> Stack: Next.js/React/Node · TypeScript · TanStack · Tailwind · DB project-wise

## DETECT FIRST (mandatory every web session)
```bash
cat package.json | grep -E '"next|"react|"vite|"remix|"astro|"hono|"express|"fastify'
cat package.json | grep -E '"@tanstack|"zustand|"jotai|"redux|"recoil'
cat package.json | grep -E '"prisma|"drizzle|"supabase|"firebase|"mongoose|"kysely'
cat package.json | grep -E '"@auth|"next-auth|"clerk|"lucia|"better-auth'
ls src/ app/ pages/ 2>/dev/null | head -10
cat tsconfig.json | grep -E '"paths|"baseUrl|"strict'
```
Write ALL findings to MEMORY.md under CODEBASE MAP.

## TANSTACK SETUP
```bash
# Auto-wire skills from node_modules (run once per project)
npx @tanstack/intent install
```

## WEB LAWS
| # | Law |
|---|-----|
| W1 | Match detected router/framework — never assume Next.js if not detected |
| W2 | Read `node_modules/[framework]/dist/docs/` before any framework-specific code |
| W3 | TypeScript strict: true — no `any`, use `unknown` + type guards |
| W4 | Zod for ALL external data (API responses, form input, env vars) |
| W5 | Server Components default (Next.js) — `use client` only when required |
| W6 | Rate limiting on ALL public API endpoints |
| W7 | CSP headers configured — no `unsafe-inline` without justification |
| W8 | No tokens in localStorage — httpOnly cookies or server-side session |
| W9 | `next/image`, `next/font` always — never raw `<img>` or CDN fonts |
| W10 | Every page: `generateMetadata()` — never ship without title/description/og |

## SKILLS (load on demand)
| Task | Skill |
|------|-------|
| Next.js patterns | `.claude/skills/nextjs-patterns/SKILL.md` |
| React patterns | `.claude/skills/react-patterns/SKILL.md` |
| TanStack | `.claude/skills/tanstack/SKILL.md` |
| Design system | `.claude/skills/design-system-web/SKILL.md` |
| Testing/TDD | `.claude/skills/tdd/SKILL.md` |
| Security audit | `.claude/skills/security-audit/SKILL.md` |
| API design | `.claude/skills/api-design/SKILL.md` |
| Auth | `shared/.claude/skills/auth-patterns/SKILL.md` |
| Database | `shared/.claude/skills/database/SKILL.md` |
| GraphQL | `shared/.claude/skills/graphql/SKILL.md` |
| Performance | `shared/.claude/skills/performance/SKILL.md` |
| AI features | `shared/.claude/skills/ai-integration/SKILL.md` |
| i18n | `shared/.claude/skills/i18n/SKILL.md` |
| K8s deploy | `shared/.claude/skills/kubernetes/SKILL.md` |
| Message queues | `shared/.claude/skills/message-queues/SKILL.md` |
| Serverless/Edge | `shared/.claude/skills/serverless-edge/SKILL.md` |
| Observability | `shared/.claude/skills/observability/SKILL.md` |
| DB Migrations | `shared/.claude/skills/db-migrations/SKILL.md` |
| Resilience | `shared/.claude/skills/resilience/SKILL.md` |
| E2E Testing | `shared/.claude/skills/e2e-testing/SKILL.md` |
| Backend Go | `shared/.claude/skills/backend-go/SKILL.md` |
| Secret scanning | `shared/.claude/skills/secret-scanning/SKILL.md` |
| Worktree | `shared/.claude/skills/worktree/SKILL.md` |

## AGENTS (invoke for specialist tasks)
| Agent | When |
|-------|------|
| `.claude/agents/architect.md` | System design, ADRs, library selection |
| `.claude/agents/security.md` | OWASP audit, CSP, headers, pre-release |
| `.claude/agents/reviewer.md` | PR review, a11y, performance, SEO |
| `.claude/agents/devops.md` | CI/CD, Vercel/Docker, monitoring |
| `.claude/agents/seo.md` | Core Web Vitals, metadata, structured data |

## PRODUCTION GATE (/ship)
- [ ] `tsc --noEmit` → 0 errors
- [ ] `eslint . --max-warnings 0` → clean
- [ ] `vitest run --coverage` → all pass, ≥80% coverage
- [ ] `playwright test` → critical journeys green
- [ ] `next build` → 0 errors
- [ ] Lighthouse: Perf ≥90, A11y ≥95, SEO ≥95
- [ ] No `console.log` in production code
- [ ] All env vars in `.env.example` (values redacted)
- [ ] gitleaks → 0 secrets
- [ ] CSP + security headers configured
- [ ] Rate limiting on all API routes
- [ ] Error tracking configured
