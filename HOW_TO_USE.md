# HOW TO USE · ELITE SOFTWARE FIRM · v2026.11
> One person. Any agentic tool. World-class output.
> Read this once. Then use AGENTS.md every session.

---

## WHAT YOU HAVE (96 files)

```
final-firm/
├── AGENTS.md                    ← LEAN master router (<100 lines)
├── HOW_TO_USE.md                ← this file
├── .opencode/config.json        ← OpenCode tool config
├── shared/
│   ├── AGENT_GOD_MODE.md        ← full engineering law system
│   ├── UNIVERSAL_GOD_MODE.md    ← general LLM behavior
│   ├── SECURITY_HARDENING.md    ← security reference
│   ├── RUNBOOK.md               ← ops runbook
│   └── .claude/
│       ├── settings.json        ← hooks config (Claude Code)
│       ├── hooks/               ← auto-format · block-dangerous · verify-stop · rtk
│       └── skills/              ← 22 shared skills
│           ├── security-audit/  ├── tdd/           ├── api-design/
│           ├── performance/     ├── commit/        ├── database/
│           ├── system-design/   ├── auth-patterns/ ├── kubernetes/
│           ├── mobile-cicd/     ├── i18n/          ├── graphql/
│           ├── message-queues/  ├── ai-integration/├── serverless-edge/
│           ├── token-compression/ ├── ui-playbook/  ├── observability/
│           ├── db-migrations/    ├── resilience/    ├── e2e-testing/
│           └── backend-go/
├── flutter-team/
│   ├── AGENTS.md                ← Flutter directive
│   ├── MEMORY.md                ← agent learning log
│   ├── ERRORS.md                ← pre-seeded Flutter pitfalls
│   └── .claude/
│       ├── agents/              ← architect · security · reviewer · devops
│       └── skills/              ← flutter-patterns · design-system · state-mgmt · testing
│                                  · tdd · api-design · security-audit (7 skills)
├── web-team/
│   ├── AGENTS.md                ← Web directive
│   ├── MEMORY.md                ← agent learning log
│   ├── ERRORS.md                ← pre-seeded web pitfalls
│   └── .claude/
│       ├── agents/              ← architect · security · reviewer · devops · seo
│       └── skills/              ← 12 web skills
└── devops/
    ├── DEVOPS.md                ← CI/CD directive
    ├── DEVOPS_SKILL.md          ← pipeline templates
    └── DOCKER_COMPOSE.yml       ← production docker compose
```

---

## FRESH PROJECT SETUP (5 minutes)

### Flutter project
```bash
flutter create my-app && cd my-app

# Copy firm files
cp /path/to/final-firm/AGENTS.md .
cp /path/to/final-firm/shared/AGENT_GOD_MODE.md .
cp -r /path/to/final-firm/flutter-team/. .
cp -r /path/to/final-firm/shared/.claude/hooks .claude/hooks/
cp /path/to/final-firm/shared/.claude/settings.json .claude/
cp -r /path/to/final-firm/shared/.claude/skills .claude/skills/

# Claude Code symlink
ln -s AGENTS.md CLAUDE.md

# Make hooks executable
chmod +x .claude/hooks/*.sh

# First prompt to agent:
# /onboard
```

### Web project (Next.js)
```bash
npx create-next-app@latest my-app --typescript --tailwind && cd my-app

# Copy firm files
cp /path/to/final-firm/AGENTS.md .
cp /path/to/final-firm/shared/AGENT_GOD_MODE.md .
cp -r /path/to/final-firm/web-team/. .
cp -r /path/to/final-firm/shared/.claude/hooks .claude/hooks/
cp /path/to/final-firm/shared/.claude/settings.json .claude/
cp -r /path/to/final-firm/shared/.claude/skills .claude/skills/

# Claude Code
ln -s AGENTS.md CLAUDE.md
chmod +x .claude/hooks/*.sh

# TanStack auto-skills (if using TanStack)
npx @tanstack/intent install

# First prompt:
# /onboard
```

---

