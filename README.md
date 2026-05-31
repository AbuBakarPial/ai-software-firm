# 🏗 AI Software Firm

**One person. Any project. Production-ready output.**

> Drop 96 files into any repo. Your AI coding agent instantly becomes a senior engineer with memory, laws, live docs, secret scanning, and one-command app store deploy.

Works with **Claude Code · Cursor · Windsurf · Copilot · Codex · OpenCode · Antigravity · Kiro** — any tool that reads `AGENTS.md` or `CLAUDE.md`.

---

## The problem with AI coding tools

You ask the AI to add a feature.

It ignores your folder structure. It uses a deprecated API. It touches files you didn't ask it to touch. It says "done" — tests are broken. Next session, it forgets everything and repeats the same mistake.

**This fixes that. Permanently.**

---

## What you get

```
full-setup/
├── AGENTS.md                    ← 11 laws the AI follows every session
├── shared/
│   ├── .claude/hooks/           ← 5 hooks: block dangerous cmds, auto-format,
│   │                               verify on stop, secret scan, context guard
│   └── .claude/skills/          ← 24 shared skills: auth, TDD, k8s, GraphQL,
│                                   observability, resilience, db-migrations...
├── flutter-team/
│   ├── MEMORY.md                ← AI's project memory (fills up over time)
│   ├── ERRORS.md                ← Mistakes it will never repeat
│   ├── fastlane/                ← One-command App Store + Play Store deploy
│   └── .claude/
│       ├── agents/              ← architect · security · reviewer · devops
│       └── skills/              ← flutter-patterns, state-management, MCP,
│                                   design-system, TDD, security-audit...
└── web-team/
    └── .claude/
        ├── agents/              ← architect · security · reviewer · devops · SEO
        └── skills/              ← Next.js, React, Node, Python, TanStack,
                                    design-system, TDD, security-audit...
```

**96 files. 45 skills. 5 hooks. 9 agents. Built for real production software.**

---

## The 11 laws (AGENTS.md)

Every session, every tool, no exceptions:

| # | Law |
|---|-----|
| 0 | **Session protocol** — read MEMORY.md + ERRORS.md before touching anything. Write updates at end. |
| 1 | Detect before build — scan structure, match existing, never impose |
| 2 | One question before ambiguous work. Not after. |
| 3 | Surgical — touch only what the task requires |
| 4 | Verify every task: state command + expected output before saying done |
| 5 | Pushback first — bad plan? Name the flaw, offer fix, confirm before executing |
| 6 | Zero secrets — no hardcoded keys, tokens, passwords, URLs |
| 7 | YAGNI — build only what was asked. "Useful later" = scope creep |
| 8 | Read local docs first — training data is stale |
| 9 | Self-correct — MEMORY.md and ERRORS.md update automatically, never on request |
| 10 | Worktree first — non-trivial task? `git worktree add` before any `/build` |
| 11 | MCP before package — any pub.dev import? Call dart MCP first. Never guess APIs |

---

## The memory system (why this gets smarter over time)

```
Session 1:  AI reads empty MEMORY.md. Scans your project. Writes codebase map.
Session 5:  AI knows your folder structure, your patterns, your decisions.
Session 20: AI has institutional knowledge no other tool has.
```

**MEMORY.md** — the AI's notebook. After every session it writes what it learned about YOUR specific project. The next session, it reads this first.

**ERRORS.md** — pre-seeded with Flutter and web pitfalls. If the AI makes a new mistake, it adds a rule immediately. Same mistake never happens twice.

This is the real long-term value. After 20 real sessions, your MEMORY.md is a project knowledge base worth more than the code itself.

---

## Setup: 3 commands

### Flutter project (new or existing)

```bash
# 1. Clone this repo
git clone https://github.com/AbuBakarPial/ai-software-firm.git

# 2. Copy into your project
cd your-flutter-project
cp /path/to/ai-software-firm/AGENTS.md .
cp -r /path/to/ai-software-firm/flutter-team/. .
cp -r /path/to/ai-software-firm/shared/.claude .claude/
chmod +x .claude/hooks/*.sh

# 3. Start Claude Code (or any tool) and type:
/onboard
```

