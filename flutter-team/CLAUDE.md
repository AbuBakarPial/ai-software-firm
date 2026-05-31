# FLUTTER TEAM DIRECTIVE · v2026.10
> Load this AFTER shared/AGENT_GOD_MODE.md. Flutter-specific laws on top of universal laws.
> Stack: Flutter · Dart · Riverpod · GoRouter · Supabase · Rust FFI (optional)

---

## STEP 0 — DETECT BEFORE WRITING ANY CODE (mandatory)

```bash
find lib -type d | sort
grep -r "StateNotifierProvider\|NotifierProvider\|@riverpod" lib --include="*.dart" -l | head -5
grep -r "BlocProvider\|Cubit" lib --include="*.dart" -l | head -5
grep -r "GoRouter\|AutoRouter\|go_router" lib --include="*.dart" -l | head -5
grep -r "supabase\|Supabase" lib --include="*.dart" -l | head -5
grep -r "ffi\|NativeFunction" lib --include="*.dart" -l | head -5
cat pubspec.yaml | grep -A 50 "dependencies:"
npx skills add flutter/skills dart-lang/skills  # official Flutter agent skills (test-gen, deps, static-analysis)
```

Write ALL findings to MEMORY.md under `CODEBASE MAP` before first line of code.

---

## FLUTTER LAWS (supplement universal laws)

| # | Law |
|---|-----|
| F1 | Match detected folder structure — feature-first / layer-first / hybrid — never mix |
| F2 | Match detected state management — never introduce second library |
| F3 | `ref.watch` in build only · `ref.read` in callbacks only · `ref.listen` for side effects |
| F4 | Every widget: const constructor if no dynamic data |
| F5 | Never put business logic in widgets — controllers/notifiers only |
| F6 | BuildContext never stored across async gaps — use mounted check |
| F7 | Dart null-safety: no `!` unless proven non-null by control flow |
| F8 | GoRouter: declarative routes only — no Navigator.push except nested |
| F9 | Supabase realtime: always unsubscribe in onDispose |
| F10 | Rust FFI: zero raw pointers in Dart — wrap in safe Dart API always |

---

## RIVERPOD PATTERNS (Riverpod 2.x · @riverpod annotation)

```dart
// Controller
@riverpod
class MessagesController extends _$MessagesController {
  @override
  Future<List<Message>> build(String roomId) async {
    ref.onDispose(() => _sub?.unsubscribe());
    return _repo.getMessages(roomId);
  }
  Future<void> send(String content) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.sendMessage(roomId, content));
  }
}

// Optimistic UI
Future<void> sendOptimistic(Message msg) async {
  final prev = state;
  state = AsyncData([msg, ...prev.value ?? []]);  // instant UI
  try { await _repo.sendMessage(msg); }
  catch (e) { state = prev; rethrow; }            // rollback on fail
}

// UI
class MsgList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(messagesControllerProvider(roomId)).when(
      data: (msgs) => _ListView(msgs),
      loading: () => const _Shimmer(),
      error: (e, _) => _ErrorView(e, onRetry: () =>
          ref.invalidate(messagesControllerProvider(roomId))),
    );
  }
}
```

---

## GOROUTER PATTERNS

```dart
final router = GoRouter(
  initialLocation: '/splash',
  redirect: (context, state) {
    final auth = ref.read(authProvider);
    if (!auth.isLoggedIn && !state.location.startsWith('/auth')) return '/auth/login';
    return null;
  },
  routes: [
    GoRoute(path: '/home', builder: (c, s) => const HomeScreen()),
    ShellRoute(builder: (c, s, child) => ScaffoldWithNav(child: child), routes: [...]),
  ],
);
```

---

## SUPABASE REALTIME

