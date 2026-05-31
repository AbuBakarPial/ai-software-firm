# ERRORS · Agent Failure Log
> READ THIS before every session. Never repeat a logged failure.
> Agent: write here immediately after any failed command or wrong output.

---

## HOW TO WRITE HERE

```
## ERROR-[N]
Date:    [YYYY-MM-DD]
Tool:    [OpenCode / Codex / Claude Code / other]
Action:  [what was attempted]
Error:   [exact error message]
Cause:   [why it happened]
Fix:     [what resolved it]
Guard:   [rule added to MEMORY.md to prevent recurrence]
```

---

## KNOWN ENVIRONMENT QUIRKS
> Pre-seeded. Agent reads these before touching the stack.

### Flutter + Dart
- `const` constructor missing on immutable widgets = unnecessary rebuilds — always add const
- `MediaQuery.of(context)` deep in widget tree = rebuilds entire subtree on resize — pass size as parameter
- `BuildContext` used across async gap = widget may be disposed — always check `mounted`
- `print()` left in production code = noise in logs — use `debugPrint` inside `kDebugMode` guard
- `flutter build` without `--release` = debug build with performance penalties
- Hot reload not caught by `@override` changes — always hot restart after method override edit

### Riverpod 2.x
- `ref.read` inside `build()` = silent stale data bug — use `ref.watch` in build
- `autoDispose` provider accessed after dispose = `StateError` — always check `mounted` before async gaps
- `ref.invalidate` without `.reconnect()` on stream providers = stream not reconnected — use `ref.invalidate(provider); ref.listen(provider, ...)`
- Notifier state mutation outside `@override` methods = state not tracked — always mutate via `state =`
- Family provider key mismatch = cached wrong data — key must be canonical (same object identity or primitive)

### GoRouter
- `context.go()` inside `build()` throws — use `WidgetsBinding.instance.addPostFrameCallback`
- Nested `ShellRoute` + `GoRoute` redirect loop — redirect must check current location before returning new path
- `GoRouter.of(context)` fails outside `MaterialApp` scope — use provider ref instead
- Route-level `state.extra` not persisted across app restart — use deep-link compatible approach

### Supabase + Dart
- `.select()` without column list = returns all columns including sensitive ones — always specify columns
- `PostgrestException` not caught = unhandled exception crashes app — every DB call needs try/catch
- Realtime subscription on unauthenticated channel = silent failure — verify auth before subscribing
- Realtime channels must be explicitly `unsubscribe()`d before re-subscribing — duplicate listeners cause double events
- `upsert()` without `onConflict` = inserts duplicate rows — always specify conflict column
- `supabase.auth.currentUser` returns null on first frame — always await `onAuthStateChange` before accessing user
- Service role key in app code = critical vulnerability — only anon key with RLS
- `flutter_secure_storage` fails on Android emulator without `minSdkVersion 18`

### Rust FFI
- FFI call on main isolate blocks UI — always use `compute()` or separate isolate
- `cargo build` not re-run after header change = stale bindings — run `flutter pub run ffigen` after any `.h` change
- Missing `zeroize` on key structs = key material lingers in memory — `#[derive(Zeroize, ZeroizeOnDrop)]` on all key types
- `unwrap()` at FFI boundary = panic crashes entire Flutter app — use `match` or return `Result`

### Testing (Flutter)
- `pumpWidget` without `pumpAndSettle` = incomplete widget tree — use `pumpAndSettle` after async operations
- Mock not registered in `ProviderScope` = real impl runs (network calls) — always use `overrideWithValue`
- Golden tests fail on different screen sizes — use `surfaceSize` to standardize

### CI/CD
- Protected variables unavailable in fork pipelines — expected behavior, not a bug
- Flutter SDK cache stale after version bump — add `flutter upgrade` or rebuild cache key
- `key.properties` not found in CI = release build fails — must be injected via CI variable, not committed
- `dart format --check` fails on CI if format not run locally — add pre-commit hook

---

## ERROR LOG

*(agent writes here — grows from real usage)*