Done. The AI reads your project, writes the codebase map, and says:
```
Ready. Stack: Flutter + Riverpod + GoRouter. Pattern: feature-first.
I will not repeat: storing BuildContext across async gaps.
```

### Web project (Next.js / React / Node / Python)

```bash
cd your-web-project
cp /path/to/ai-software-firm/AGENTS.md .
cp -r /path/to/ai-software-firm/web-team/. .
cp -r /path/to/ai-software-firm/shared/.claude .claude/
chmod +x .claude/hooks/*.sh
```

### Any other project

```bash
# shared/ works for any language: Go, Rails, Django, Laravel, anything
cp /path/to/ai-software-firm/AGENTS.md .
cp -r /path/to/ai-software-firm/shared/.claude .claude/
chmod +x .claude/hooks/*.sh
```

---

## One-time installs (do once on your machine)

```bash
# Secret scanning (blocks hardcoded keys in CI + pre-commit)
brew install gitleaks          # Mac
choco install gitleaks         # Windows

# Fastlane for mobile deploy (Flutter projects only)
cd your-project/fastlane && bundle install

# Dart MCP — already built into Dart SDK. Zero install.
# Verifies real pub.dev APIs before every package import.
```

---

## Workflow

```
/spec → /plan → /worktree → /build → /test → /review → /devsecops → /ship
```

| Command | What happens |
|---------|-------------|
| `/onboard` | First-time scan → writes full CODEBASE MAP to MEMORY.md |
| `/spec` | Define what to build with acceptance criteria before any code |
| `/plan` | Atomic checklist with verify commands for each step |
| `/build` | One thin slice, matches your existing style, no scope creep |
| `/test` | RED → GREEN → REFACTOR. Behavior tests, not implementation tests |
| `/review` | Correctness · security · data safety · performance · completeness |
| `/devsecops` | Full security gate: gitleaks scan, OWASP check, secrets audit |
| `/ship` | Fastlane for mobile (App Store + Play Store), CI/CD for web |
| `/debug` | Reproduce → localize → reduce → fix → guard with test |

---

## The 5 hooks (automatic — cannot be turned off)

| Hook | What it blocks / does |
|------|-----------------------|
| `block-dangerous.sh` | Blocks `rm -rf`, `DROP TABLE` without backup, force push to main |
| `auto-format.sh` | Runs `dart format` / `prettier` after every file write |
| `verify-on-stop.sh` | When AI says "done", runs tests — can't claim done without passing |
| `context-guard.sh` | Blocks reading 500+ line files that waste context budget |
| `rtk-rewrite.sh` | Blocks old Redux patterns, enforces RTK (web projects) |

---

## The 45 skills

Skills are read-on-demand. The AI loads only what the current task needs.

**Shared (works for every project):**
`security-audit` · `tdd` · `api-design` · `auth-patterns` · `system-design` · `database` · `db-migrations` · `kubernetes` · `mobile-cicd` · `observability` · `performance` · `resilience` · `e2e-testing` · `graphql` · `i18n` · `message-queues` · `ai-integration` · `serverless-edge` · `backend-go` · `token-compression` · `ui-playbook` · `worktree` · `secret-scanning` · `commit`

**Flutter team:**
`flutter-patterns` · `design-system-flutter` · `state-management` · `testing-flutter` · `tdd` · `api-design` · `security-audit` · `fastlane` · `flutter-mcp`

**Web team:**
`nextjs-patterns` · `react-patterns` · `backend-node` · `backend-python` · `tanstack` · `design-system-web` · `testing-web` · `tdd` · `security-audit` · `api-design` · `devops-checklist` · `commit`

---

## The 9 sub-agents

Specialized agents that run parallel to your main session:

**Flutter:** `@architect` · `@security` · `@reviewer` · `@devops`

