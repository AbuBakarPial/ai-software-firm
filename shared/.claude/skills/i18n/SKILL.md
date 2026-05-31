# SKILL: Internationalization (i18n) · v2026.10
> Load when: adding multi-language support, localizing UI, or formatting locale-sensitive data.
> Covers: Flutter intl, next-i18next, react-intl, ICU message syntax

## DETECT FIRST
```bash
# Flutter
cat pubspec.yaml | grep -E "flutter_localizations|intl|slang"
ls lib/l10n/ 2>/dev/null

# Web
cat package.json | grep -E "next-i18next|react-i18next|react-intl|lingui|i18n"
ls public/locales/ messages/ 2>/dev/null
```

---

## FLUTTER LOCALIZATION

### Setup (ARB files — Flutter standard)
```dart
// pubspec.yaml
dependencies:
  flutter_localizations:
    sdk: flutter
  intl: any

flutter:
  generate: true  // enables flutter gen-l10n
```

```
# lib/l10n/ — source of truth (English)
├── app_en.arb      ← base
├── app_es.arb      ← translations
├── app_fr.arb
└── app_ja.arb
```

```json
// app_en.arb
{
  "@@locale": "en",
  "appName": "Messenger",
  "@appName": { "description": "App name" },
  "welcomeMessage": "Welcome, {name}!",
  "@welcomeMessage": {
    "description": "Welcome message",
    "placeholders": {
      "name": { "type": "String" }
    }
  },
  "messages_one": "{count} message",
  "messages_other": "{count} messages",
  "@messages": {
    "placeholders": {
      "count": { "type": "int" }
    }
  }
}
```

```json
// app_es.arb
{
  "@@locale": "es",
  "appName": "Mensajero",
  "welcomeMessage": "¡Bienvenido, {name}!",
  "messages_one": "{count} mensaje",
  "messages_other": "{count} mensajes"
}
```

### Usage in code
```dart
// Generated: AppLocalizations.of(context)!.appName

// Text
Text(AppLocalizations.of(context)!.welcomeMessage(name: userName));

// Plural
Text(AppLocalizations.of(context)!.messages(count: unreadCount));

// Date formatting
final formatted = DateFormat.yMMMd(Localizations.localeOf(context).languageCode)
    .format(message.createdAt);

// Number formatting
final formatted = NumberFormat.currency(locale: locale, symbol: '€')
    .format(price);
```

### Generate + Build
```bash
flutter gen-l10n          # generates Dart code from ARB files
flutter build apk         # generates during build automatically
```

---

## NEXT.JS / REACT I18N (next-i18next)

### Setup
```typescript
// next-i18next.config.js
module.exports = {
  i18n: {
    defaultLocale: 'en',
    locales: ['en', 'es', 'fr', 'ja', 'zh'],
    localeDetection: true,
  },
};
```

```
# public/locales/
├── en/
│   ├── common.json     ← shared strings
│   └── chat.json       ← chat-specific
├── es/
│   ├── common.json
│   └── chat.json
└── fr/
    ├── common.json
    └── chat.json
```

```json
// public/locales/en/common.json
{
  "appName": "Messenger",
  "welcome": "Welcome, {{name}}!",
  "messages_one": "{{count}} message",
  "messages_other": "{{count}} messages"
}
```

### Usage in Next.js
```typescript
// app/layout.tsx
import { dir } from 'i18next';
import { languages } from '../i18n/settings';

export async function generateStaticParams() {
  return languages.map((lng) => ({ lng }));
}

export default function RootLayout({ children, params: { lng } }: {
  children: React.ReactNode;
  params: { lng: string };
}) {
  return (
    <html lang={lng} dir={dir(lng)}>
      <body>{children}</body>
    </html>
  );
}
```

```typescript
// Client component
'use client';
import { useTranslation } from 'next-i18next';

export default function Welcome({ userName }: { userName: string }) {
  const { t } = useTranslation('common');
  return <h1>{t('welcome', { name: userName })}</h1>;
}
```

---

## ICU MESSAGE SYNTAX (universal)

```
# Simple
{name} → Hello, John

# Plural
You have {count, plural,
  =0 {no messages}
  one {# message}
  other {# messages}
}

# Select (gender)
{gender, select,
  male {He} female {She} other {They}
} wrote a message

# Nested
{count, plural,
  one {{gender, select, male {His} female {Her} other {Their}} message}
  other {{gender, select, male {His} female {Her} other {Their}} messages}
}
```

---

## RIGHT-TO-LEFT (RTL) SUPPORT

```dart
// Flutter — MaterialApp auto-detects
MaterialApp(
  locale: locale,
  // RTL locales automatically get right-to-left layout
  // Widgets like Text, Row, Padding auto-mirror
  // Test with: Directionality.of(context)
);

// Web — CSS logical properties
.element {
  margin-inline-start: 8px;   /* auto-mirrors for RTL */
  padding-inline-end: 16px;
  border-inline-start: 1px solid;
}
/* Avoid: left/right — use inline-start/inline-end */
```

---

## I18N RULES

| Rule | Why |
|------|-----|
| Never concatenate strings | "Hello " + name → wrong word order in other languages |
| Always use ICU/ARB plural rules | "message(s)" doesn't work for Arabic/Slavic plurals |
| Extract ALL user-facing strings | No hardcoded text in UI |
| Default locale = English | Always ship with full English strings |
| Locale detection from system | User can override in settings |
| RTL layout support from day 1 | Retrofitting RTL is expensive |
| Test with pseudolocale | `flutter run --locale=xx` — shows translation gaps |
| Keep translations in version control | Never lose your i18n work |
| Use keys, not raw text in code | `t('greeting')` not `t('Hello')` |

---

## PSEUDOLOCALIZATION TESTING

```bash
# Flutter — test with pseudo-locale (replaces chars with accented versions)
flutter run --locale=xx

# Next.js — add pseudo locale for testing
# Creates locale that wraps all strings in brackets + adds accents
# Exposes truncation, hardcoded strings, missing translations
```
