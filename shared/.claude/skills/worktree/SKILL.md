---
name: worktree
description: >
  Use for every non-trivial task. Mandatory before /build starts.
  Each feature or fix lives in an isolated git worktree — never implement in main context.
---

# Git Worktree Discipline

## Why

Context from one feature bleeds into another. Worktrees give each task a clean file
system view and a clean branch. Main context stays uncontaminated.

## Start every /build with this

```bash
# Create isolated worktree for the task
git worktree add ../worktrees/feature-name -b feature/feature-name

# Open agent in that worktree (Claude Code)
claude --worktree ../worktrees/feature-name

# OpenCode / Codex / Antigravity: cd into the worktree and start session there
cd ../worktrees/feature-name
```

## Lifecycle

```bash
# List active worktrees
git worktree list

# Done — merge and clean up
git checkout main
git merge feature/feature-name --no-ff
git worktree remove ../worktrees/feature-name
git branch -d feature/feature-name
```

## When NOT to use

- Single-file hotfixes (< 5 min, 1 file) — branch is enough
- /debug sessions on existing branch

## Rule in AGENTS.md

Non-trivial task = worktree. Ambiguous? Use worktree. Cost is 10 seconds.
Skipping it to save time is false economy — context bleed costs hours.