```dart
// Always unsubscribe — no memory leaks
@riverpod
class ChatRoomController extends _$ChatRoomController {
  RealtimeChannel? _channel;

  @override
  Stream<List<Message>> build(String roomId) {
    ref.onDispose(() => _channel?.unsubscribe());
    _channel = supabase.channel('room:$roomId')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'messages',
        filter: PostgresChangeFilter(type: FilterType.eq, column: 'room_id', value: roomId),
        callback: (payload) => _handleInsert(payload),
      )
      .subscribe();
    return _repo.messagesStream(roomId);
  }
}
```

---

## NULL SAFETY RULES

```dart
// ✅
final user = ref.watch(authProvider).valueOrNull;
if (user == null) return const SizedBox.shrink();

// ❌ never
final user = ref.watch(authProvider).value!;

// ✅ mounted check after async
Future<void> onTap() async {
  final result = await someAsync();
  if (!mounted) return;   // ← always
  setState(() => _data = result);
}
```

---

## PERFORMANCE RULES

- `const` widgets everywhere possible
- `RepaintBoundary` around heavy animated widgets
- `ListView.builder` never `ListView` with children for long lists
- Image: `cacheWidth`/`cacheHeight` always set for network images
- `compute()` for parsing > 1000 items
- No `setState` in `initState` — use `addPostFrameCallback`
- Profile with `flutter run --profile` before claiming performance is fine

---

## TESTING (Flutter)

```dart
// Widget test
testWidgets('shows shimmer while loading', (tester) async {
  final container = ProviderContainer(
    overrides: [messagesControllerProvider.overrideWith(() => FakeController())],
  );
  await tester.pumpWidget(UncontrolledProviderScope(container: container,
    child: const MaterialApp(home: MessageListScreen())));
  expect(find.byType(Shimmer), findsOneWidget);
});

// Unit test
test('optimistic send rolls back on error', () async {
  final ctrl = MessagesController();
  final prev = ctrl.state;
  await expectLater(ctrl.sendOptimistic(badMsg), throwsA(isA<Exception>()));
  expect(ctrl.state, prev);
});
```

---

## FOLDER STRUCTURE (detect — don't impose)

**Feature-first (if detected):**
```
lib/
├── features/
│   ├── auth/       (data/ domain/ presentation/)
│   ├── chat/
│   └── calls/
├── shared/         (widgets/ utils/ theme/)
└── core/           (router/ di/ constants/)
```

**Layer-first (if detected):**
```
lib/
├── data/           (repositories/ datasources/ models/)
├── domain/         (entities/ usecases/ interfaces/)
├── presentation/   (screens/ widgets/ controllers/)
└── core/
```

**Hybrid (if detected):** Ask human which convention for new code → write to MEMORY.md.

---

## SUBAGENTS (load on demand)

| Agent | File | When to use |
|-------|------|-------------|
| Architect | `.claude/agents/architect.md` | System design, ADRs, tech stack |
| Security | `.claude/agents/security.md` | Pre-release audit, auth changes |
| Reviewer | `.claude/agents/reviewer.md` | PR review, pre-merge gate |
| DevOps | `.claude/agents/devops.md` | CI/CD, pipeline, release automation |

## SKILLS — load on demand

| Task | Skill |
|------|-------|
| Flutter patterns | `.claude/skills/flutter-patterns/SKILL.md` |
| Design system | `.claude/skills/design-system-flutter/SKILL.md` |
| State management | `.claude/skills/state-management/SKILL.md` |
| Testing | `.claude/skills/testing-flutter/SKILL.md` |
| TDD | `.claude/skills/tdd/SKILL.md` |
| API/Supabase | `.claude/skills/api-design/SKILL.md` |
| Security audit | `.claude/skills/security-audit/SKILL.md` |
| Database (any DB) | `shared/.claude/skills/database/SKILL.md` |
| Performance | `shared/.claude/skills/performance/SKILL.md` |
| Auth | `shared/.claude/skills/auth-patterns/SKILL.md` |
| Commit | `shared/.claude/skills/commit/SKILL.md` |
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
