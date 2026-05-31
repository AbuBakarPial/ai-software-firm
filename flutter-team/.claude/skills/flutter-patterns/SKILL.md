# SKILL: Flutter Patterns · v2026.9
> Load when: working on any Flutter feature.
> FIRST: detect existing patterns. Match them. Never impose.

---

## STEP 0 — DETECT BEFORE BUILDING (mandatory)

```bash
# Run these before writing any Flutter code
find lib -type d | sort
grep -r "StateNotifierProvider\|NotifierProvider\|riverpod" lib --include="*.dart" -l | head -5
grep -r "BlocProvider\|Cubit" lib --include="*.dart" -l | head -5
grep -r "GetX\|GetxController" lib --include="*.dart" -l | head -5
grep -r "GoRouter\|AutoRouter\|go_router" lib --include="*.dart" -l | head -5
```

Write findings to MEMORY.md under CODEBASE MAP before proceeding.

---

## STATE MANAGEMENT

### Riverpod (if detected)

```dart
// ✅ Modern Riverpod 2.x — prefer over StateNotifierProvider
@riverpod
class MessagesController extends _$MessagesController {
  @override
  Future<List<Message>> build(String roomId) async {
    // autoDispose built-in with @riverpod
    ref.onDispose(() => _channel?.unsubscribe());
    return _repo.getMessages(roomId);
  }

  Future<void> send(String content) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _repo.sendMessage(roomId, content),
    );
  }
}

// UI — watch, never read in build
class MessageList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = ref.watch(messagesControllerProvider(roomId));
    return messages.when(
      data: (msgs) => _MessageListView(msgs),
      loading: () => const _LoadingShimmer(),
      error: (e, st) => _ErrorView(error: e, onRetry: () => ref.invalidate(messagesControllerProvider(roomId))),
    );
  }
}
```

**Riverpod rules:**
- `@riverpod` annotation preferred over manual provider declaration
- `ref.watch` in build · `ref.read` in callbacks only · `ref.listen` for side effects
- `ref.invalidate()` to force refresh · `ref.keepAlive()` for providers that must persist
- Family providers for parameterized data: `messagesControllerProvider(roomId)`
- Never nest providers inside providers — use `ref.watch` at top level

### Bloc/Cubit (if detected)

```dart
class MessagesCubit extends Cubit<MessagesState> {
  MessagesCubit(this._repo) : super(const MessagesInitial());

  Future<void> load(String roomId) async {
    emit(const MessagesLoading());
    final result = await _repo.getMessages(roomId);
    result.fold(
      (error) => emit(MessagesError(error.message)),
      (messages) => emit(MessagesLoaded(messages)),
    );
  }
}

// UI
BlocBuilder<MessagesCubit, MessagesState>(
  builder: (context, state) => switch (state) {
    MessagesLoaded(:final messages) => _MessageListView(messages),
    MessagesLoading() => const _LoadingShimmer(),
    MessagesError(:final message) => _ErrorView(message),
    _ => const SizedBox.shrink(),
  },
)
```

---

## NAVIGATION

### GoRouter (if detected)

```dart
@riverpod
GoRouter router(RouterRef ref) {
  final auth = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: GoRouterRefreshStream(auth.stream),
    redirect: (context, state) {
      final loggedIn = auth.valueOrNull != null;
      final onAuth = state.matchedLocation.startsWith('/auth');
      if (!loggedIn && !onAuth) return '/auth/login';
      if (loggedIn && onAuth) return '/home';
      return null;
    },
    routes: $appRoutes, // use go_router_builder code gen
  );
}

// Route definitions with type-safe params (go_router_builder)
@TypedGoRoute<ChatRoute>(path: '/chat/:userId')
class ChatRoute extends GoRouteData {
  const ChatRoute({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      ChatScreen(userId: userId);
}
```

**GoRouter rules:**
- Auth guard in `redirect` only — never in widget `initState`
- `context.go()` for replace · `context.push()` for stack · `context.pop()` for back
- Never use `context.go()` in `build()` — use `addPostFrameCallback`
- Deep links: register all routes in `AndroidManifest.xml` + `Info.plist`
- Route constants in generated code — never raw strings

---

## ERROR HANDLING

