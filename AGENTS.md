# ELITE SOFTWARE FIRM · MASTER DIRECTIVE · v2026.11
# Token budget: STRICT (<100 lines) · Universal: OpenCode·Codex·Antigravity·OpenClaude·Cursor·Windsurf·Kiro·Copilot
# Claude Code: ln -s AGENTS.md CLAUDE.md

## LAW 0 — SESSION PROTOCOL (non-negotiable)

**START** (before touching anything):
1. Read `MEMORY.md` → state 3 bullets: what you know about this project
2. Read `ERRORS.md` → state 3 pitfalls you will not repeat
3. Detect stack: `find . -maxdepth 2 -name "pubspec.yaml" -o -name "package.json" -o -name "go.mod" | head -5`
4. Say: "Ready. Stack: [X]. Pattern: [Y]. I will not repeat: [Z]."

**END** (unprompted, always, before closing):
1. Update `MEMORY.md`: decisions, patterns confirmed, rules learned this session
2. Update `ERRORS.md`: every failed command or wrong assumption
3. Write: "Session done. [N] rules added."

**ON ANY CORRECTION** (immediate — never batch):
`LEARNED: [what went wrong] → [rule that prevents recurrence]` → write to MEMORY.md NOW.

## CORE LAWS
| # | Law |
|---|-----|
| 1 | Detect before build — scan structure, match existing, never impose |
| 2 | One question before ambiguous work. Not after. |
| 3 | Surgical — touch only what task requires. Notice other issues? Mention, don't touch. |
| 4 | Verify every task: state command + expected output before saying done |
| 5 | Pushback first — bad plan? Name flaw, offer fix, confirm before executing |
| 6 | Zero secrets — no hardcoded keys, tokens, passwords, URLs |
| 7 | YAGNI — build only what was asked. "Useful later" = scope creep |
| 8 | Read local docs first — training data is stale (`node_modules/next/dist/docs/`, pubspec) |
| 9 | Self-correct — MEMORY.md and ERRORS.md update automatically, never on request |
| 10 | Worktree first — non-trivial task? `git worktree add` before any /build. Load worktree/SKILL.md |
| 11 | MCP before package — any pub.dev import you didn't write? Call dart_docs MCP first. Never guess APIs |

## WORKFLOW
```
/spec → /plan → /worktree → /build → /test → /review → /devsecops → /ship
```
Non-trivial task: always `/spec` first. Wait for approval. Never skip.

## COMMANDS
`/onboard`    first-time scan → write full CODEBASE MAP to MEMORY.md
`/spec`       define objective + acceptance criteria before any code
`/plan`       atomic checklist: `[ ] step → verify: [command]`
`/build`      one thin slice, match existing style, no scope creep
`/test`       RED→GREEN→REFACTOR, behavior not implementation
`/review`     correctness · security · data safety · perf · completeness
`/debug`      reproduce → localize → reduce → fix → guard with test
`/devsecops`  full security gate before any release
`/ship`       production readiness checklist
`/fix`        correction received → update MEMORY.md now
`/worktree`   git worktree add for current task → load worktree/SKILL.md
`/compress`   context >50% → compact without losing state
`/status`     summarize MEMORY.md + current task state

## TEAM FILES (load after this)
| Project | Load |
|---------|------|
| Flutter | `flutter-team/AGENTS.md` |
| Web (React/Next/Node) | `web-team/AGENTS.md` |
| DevOps/Infra | `devops/DEVOPS.md` |
| Store delivery (Flutter) | `flutter-team/.claude/skills/fastlane/SKILL.md` |
| Secret scanning | `shared/.claude/skills/secret-scanning/SKILL.md` |
| Flutter MCP | `flutter-team/.claude/skills/flutter-mcp/SKILL.md` |
| Full-stack | All three |

## RESPONSE FORMAT
```
Changed: [files + lines]
Why:     [maps to task]
Verify:  [command] → [expected output]
Memory:  [what I'm adding to MEMORY.md]
```

## NEVER
- Start coding before reading MEMORY.md
- Say "done" without running verification command
- Repeat any error logged in ERRORS.md
- Mix patterns or state management libraries
- Hardcode environment values
- Assume structure without detecting it first
- Implement a pub.dev package without calling dart_docs MCP first
- Push to any branch without running: `gitleaks detect --redact --staged`
- Ship mobile without: `bundle exec fastlane [android internal | ios beta]`
