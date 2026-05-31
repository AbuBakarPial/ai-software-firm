# SKILL: State Management · v2026.10
> Load when: choosing or debugging state management in any project.
> Covers: Riverpod, Bloc/Cubit, GetX (detect first, never mix)

## DETECT FIRST
```bash
grep -r "riverpod\|@riverpod" pubspec.yaml lib --include="*.dart" -l | head -3
grep -r "BlocProvider\|Cubit" pubspec.yaml lib --include="*.dart" -l | head -3
grep -r "GetX\|GetxController" pubspec.yaml lib --include="*.dart" -l | head -3
```
Use ONLY what's detected. Write finding to MEMORY.md.

## RIVERPOD 2.x (preferred modern pattern)
```dart
// @riverpod annotation — always prefer over manual
@riverpod
class AuthController extends _$AuthController {
  @override
  Future<User?> build() async => await _repo.getSession();

  Future<void> signIn(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.signIn(email, password));
  }
  Future<void> signOut() async {
    state = const AsyncLoading();
    await _repo.signOut();
    state = const AsyncData(null);
  }
}

// Scoped providers (family)
@riverpod
Future<Room> room(RoomRef ref, String roomId) => ref.watch(roomRepositoryProvider).getRoom(roomId);

// Combining providers
@riverpod
Future<RoomWithMessages> roomWithMessages(RoomWithMessagesRef ref, String roomId) async {
  final room = await ref.watch(roomProvider(roomId).future);
  final messages = await ref.watch(messagesProvider(roomId).future);
  return RoomWithMessages(room, messages);
}
```

## BLOC/CUBIT (if detected)
```dart
// Cubit (simpler — prefer over Bloc unless complex event mapping needed)
class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._repo) : super(const AuthInitial());

  Future<void> signIn(String email, String password) async {
    emit(const AuthLoading());
    final result = await _repo.signIn(email, password);
    result.fold(
      (error) => emit(AuthError(error.message)),
      (user) => emit(AuthAuthenticated(user)),
    );
  }
}

// UI — BlocBuilder only for local state, BlocListener for side effects
BlocConsumer<AuthCubit, AuthState>(
  listener: (ctx, state) { if (state is AuthAuthenticated) ctx.go('/home'); },
  builder: (ctx, state) => switch (state) {
    AuthLoading() => const CircularProgressIndicator(),
    AuthError(:final message) => ErrorWidget(message),
    _ => const LoginForm(),
  },
)
```

## COMMON PITFALLS
```dart
// ❌ Never read in build — always watch
ref.read(authProvider);          // in build → stale
ref.watch(authProvider);         // ✅

// ❌ Never store context across async gap
Future<void> foo(BuildContext ctx) async {
  await something();
  ctx.go('/home');               // ❌ context may be unmounted
}
// ✅
Future<void> foo(BuildContext ctx) async {
  await something();
  if (!mounted) return;          // ✅
  ctx.go('/home');
}

// ❌ Nested providers
@riverpod
class Bad extends _$Bad {
  @override
  Future<Data> build() async {
    final a = await ref.watch(aProvider.future);
    final b = await ref.watch(bProvider.future);   // ❌ nested future await
    return combine(a, b);
  }
}
// ✅ Use family + combine at top level
```
