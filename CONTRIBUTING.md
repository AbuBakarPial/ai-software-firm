# CONTRIBUTING · Elite Software Firm

This framework is designed to be extended. Here's how to add new skills, teams, or tools.

---

## ADD A NEW SKILL

Skills live in `shared/.claude/skills/<name>/` or `<team>/.claude/skills/<name>/`.

### Structure
```
skills/<name>/
├── SKILL.md          # Required. Trigger condition + detection + code examples
└── templates/        # Optional. Scaffold files for `/build`
```

### SKILL.md template
```markdown
# SKILL: <Name> · v2026.11
> Load when: <trigger condition — e.g., "Flutter state management work">

## DETECT FIRST
```bash
<auto-detection commands to identify if this skill applies>
```

## <Core patterns — code examples, anti-patterns, checklists>

## REFERENCES
- <link to official docs in local node_modules if available>
```

### Guidelines
- **250+ lines minimum** — real code, not stubs. Include: detect command, code examples, anti-patterns table, verification checklist.
- **Detect first** — every skill must tell the agent how to auto-detect whether it applies.
- **No theory dumps** — every paragraph must answer "what do I write right now?"
- **Match project conventions** — reference existing code in the skill's team directory.
- **Update both AGENTS.md and CLAUDE.md** to mention the new skill in the load-table.

---

## ADD A NEW TEAM (e.g., `mobile-team/`, `ml-team/`)

```
<team>/
├── AGENTS.md         # Team-specific laws + skill table
├── CLAUDE.md         # Same content, symlinked
├── MEMORY.md         # CODEBASE MAP template
├── ERRORS.md         # Pre-seeded team pitfalls
└── .claude/
    └── skills/       # Team-specific skills
```

### AGENTS.md template (lean, sub-100 lines)
```markdown
# <TEAM> TEAM · v2026.11
[LAW <T1> ... <T10>]
- Work within <framework>, don't fight it
- <team-specific law 2>
- ...

## SKILLS (load on demand)
| Trigger | Skill |
|---------|-------|
| <pattern> | `<team>/skills/<name>` |
| <pattern> | `<team>/skills/<name>` |

## STATE MANAGEMENT (pick one, stick to it)
<decision tree for the team's domain>
```

### Guidelines
- **Import root laws** — team files complement `AGENTS.md`, don't repeat core laws.
- **Decision tree** — include a state management / framework choice tree (like Flutter's Riverpod/Bloc/Provider section).
- **Symlink** — `ln -s AGENTS.md CLAUDE.md` for Claude Code compatibility.

---

## ADD A NEW AGENT TOOL (e.g., Cursor, Windsurf, Copilot)

### OpenCode (already configured)
- `.opencode/config.json` or `opencode.json[c]`

### Claude Code (already configured)
- `ln -s AGENTS.md CLAUDE.md` at project root

### Cursor
- Place rules in `.cursor/rules/` as `.mdc` files
- Root AGENTS.md referenced by Cursor via GitHub markdown

### Windsurf
- Place rules in `.windsurfrules`

### Copilot
- Place instructions in `.github/copilot-instructions.md`
- Or use `.github/copilot/` directory

### Adding a new tool
1. Create tool-specific config at `<tool-root>/` or `shared/<tool>/`
2. Update root AGENTS.md "Multi-tool parity" section
3. Update `HOW_TO_USE.md` setup steps

---

## MODIFY CORE FILES

| File | Purpose | Change frequency |
|------|---------|-----------------|
| `AGENTS.md` | Root entry point, laws, team references | Rare (laws stable) |
| `shared/AGENT_GOD_MODE.md` | Universal engineering directives | Rare |
| `HOW_TO_USE.md` | Setup guide for new users | Per-release |
| `<team>/AGENTS.md` | Team-specific laws | Per-new-pattern |
| `<team>/MEMORY.md` | Project CODEBASE MAP | Every session (auto) |
| `<team>/ERRORS.md` | Project pitfalls log | Every session (auto) |
| `CONTRIBUTING.md` | This file | Per-structural-change |

---

## QUALITY STANDARDS

### Review checklist (before merging)
- [ ] Every skill ≥ 250 lines of substantive content
- [ ] Every skill has `## DETECT FIRST` with runnable command
- [ ] No stubs — each section has real code examples
- [ ] Cross-references work (team files reference shared skills correctly)
- [ ] Token budget respected — sub-100-line root AGENTS.md
- [ ] `HOW_TO_USE.md` file count updated
- [ ] `.gitignore` covers all `node_modules/` dirs
- [ ] No project-specific data in shared/ templates
- [ ] `find-in-files` check for broken refs: `grep -r "removed\|stale\|old/path" shared/`
- [ ] Claude Code review: load full framework, scan skills table, verify no stale refs

### Definition of done
- `/spec` → `/plan` → `/build` → `/test` → `/review` → `/devsecops` → `/ship`
- All acceptance criteria met
- MEMORY.md + ERRORS.md auto-updated with session learnings
