# SKILL: Design System · v2026.9
> Load when: building any UI, theming, or component.
> FIRST: detect if a design system already exists. Match it.

---

## STEP 0 — DETECT EXISTING DESIGN

```bash
# Check for existing design system
find lib -name "*theme*" -o -name "*tokens*" -o -name "*colors*" -o -name "*styles*" | grep "\.dart$"
grep -r "ThemeData\|ColorScheme\|TextTheme" lib --include="*.dart" -l | head -5
grep -r "Color(0x" lib --include="*.dart" | head -10  # detect existing color values
```

If design system exists → extend it, never replace.
If none exists → build from tokens below.
Write findings to MEMORY.md.

---

## DESIGN PHILOSOPHY

Messenger app UI principles:
- **Trust** — clean, uncluttered, nothing screams for attention
- **Speed** — instant feedback, skeleton loaders not spinners, optimistic UI
- **Focus** — content first, chrome last
- Reference: Signal's precision + modern warmth. NOT: social media bright. NOT: generic Material defaults.

---

## DESIGN TOKENS

```dart
// lib/shared/theme/app_tokens.dart
abstract final class AppTokens {
  // Spacing — 4pt grid system
  static const double sp2  = 2;
  static const double sp4  = 4;
  static const double sp8  = 8;
  static const double sp12 = 12;
  static const double sp16 = 16;
  static const double sp20 = 20;
  static const double sp24 = 24;
  static const double sp32 = 32;
  static const double sp48 = 48;
  static const double sp64 = 64;

  // Border radius
  static const double rXs  = 4;
  static const double rSm  = 8;
  static const double rMd  = 12;
  static const double rLg  = 16;
  static const double rXl  = 24;
  static const double rFull = 999;

  // Type scale
  static const double tXs   = 11;
  static const double tSm   = 13;
  static const double tBase = 15;
  static const double tLg   = 17;
  static const double tXl   = 20;
  static const double t2xl  = 24;
  static const double t3xl  = 30;

  // Animation
  static const Duration fast   = Duration(milliseconds: 120);
  static const Duration base   = Duration(milliseconds: 220);
  static const Duration slow   = Duration(milliseconds: 380);
  static const Duration xslow  = Duration(milliseconds: 600);

  // Tap targets — WCAG minimum
  static const double tapMin = 48;
}
```

---

## COLOR SYSTEM

```dart
// lib/shared/theme/app_colors.dart
abstract final class AppColors {
  // Brand — deep teal (trust, security, calm)
  static const Color primary      = Color(0xFF0A7B6C);
  static const Color primaryLight = Color(0xFF14A896);
  static const Color primaryDark  = Color(0xFF065E52);
  static const Color primarySurf  = Color(0xFFE0F2EF);

  // Semantic
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error   = Color(0xFFEF4444);
  static const Color info    = Color(0xFF3B82F6);

  // Dark neutrals
  static const Color dark900 = Color(0xFF0F1117);
  static const Color dark800 = Color(0xFF1A1D27);
  static const Color dark700 = Color(0xFF252836);
  static const Color dark600 = Color(0xFF2E3347);
  static const Color dark400 = Color(0xFF6B7280);

  // Light neutrals
  static const Color light100 = Color(0xFFF4F5F7);
  static const Color light200 = Color(0xFFE8EAEF);
  static const Color light300 = Color(0xFFD1D5DB);

  // Chat bubbles
  static const Color bubbleSent     = Color(0xFF0A7B6C);
  static const Color bubbleSentText = Color(0xFFFFFFFF);
  static const Color bubbleRecvDark = Color(0xFF252836);
  static const Color bubbleRecvText = Color(0xFFE8EAEF);
  static const Color bubbleRecvLight    = Color(0xFFEEEEEE);
  static const Color bubbleRecvLightText = Color(0xFF1A1D27);

  // Status indicators
  static const Color online  = Color(0xFF22C55E);
  static const Color away    = Color(0xFFF59E0B);
  static const Color offline = Color(0xFF6B7280);
  static const Color typing  = Color(0xFF3B82F6);
}
```

---

## THEME CONFIG