**Web:** `@architect` · `@security` · `@reviewer` · `@devops` · `@seo`

```bash
# Example — ask the security agent to audit your auth code:
@security review the Supabase auth implementation in lib/features/auth/
```

---

## Dart MCP — live Flutter/Dart docs

The official `dart mcp-server` (built into Dart SDK, zero install) gives the AI:

- **pub_dev_search** — search packages with real metadata before any import
- **resolve_symbol** — look up exact API signatures, no guessing
- **add_dependency** — correct version resolution every time
- **get_widget_tree** — inspect running app's widget tree live
- **screenshot** — visual QA of running app
- **hot_reload** — trigger hot reload from the agent

Without this, agents confidently implement APIs deprecated three versions ago.

---

## Secret scanning in CI

Add to your GitHub Actions:

```yaml
- name: Secret scan
  uses: gitleaks/gitleaks-action@v2
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

Or GitLab CI — see `devops/SECRET_SCAN_CI.md`.

---

## App store deploy in one command

```bash
# Android (internal track):
bundle exec fastlane android internal

# iOS (TestFlight):
bundle exec fastlane ios beta

# Or just:
/ship
```

See `flutter-team/fastlane/Fastfile` for full lane config including signing via `match`.

---

## Compatible tools

| Tool | How to use |
|------|-----------|
| **Claude Code** | `ln -s AGENTS.md CLAUDE.md` in project root |
| **Cursor** | Add `AGENTS.md` to project root — auto-detected |
| **Windsurf** | Add `AGENTS.md` to project root — auto-detected |
| **GitHub Copilot** | Reference `AGENTS.md` in your workspace instructions |
| **OpenCode** | `.opencode/config.json` included with MCP pre-configured |
| **Codex CLI** | `--context AGENTS.md` flag on every run |
| **Antigravity** | Drop `AGENTS.md` in project root |
| **Kiro** | Add to `.kiro/steering/` as a steering doc |
| **Any other tool** | Any tool that reads a markdown context file works |

---

## What gets better with every session

```
Session 1   → AI reads empty MEMORY.md, discovers your project fresh
Session 3   → AI knows your folder structure and naming conventions
Session 7   → AI knows your state management patterns, your component style
Session 15  → AI knows your entire technical history and decision log
Session 20+ → Institutional knowledge no AI tool without this has
```

The remaining gap to perfection is always just `MEMORY.md`. No file can fill it. Real sessions do.

---

## FAQ

**Does this work for non-Flutter/web projects?**
Yes. `shared/` works for any language. Go, Python, Rails, Laravel, Django, Rust — copy `shared/.claude/` and `AGENTS.md` into any project.

**Will this break my existing code?**
No. `/onboard` only reads. It never writes to your code. It writes only to `MEMORY.md`. The hooks only activate on new changes.

**Does this cost anything?**
Zero. All files are Markdown and shell scripts. You pay only for the AI tool you already use.

**Will the AI actually follow these rules?**
Yes, because the hooks enforce the non-negotiables (formatting, secrets, verify-on-done) deterministically — no LLM can override them. The rest is prompt engineering tested across real projects.

**What if I use a different state management than Riverpod?**
Law 1 and Law 2: detect before build, match existing. The AI detects your patterns from `pubspec.yaml` and your `lib/` folder and follows them. It will not introduce Riverpod if you use Bloc.

---

## Contributing

Found a better hook? A skill that should be shared? PRs welcome.

- New skills go in `shared/.claude/skills/YOUR_SKILL/SKILL.md`
- Team-specific skills go in `flutter-team/` or `web-team/`
- Hooks go in `shared/.claude/hooks/`
- Keep `AGENTS.md` under 100 lines — research shows bloated context files reduce agent success rate

---

## License

MIT — use it, fork it, build on it.

---

*Built with Claude Code, OpenCode, Antigravity, and too much free-tier usage.*
*The MEMORY.md starts empty. After 20 sessions, it's the best thing in the repo.*