## EXISTING PROJECT SETUP

```bash
# 1. Copy into project root (won't overwrite your existing files)
cp /path/to/final-firm/AGENTS.md .
cp /path/to/final-firm/shared/AGENT_GOD_MODE.md .
cp -r /path/to/final-firm/[flutter-team OR web-team]/MEMORY.md .
cp -r /path/to/final-firm/[flutter-team OR web-team]/ERRORS.md .
cp -r /path/to/final-firm/[flutter-team OR web-team]/.claude .

# 2. First agent prompt (audit before touching anything):
"Read AGENTS.md and flutter-team/AGENTS.md (or web-team/AGENTS.md).
Run /onboard — scan entire codebase, write CODEBASE MAP to MEMORY.md.
Then run /devsecops — audit against security rules and report all findings.
Do NOT write any code. Audit only. List everything that needs fixing."

# 3. Review output → prioritize with agent
# 4. Normal work begins
```

---

## DAILY SESSION WORKFLOW

### Any tool (OpenCode / Codex CLI / Antigravity / OpenClaude)
**Paste this at start of every session:**
```
Read AGENTS.md, then MEMORY.md, then ERRORS.md.
State 3 bullets of what you know about this project.
State 3 mistakes you will not repeat today.
Then ask me what to work on.
```

**Paste this at end of every session:**
```
Session ending. Update MEMORY.md with everything learned.
Update ERRORS.md with any failed commands or wrong assumptions.
Write a 3-bullet summary for the next session's agent.
```

### Claude Code (hooks auto-run, AGENTS.md auto-loaded)
- CLAUDE.md symlinked → auto-read on start
- Hooks run on every file write and session stop
- Invoke agents: "Use the security agent to audit the auth feature"

---

## INVOKING SPECIALIST AGENTS

```
"Use the architect agent — should I use Supabase or Firebase for this project?"
"Use the security agent to audit everything before release"
"Use the reviewer agent to review the changes in lib/features/chat/"
"Use the devops agent to set up the GitLab CI pipeline"
"Use the seo agent to audit the homepage" (web only)
```

---

## HOME vs OFFICE (context fragmentation prevention)

**Before leaving any workspace:**
```
"Write a complete status update to MEMORY.md:
- What was completed
- What is in progress (exact file/line)
- What is broken or blocked
- What to do next session
Commit MEMORY.md and ERRORS.md to git."
```

**Arriving at new workspace:**
```
git pull
"Read MEMORY.md. Summarize path forward in 3 bullets. Then ask what to work on."
```

---

## SCORE

| Dimension | Score | Notes |
|-----------|-------|-------|
| Universal (any LLM tool) | 10/10 | Works: OpenCode·Codex·Antigravity·OpenClaude·Claude Code·Cursor·Windsurf·Copilot |
| Flutter team | 9.5/10 | Hybrid·Riverpod 2.x·DB-agnostic·Rust FFI optional·adaptive structure |
| Web team | 9.5/10 | Next.js·React·TanStack·TypeScript·DB-agnostic·full auth patterns |
| DevOps/Infra | 9.5/10 | GitLab+GitHub CI·Docker·K8s·Nginx·monitoring·mobile release |
| Security | 9.5/10 | OWASP mobile+web·cert pinning·RLS·CSP·secrets scanning |
| Design/UI | 9/10 | 7-step Oczkowski process·tokens·a11y·skeleton loaders·anti-patterns |
| AI features | 9/10 | LLM APIs·RAG·vector DBs·streaming·guardrails |
| Self-learning | 8/10 → 10/10 | MEMORY+ERRORS compound every session |
| Token efficiency | 9.5/10 | Lean AGENTS.md·progressive disclosure·compression skill |
| **Overall day 0** | **9.5/10** | **Self-improving from first session** |

**Gap to 10/10:** MEMORY.md fills from real usage. After 20 sessions: irreplaceable.

---

## THE ONE HABIT

End every session:
```
Update MEMORY.md and ERRORS.md before we close.
```
Everything else is automatic.