```dart
// lib/shared/theme/app_theme.dart
final class AppTheme {
  static ThemeData dark() => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      surface: AppColors.dark800,
      surfaceContainerHighest: AppColors.dark700,
      onPrimary: Colors.white,
      onSurface: AppColors.light200,
      error: AppColors.error,
    ),
    scaffoldBackgroundColor: AppColors.dark900,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.dark800,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: AppColors.light200),
      titleTextStyle: TextStyle(
        fontSize: AppTokens.tLg,
        fontWeight: FontWeight.w600,
        color: AppColors.light200,
        letterSpacing: -0.3,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.dark700,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTokens.rFull),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTokens.rFull),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppTokens.sp16,
        vertical: AppTokens.sp12,
      ),
      hintStyle: const TextStyle(color: AppColors.dark400, fontSize: AppTokens.tBase),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.dark700,
      thickness: 0.5,
      space: 0,
    ),
    extensions: const [AppThemeExtension.dark],
  );

  static ThemeData light() => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      surface: Colors.white,
      onPrimary: Colors.white,
      onSurface: AppColors.dark800,
    ),
    scaffoldBackgroundColor: AppColors.light100,
    extensions: const [AppThemeExtension.light],
  );
}

// Custom theme extension for project-specific tokens
@immutable
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  const AppThemeExtension({
    required this.bubbleSentColor,
    required this.bubbleReceivedColor,
    required this.onlineColor,
  });

  final Color bubbleSentColor;
  final Color bubbleReceivedColor;
  final Color onlineColor;

  static const dark = AppThemeExtension(
    bubbleSentColor: AppColors.bubbleSent,
    bubbleReceivedColor: AppColors.bubbleRecvDark,
    onlineColor: AppColors.online,
  );

  static const light = AppThemeExtension(
    bubbleSentColor: AppColors.bubbleSent,
    bubbleReceivedColor: AppColors.bubbleRecvLight,
    onlineColor: AppColors.online,
  );

  @override
  AppThemeExtension copyWith({Color? bubbleSentColor, Color? bubbleReceivedColor, Color? onlineColor}) =>
      AppThemeExtension(
        bubbleSentColor: bubbleSentColor ?? this.bubbleSentColor,
        bubbleReceivedColor: bubbleReceivedColor ?? this.bubbleReceivedColor,
        onlineColor: onlineColor ?? this.onlineColor,
      );

  @override
  AppThemeExtension lerp(AppThemeExtension other, double t) => AppThemeExtension(
        bubbleSentColor: Color.lerp(bubbleSentColor, other.bubbleSentColor, t)!,
        bubbleReceivedColor: Color.lerp(bubbleReceivedColor, other.bubbleReceivedColor, t)!,
        onlineColor: Color.lerp(onlineColor, other.onlineColor, t)!,
      );
}
```

---

## CHAT BUBBLE

```dart
class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    required this.isSent,
    required this.timestamp,
    this.status = MessageStatus.sent,
    this.isGrouped = false, // true = smaller margin (consecutive messages)
  });

  final String message;
  final bool isSent;
  final DateTime timestamp;
  final MessageStatus status;
  final bool isGrouped;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AppThemeExtension>()!;
    final bubbleColor = isSent ? theme.bubbleSentColor : theme.bubbleReceivedColor;
    final textColor = isSent ? AppColors.bubbleSentText : AppColors.bubbleRecvText;

    return Align(
      alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        margin: EdgeInsets.only(
          left: isSent ? AppTokens.sp48 : AppTokens.sp8,
          right: isSent ? AppTokens.sp8 : AppTokens.sp48,
          bottom: isGrouped ? AppTokens.sp2 : AppTokens.sp8,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.sp12,
          vertical: AppTokens.sp8,
        ),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(AppTokens.rLg),
            topRight: const Radius.circular(AppTokens.rLg),
            bottomLeft: Radius.circular(isSent ? AppTokens.rLg : AppTokens.rXs),
            bottomRight: Radius.circular(isSent ? AppTokens.rXs : AppTokens.rLg),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            SelectableText(          // allow text selection
              message,
              style: TextStyle(color: textColor, fontSize: AppTokens.tBase, height: 1.45),
            ),
            const SizedBox(height: AppTokens.sp4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _time(timestamp),
                  style: TextStyle(fontSize: AppTokens.tXs, color: textColor.withOpacity(0.55)),
                ),
                if (isSent) ...[
                  const SizedBox(width: AppTokens.sp4),
                  _StatusTick(status: status, color: textColor),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _time(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}
```

---

## SKELETON LOADERS (not spinners)

```dart
// Use shimmer effect for loading states — feels faster
class MessageListSkeleton extends StatelessWidget {
  const MessageListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.dark700,
      highlightColor: AppColors.dark600,
      child: ListView.builder(
        itemCount: 6,
        padding: const EdgeInsets.all(AppTokens.sp16),
        itemBuilder: (_, i) => _SkeletonBubble(isSent: i.isEven),
      ),
    );
  }
}
```

---

## OPTIMISTIC UI PATTERN

```dart
// Show message immediately, reconcile after server confirms
Future<void> sendMessage(String content) async {
  final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
  final optimistic = Message(id: tempId, content: content, status: MessageStatus.sending);

  // 1. Add to UI immediately
  state = AsyncData([...?state.valueOrNull, optimistic]);

  // 2. Send to server
  final result = await _repo.sendMessage(roomId, content);

  // 3. Replace temp with real or mark failed
  result.fold(
    (error) => _markFailed(tempId),
    (real) => _replace(tempId, real),
  );
}
```

---

## ACCESSIBILITY

- Min tap target: 48×48dp — wrap small icons with `SizedBox(width: 48, height: 48)`
- `Semantics` label on all non-text interactive widgets
- Color alone never conveys state — always icon + color
- WCAG AA: 4.5:1 contrast ratio for text (test with `accessibility_tools` package)
- `TextScaler` test at 1.5× and 2.0× — no overflow allowed
- Voice message: provide transcript option for deaf users

---

## UI ANTI-PATTERNS

- `Expanded` inside `Column` inside `SingleChildScrollView` → infinite height error
- `setState` in `initState` → use `addPostFrameCallback`
- Nested `Scaffold` → layout bugs
- Hardcoded pixel values → use `AppTokens` constants
- Default blue focus ring → override in theme
- `Text` without `overflow: TextOverflow.ellipsis` on variable-length data
- Spinner for loading → use skeleton shimmer
- No empty state UI → always handle empty list
- No error state UI → always handle errors

