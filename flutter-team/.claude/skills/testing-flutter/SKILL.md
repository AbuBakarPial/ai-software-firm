# SKILL: Testing Flutter · v2026.10
> Load when: writing Flutter tests.

## PYRAMID
```
~5%  Integration (patrol/flutter_driver) — critical flows
~15% Widget tests — screens + key interactions
~80% Unit tests — notifiers/controllers/repos/utils
```

## UNIT (flutter_test)
```dart
void main() {
  late MessagesController controller;
  late FakeMessageRepository fakeRepo;

  setUp(() {
    fakeRepo = FakeMessageRepository();
    controller = MessagesController(fakeRepo);
  });

  test('build returns messages for room', () async {
    final messages = await controller.build('room-1');
    expect(messages, isA<List<Message>>());
  });

  test('optimistic send rolls back on error', () async {
    fakeRepo.shouldFail = true;
    final prev = controller.state;
    await expectLater(controller.sendOptimistic(Message.fake()), throwsA(isA<Exception>()));
    expect(controller.state, prev);
  });
}
```

## WIDGET TEST
```dart
testWidgets('shows shimmer while loading', (tester) async {
  final container = ProviderContainer(
    overrides: [messagesControllerProvider.overrideWith(() => FakeLoadingController())],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container,
      child: const MaterialApp(home: MessageListScreen())),
  );
  expect(find.byType(ShimmerWidget), findsOneWidget);
});

testWidgets('error state shows retry button', (tester) async {
  // setup error override...
  await tester.tap(find.text('Retry'));
  await tester.pump();
  expect(find.byType(ShimmerWidget), findsOneWidget); // loading again
});
```

## FAKE REPOSITORIES
```dart
class FakeMessageRepository implements MessageRepository {
  bool shouldFail = false;
  List<Message> messages = Message.fakeList();

  @override
  Future<List<Message>> getMessages(String roomId) async {
    if (shouldFail) throw Exception('network error');
    return messages;
  }
}
```

## GOLDEN TESTS (UI regression)
```dart
testWidgets('MessageBubble golden', (tester) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: MessageBubble(message: Message.fake())),
  ));
  await expectLater(find.byType(MessageBubble),
    matchesGoldenFile('goldens/message_bubble.png'));
});
```

## RULES
- Test behavior, not widget tree implementation
- One assertion focus per test
- Fake repos, not mocks (fakes are simpler + more realistic)
- Golden tests for every custom widget
- Home: mock Supabase · Office: real Supabase integration tests separate
