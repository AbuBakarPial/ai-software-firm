# SKILL: TDD · Flutter/Mobile · v2026.9
> RED → GREEN → REFACTOR. Bug fix: write reproducing test first.

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
   / integr \   15% — feature flows with real DB (office only)
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
      when(() => repo.getMessages('room1'))
          .thenAnswer((_) async => Ok([]));
      await container.read(messagesControllerProvider('room1').future);

      unawaited(
        container.read(messagesControllerProvider('room1').notifier).send('Hi'),
      );

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
  });
}
```

---

## MOCKING RULES

- `mocktail` — no code gen, works with sealed classes
- Mock at repository layer — controllers test against mocked repos
- Never mock domain models — test them directly
- Integration tests: real DB, no mocks
- Fixtures: add `.fixture()` factory to every model class

```dart
extension MessageFixture on Message {
  static Message fixture({
    String? id, String? content, MessageStatus? status,
  }) => Message(
    id: id ?? 'test-id',
    content: content ?? 'Test content',
    status: status ?? MessageStatus.sent,
    createdAt: DateTime(2026, 1, 1),
    senderId: 'test-sender',
  );
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

# Integration (office only — needs real DB)
flutter test integration_test/

# Single file
flutter test test/features/chat/messages_controller_test.dart -v
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
| **Overall** | **75%** | CI gate |
