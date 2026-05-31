---
name: flutter-mcp
description: >
  Use when implementing Flutter features, debugging runtime issues, doing visual QA,
  or working with any pub.dev package. Covers the official Dart & Flutter MCP server
  (`dart mcp-server`, docs.flutter.dev/ai/mcp-server) — ships with Dart SDK, zero install.
---

# Flutter MCP Usage

## Server setup — zero install (built into Dart SDK)

The official Dart & Flutter MCP server is available with any recent Dart SDK:

```json
{
  "dart-mcp-server": {
    "command": "dart",
    "args": ["mcp-server"]
  }
}
```

No npm install needed. No brew tap. Runs as-is.

## pub.dev package lookup — use before any package import

Training data is stale. Always call the MCP server before using a package API you didn't write.

```
# Search pub.dev for the right package
pub_dev_search(query: "go_router navigation", limit: 5)

# Resolve a symbol and get its documentation + signature
resolve_symbol(uri: "package:go_router/go_router.dart", offset: 123)

# Add a dependency to pubspec.yaml
add_dependency(package: "riverpod", version: "^2.5.0")
```

**Rule:** any `package:` import you didn't write yourself → call `pub_dev_search` or `resolve_symbol` first.

## Runtime inspection and visual QA (requires `flutter run --debug`)

```dart
// Ensure your app is running in debug mode:
// flutter run --debug --host-vmservice-port=8182 --dds-port=8181
```

```
# Inspect widget tree at current state
get_widget_tree()

# Screenshot current screen (visual QA before /review)
screenshot()

# Hot reload after code change
hot_reload()

# Hot restart when state is corrupted
hot_restart()

# Analyze code for errors/warnings
dart_analyze(path: "lib/")

# Format code
dart_format(path: "lib/")
```

**Visual QA workflow (run before every /review):**
1. `screenshot()` — capture current state
2. Compare against design spec or last known-good screenshot
3. `get_widget_tree()` — verify structure matches intent
4. Only then mark UI task done

## When MCP server is unavailable (no Flutter project open)

Fall back to: read pubspec.yaml → check lib/ for existing usage patterns → check MEMORY.md for project conventions. Never invent API signatures.