```dart
// Sealed error hierarchy — project-wide
sealed class AppError {
  const AppError();
  String get userMessage; // always safe to show user
}

final class NetworkError extends AppError {
  const NetworkError([this.detail = '']);
  final String detail;
  @override String get userMessage => 'Connection failed. Check your network.';
}

final class AuthError extends AppError {
  const AuthError(this.code);
  final String code;
  @override String get userMessage => 'Session expired. Please sign in again.';
}

final class DatabaseError extends AppError {
  const DatabaseError(this.detail);
  final String detail;
  @override String get userMessage => 'Something went wrong. Please try again.';
}

// Repository: catch at boundary, never let raw exceptions escape
Future<Result<List<Message>, AppError>> getMessages(String roomId) async {
  try {
    final data = await supabase
        .from('messages')
        .select('id, content, sender_id, created_at, message_type')
        .eq('room_id', roomId)
        .order('created_at');
    return Ok(data.map(Message.fromJson).toList());
  } on PostgrestException catch (e) {
    _log.error('DB error in getMessages', error: e);
    return Err(DatabaseError(e.code ?? 'unknown'));
  } on SocketException {
    return Err(const NetworkError());
  } catch (e, st) {
    _log.error('Unexpected error in getMessages', error: e, stackTrace: st);
    return Err(DatabaseError(e.toString()));
  }
}
```

---

## SUPABASE REALTIME

```dart
// Clean subscription management — always unsubscribe
@riverpod
class ChatController extends _$ChatController {
  RealtimeChannel? _channel;

  @override
  Future<List<Message>> build(String roomId) async {
    ref.onDispose(() {
      _channel?.unsubscribe(); // mandatory
      _channel = null;
    });

    await _subscribeToRoom(roomId);
    return _repo.getMessages(roomId);
  }

  void _subscribeToRoom(String roomId) {
    _channel = supabase
        .channel('room:$roomId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_id',
            value: roomId,
          ),
          callback: (payload) {
            final newMessage = Message.fromJson(payload.newRecord);
            state = AsyncData([...?state.valueOrNull, newMessage]);
          },
        )
        .subscribe();
  }
}
```

---

## RUST FFI

```dart
// Always off main isolate
Future<Uint8List> encryptMessage(Uint8List plaintext, Uint8List key) {
  return compute(_encryptIsolate, {'data': plaintext, 'key': key});
}

// Isolate function — no Flutter bindings
Uint8List _encryptIsolate(Map<String, Uint8List> args) {
  final result = nativeEncrypt(args['data']!, args['key']!);
  // Zero out key after use (Dart side)
  args['key']!.fillRange(0, args['key']!.length, 0);
  return result;
}
```

---

## WIDGET RULES

```dart
// ✅ Good widget
class MessageBubble extends StatelessWidget {
  const MessageBubble({              // const constructor — always
    super.key,                       // key parameter — always on reusable widgets
    required this.message,
    required this.isSent,
  });

  final Message message;
  final bool isSent;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(          // isolate repaints on animated children
      child: _BubbleContent(message: message, isSent: isSent),
    );
  }
}

// Extract when widget exceeds 80 lines
// StatefulWidget only for local UI state (animations, form fields)
// ConsumerWidget when reading providers
// ConsumerStatefulWidget when both
```

**Performance:**
- `ListView.builder` not `ListView` for >10 items
- `const` widgets everywhere — they never rebuild
- `RepaintBoundary` around heavy or animated widgets
- `cached_network_image` for all network images with placeholder
- `MediaQuery.of(context)` only at top level — pass sizes down

---

## ADAPTIVE FOLDER STRUCTURE

Agent detects and follows. Never impose. Document in MEMORY.md.

**Feature-first (common):**
```
lib/features/[feature]/
  ├── data/          # repositories, DTOs, data sources
  ├── domain/        # models, interfaces, use cases
  └── presentation/  # screens, controllers/notifiers, widgets
```

**Layer-first (less common):**
```
lib/
  ├── data/          # all repositories
  ├── domain/        # all models + interfaces
  └── presentation/  # all screens + widgets
```

**Shared (both patterns):**
```
lib/shared/
  ├── widgets/       # reusable UI (no business logic)
  ├── theme/         # design tokens, theme config
  └── utils/         # pure functions, extensions, constants
```

