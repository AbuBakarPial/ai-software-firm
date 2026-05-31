# SKILL: TDD · v2026.9
> Load when: writing any feature, fixing any bug, or asked to write tests.
> Rule: RED → GREEN → REFACTOR. No exceptions.

---

## THE PROTOCOL

```
1. Write failing test that describes behavior (RED)
2. Run it — confirm it fails for the RIGHT reason
3. Write MINIMUM code to make it pass (GREEN)
4. Refactor without breaking (REFACTOR)
5. Log test in MEMORY.md: "Guards: [behavior]"
```

Bug fix variant:
```
1. Write test that REPRODUCES the bug (RED) — commit this first
2. Fix the bug (GREEN)
3. Run full suite — zero regressions
4. Log to ERRORS.md: cause + fix + test that now guards it
```

---

## TEST PYRAMID

```
      /\
     /e2e\      5%  — critical journeys: sign-up, send message, make call
    /------\
   / integr \   15% — feature flows with real Supabase (office only)
  /----------\
 /    unit    \ 80% — controllers, repositories, pure functions, models
/--------------\
```

---

## UNIT TEST TEMPLATE

```dart
// test/features/chat/messages_controller_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MockMessagesRepo extends Mock implements MessagesRepository {}
class FakeMessage extends Fake implements Message {}

void main() {
  setUpAll(() => registerFallbackValue(FakeMessage()));

  group('MessagesController', () {
    late MockMessagesRepo repo;
    late ProviderContainer container;

    setUp(() {
      repo = MockMessagesRepo();
      container = ProviderContainer(overrides: [
        messagesRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);
    });

    test('loads messages for room', () async {
      when(() => repo.getMessages('room1')).thenAnswer(
        (_) async => Ok([Message.fixture(content: 'Hello')]),
      );

      await container.read(messagesControllerProvider('room1').future);

      final state = container.read(messagesControllerProvider('room1'));
      expect(state.value?.length, 1);
      expect(state.value?.first.content, 'Hello');
    });

    test('surfaces network error without crashing', () async {
      when(() => repo.getMessages(any()))
          .thenAnswer((_) async => Err(const NetworkError()));

      await container.read(messagesControllerProvider('room1').future)
          .catchError((_) => <Message>[]);

      final state = container.read(messagesControllerProvider('room1'));
      expect(state.hasError, isTrue);
    });

    test('optimistic send appears before server confirms', () async {
      when(() => repo.sendMessage(any(), any()))
          .thenAnswer((_) async {
            await Future.delayed(const Duration(milliseconds: 100));
            return Ok(Message.fixture(content: 'Hi'));
          });

      // Load initial state
      when(() => repo.getMessages('room1'))
          .thenAnswer((_) async => Ok([]));
      await container.read(messagesControllerProvider('room1').future);

      // Trigger send — don't await
      unawaited(
        container.read(messagesControllerProvider('room1').notifier).send('Hi'),
      );

      // Immediately check — optimistic message should appear
      await Future.delayed(Duration.zero);
      final state = container.read(messagesControllerProvider('room1'));
      expect(state.value?.any((m) => m.content == 'Hi'), isTrue);
    });
  });
}
```

---

## WIDGET TEST TEMPLATE

```dart
// test/shared/widgets/chat_bubble_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChatBubble', () {
    Widget buildBubble({required bool isSent}) => MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: ChatBubble(
              message: 'Test message',
              isSent: isSent,
              timestamp: DateTime(2026, 1, 1, 14, 30),
            ),
          ),
        );

    testWidgets('sent bubble aligns right', (tester) async {
      await tester.pumpWidget(buildBubble(isSent: true));
      final align = tester.widget<Align>(
        find.ancestor(of: find.text('Test message'), matching: find.byType(Align)).first,
      );
      expect(align.alignment, Alignment.centerRight);
    });

    testWidgets('shows formatted timestamp', (tester) async {
      await tester.pumpWidget(buildBubble(isSent: false));
      expect(find.text('14:30'), findsOneWidget);
    });

    testWidgets('meets minimum tap target', (tester) async {
      await tester.pumpWidget(buildBubble(isSent: true));
      // Text selectable — verify no layout overflow
      expect(tester.takeException(), isNull);
    });
  });
}
```

---

## INTEGRATION TEST TEMPLATE (office only)

```dart
// integration_test/chat_flow_test.dart
// Tag: integration — skip in home/CI unit test runs

@Tags(['integration'])
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Chat flow', () {
    late SupabaseClient supabase;

    setUpAll(() async {
      await Supabase.initialize(
        url: const String.fromEnvironment('SUPABASE_URL'),
        anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
      );
      supabase = Supabase.instance.client;
    });

    testWidgets('send and receive message', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Sign in
      await tester.tap(find.byKey(const Key('email_field')));
      await tester.enterText(find.byKey(const Key('email_field')), 'test@office.lan');
      await tester.tap(find.byKey(const Key('login_button')));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Navigate to chat
      await tester.tap(find.byKey(const Key('chat_room_1')));
      await tester.pumpAndSettle();

      // Send message
      await tester.enterText(find.byKey(const Key('message_input')), 'Hello from test');
      await tester.tap(find.byKey(const Key('send_button')));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Verify appears in UI
      expect(find.text('Hello from test'), findsOneWidget);
    });
  });
}
```

---

## TEST COMMANDS

```bash
# Unit only (home + office, fast)
flutter test --exclude-tags integration --reporter expanded

# With coverage
flutter test --exclude-tags integration --coverage
genhtml coverage/lcov.info -o coverage/html

# Integration (office only — needs Supabase)
flutter test integration_test/ --dart-define=SUPABASE_URL=http://office-ip:8000

# Single file
flutter test test/features/chat/messages_controller_test.dart -v

# Rust
cargo test -- --test-threads=4
cargo clippy -- -D warnings

# Watch (requires entr)
find lib test -name "*.dart" | entr flutter test --exclude-tags integration
```

---

## COVERAGE TARGETS

| Layer | Min | Why |
|-------|-----|-----|
| Domain models | 95% | Pure functions — trivial |
| Controllers | 90% | Core business logic |
| Repositories | 80% | Data layer boundary |
| FFI bridge | 70% | Safety-critical |
| Widgets | 60% | Behavior, not rendering |
| **Overall** | **75%** | CI gate — pipeline fails below this |

---

## MOCKING RULES

- `mocktail` — no code gen, works with sealed classes
- Mock at repository layer — controllers test against mocked repos
- Never mock domain models — test them directly
- Integration tests: real Supabase, no mocks
- Fixtures: add `.fixture()` factory to every model class

```dart
// In every model
extension MessageFixture on Message {
  static Message fixture({
    String? id,
    String? content,
    MessageStatus? status,
  }) => Message(
    id: id ?? 'test-id',
    content: content ?? 'Test content',
    status: status ?? MessageStatus.sent,
    createdAt: DateTime(2026, 1, 1),
    senderId: 'test-sender',
  );
}
```

