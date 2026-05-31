# FLUTTER TEAM DIRECTIVE · v2026.11
> Load AFTER shared/AGENTS.md. Extends it.
> Stack: Flutter · Dart · Riverpod 2.x · Hybrid structure · DB project-wise · Rust FFI optional

## DETECT FIRST (mandatory every Flutter session)
```bash
find lib -type d | sort
cat pubspec.yaml | grep -A 30 "dependencies:"
grep -rl "@riverpod\|StateNotifierProvider\|BlocProvider\|GetxController" lib | head -5
grep -rl "GoRouter\|AutoRouter\|go_router" lib | head -3
grep -rl "supabase\|firebase\|drift\|isar\|hive\|sqflite" lib | head -3
grep -rl "ffi\|dart:ffi\|NativeFunction" lib | head -3
```
Write ALL findings to MEMORY.md under CODEBASE MAP before first line of code.

## FLUTTER LAWS
| # | Law |
|---|-----|
| F1 | Match detected folder structure — feature-first/layer-first/hybrid — never mix, never reorganize |
| F2 | Match detected state management — never introduce second library |
| F3 | `ref.watch` in build · `ref.read` in callbacks · `ref.listen` for side effects |
| F4 | const constructor on every widget that has no dynamic data |
| F5 | Business logic in controllers/notifiers ONLY — never in widgets |
| F6 | `BuildContext` never stored across async gaps — always `mounted` check |
| F7 | No `!` on nullable unless proven by control flow — document why |
| F8 | GoRouter: declarative only — no `Navigator.push` except in nested navigators |
| F9 | Supabase realtime: `unsubscribe()` in `onDispose` — mandatory |
| F10 | Rust FFI: all calls on separate isolate via `compute()` — main thread never blocked |

## STATE MANAGEMENT PATTERNS (Riverpod 2.x — if detected)
```dart
@riverpod
class FeatureController extends _$FeatureController {
  @override
  Future<List<T>> build(String id) async {
    ref.onDispose(() => _cleanup());
    return _repo.fetch(id);
  }
  // Optimistic UI: paint immediately, rollback on error
  Future<void> optimisticAction(T item) async {
    final prev = state;
    state = AsyncData([item, ...prev.value ?? []]);
    try { await _repo.save(item); }
    catch (e) { state = prev; rethrow; }
  }
}
```

## SKILLS (load on demand)
| Task | Skill |
|------|-------|
| Flutter patterns | `.claude/skills/flutter-patterns/SKILL.md` |
| Design system | `.claude/skills/design-system-flutter/SKILL.md` |
| State mgmt | `.claude/skills/state-management/SKILL.md` |
| Flutter patterns | `.claude/skills/flutter-patterns/SKILL.md` |
| Design system | `.claude/skills/design-system-flutter/SKILL.md` |
| State mgmt | `.claude/skills/state-management/SKILL.md` |
| Testing | `.claude/skills/testing-flutter/SKILL.md` |
| TDD | `.claude/skills/tdd/SKILL.md` |
| API design | `.claude/skills/api-design/SKILL.md` |
| Security audit | `.claude/skills/security-audit/SKILL.md` |
| Database (any) | `shared/.claude/skills/database/SKILL.md` |
| Auth | `shared/.claude/skills/auth-patterns/SKILL.md` |
| Performance | `shared/.claude/skills/performance/SKILL.md` |
| Mobile CI/CD | `shared/.claude/skills/mobile-cicd/SKILL.md` |
| AI features | `shared/.claude/skills/ai-integration/SKILL.md` |
| i18n | `shared/.claude/skills/i18n/SKILL.md` |
| Observability | `shared/.claude/skills/observability/SKILL.md` |
| DB Migrations | `shared/.claude/skills/db-migrations/SKILL.md` |
| Resilience | `shared/.claude/skills/resilience/SKILL.md` |
| E2E Testing | `shared/.claude/skills/e2e-testing/SKILL.md` |
| Backend Go | `shared/.claude/skills/backend-go/SKILL.md` |
| Flutter MCP | `.claude/skills/flutter-mcp/SKILL.md` |
| Fastlane | `.claude/skills/fastlane/SKILL.md` |
| Secret scanning | `shared/.claude/skills/secret-scanning/SKILL.md` |
| Worktree | `shared/.claude/skills/worktree/SKILL.md` |

## AGENTS (invoke for specialist tasks)
| Agent | When |
|-------|------|
| `.claude/agents/architect.md` | Tech decisions, ADRs, library choices |
| `.claude/agents/security.md` | Pre-release audit, auth changes, crypto |
| `.claude/agents/reviewer.md` | PR review, before merge |
| `.claude/agents/devops.md` | CI/CD, pipeline, release automation |

## PRODUCTION GATE (/ship)
- [ ] `flutter analyze` → 0 errors, 0 warnings
- [ ] `dart format --check .` → all formatted
- [ ] `flutter test` → all pass, coverage ≥75%
- [ ] No `print()` in lib/ outside debug guards
- [ ] No `http://` in production code
- [ ] No secrets in source or assets (gitleaks 0)
- [ ] Release APK signed with keystore
- [ ] All DB tables: RLS enabled (if Supabase)
- [ ] Error tracking DSN configured
- [ ] `flutter build apk --release` → success
