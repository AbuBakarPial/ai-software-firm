# SKILL: TDD · Web · v2026.11
> RED → GREEN → REFACTOR. Bug fix: write reproducing test first, then fix.

## DETECT FIRST
```bash
cat package.json | grep -E '"vitest|"jest|"playwright|"cypress|"msw|"@testing-library"'
ls vitest.config.ts jest.config.ts playwright.config.ts test/ __tests__/ 2>/dev/null
```

## TEST PYRAMID
```
Unit         70% — hooks, utils, pure components (fast, no DOM)
Integration  20% — API routes, DB queries, React components with mocks
E2E          10% — Playwright, critical user journeys only
```

## CORE SETUP

### Vitest config
```ts
// vitest.config.ts
import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  test: {
    globals: true,
    environment: 'jsdom',
    setupFiles: ['./test/setup.ts'],
    css: false,
    coverage: { provider: 'v8', reporter: ['text', 'lcov'], thresholds: { lines: 80, functions: 80, branches: 75, statements: 80 } },
  },
});
```

### test setup file
```ts
// test/setup.ts
import '@testing-library/jest-dom/vitest';
import { cleanup } from '@testing-library/react';
import { afterEach, vi } from 'vitest';

afterEach(() => cleanup());

// Mock matchMedia, IntersectionObserver, etc.
Object.defineProperty(window, 'matchMedia', {
  writable: true,
  value: vi.fn().mockImplementation(query => ({ matches: false, media: query, onchange: null, addEventListener: vi.fn(), removeEventListener: vi.fn(), dispatchEvent: vi.fn() })),
});
```

## UNIT TESTS — components, hooks, utils

### Component test (React Testing Library)
```tsx
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MessageInput } from './MessageInput';

describe('MessageInput', () => {
  it('calls onSend with trimmed content on Enter', async () => {
    const onSend = vi.fn();
    const user = userEvent.setup();
    render(<MessageInput onSend={onSend} />);

    await user.type(screen.getByRole('textbox'), '  Hello  ');
    await user.keyboard('{Enter}');

    expect(onSend).toHaveBeenCalledWith('Hello');
    expect(screen.getByRole('textbox')).toHaveValue('');
  });

  it('does not call onSend with empty content', async () => {
    const onSend = vi.fn();
    const user = userEvent.setup();
    render(<MessageInput onSend={onSend} />);

    await user.keyboard('{Enter}');

    expect(onSend).not.toHaveBeenCalled();
  });
});
```

### Hook test (renderHook)
```tsx
import { renderHook, act, waitFor } from '@testing-library/react';
import { useMessageCount } from './useMessageCount';

describe('useMessageCount', () => {
  it('returns message count for a room', async () => {
    const { result } = renderHook(() => useMessageCount('room-1'));

    await waitFor(() => expect(result.current.isLoading).toBe(false));
    expect(result.current.count).toBeGreaterThanOrEqual(0);
  });
});
```

## INTEGRATION TESTS — API with MSW

### MSW handler setup
```ts
// test/mocks/handlers.ts
import { http, HttpResponse } from 'msw';

export const handlers = [
  http.get('/api/messages/:roomId', ({ params, request }) => {
    const url = new URL(request.url);
    const cursor = url.searchParams.get('cursor');
    return HttpResponse.json({
      items: [
        { id: '1', content: 'Hello', createdAt: '2024-01-01T00:00:00Z', author: { name: 'Alice' } },
      ],
      nextCursor: null,
    });
  }),
  http.post('/api/messages', async ({ request }) => {
    const body = await request.json() as Record<string, unknown>;
    if (!body.content) return new HttpResponse(null, { status: 400 });
    return HttpResponse.json({ id: 'new-1', content: body.content, createdAt: new Date().toISOString() }, { status: 201 });
  }),
];
```

### MSW server setup
```ts
// test/mocks/server.ts
import { setupServer } from 'msw/node';
import { handlers } from './handlers';

export const server = setupServer(...handlers);
```

### Integration test
```ts
import { server } from '../test/mocks/server';

beforeAll(() => server.listen({ onUnhandledRequest: 'warn' }));
afterEach(() => server.resetHandlers());
afterAll(() => server.close());

describe('POST /api/messages — integration', () => {
  it('returns 201 with valid body', async () => {
    const res = await fetch('/api/messages', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ content: 'Hello' }) });
    expect(res.status).toBe(201);
    const body = await res.json();
    expect(body.id).toBeDefined();
  });

  it('returns 400 with empty body', async () => {
    const res = await fetch('/api/messages', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{}' });
    expect(res.status).toBe(400);
  });

  it('returns 401 without auth token', async () => {
    server.use(http.post('/api/messages', () => new HttpResponse(null, { status: 401 })));
    const res = await fetch('/api/messages', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ content: 'Hello' }) });
    expect(res.status).toBe(401);
  });
});
```

### Integration test with database
```ts
import { db } from '@/lib/db';
import { POST } from '@/app/api/messages/route';

describe('POST /api/messages — with DB', () => {
  beforeEach(async () => {
    await db.message.create({ data: { content: 'Seed', roomId: 'room-1', authorId: 'user-1' } });
  });
  afterEach(async () => {
    await db.message.deleteMany();  // or transaction rollback
  });

  it('persists message and returns it', async () => {
    const req = new Request('http://localhost/api/messages', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ content: 'Test', roomId: 'room-1' }) });
    const res = await POST(req);
    expect(res.status).toBe(201);
    const count = await db.message.count({ where: { roomId: 'room-1' } });
    expect(count).toBe(2);
  });
});
```

## PLAYWRIGHT E2E — critical journeys only
```ts
// tests/e2e/message-flow.spec.ts
import { test, expect } from '@playwright/test';

test('user can send and see message', async ({ page }) => {
  await page.goto('/chat/room-1');
  await page.getByRole('textbox', { name: 'Message' }).fill('Hello team');
  await page.keyboard.press('Enter');
  await expect(page.getByText('Hello team')).toBeVisible();
});

test('redirects to login when unauthenticated', async ({ page }) => {
  await page.goto('/chat/room-1');
  await expect(page).toHaveURL(/\/login/);
});

// Snapshot test — visual regression
test('message list matches snapshot', async ({ page }) => {
  await page.goto('/chat/room-1');
  await expect(page).toHaveScreenshot('message-list.png', { maxDiffPixelRatio: 0.02 });
});
```

## COMMANDS
```bash
vitest                    # watch mode (development)
vitest run                # CI mode (single run)
vitest run --coverage     # CI with coverage report
vitest run --changed      # only changed files
playwright test           # E2E (headless)
playwright test --ui      # debug mode (headed + inspector)
playwright test --project chromium --retries 2  # flaky test debug
```

## COVERAGE GATES
| Layer | Threshold | Notes |
|-------|-----------|-------|
| Utilities | ≥95% | Pure functions, helpers, formatters |
| Components | ≥70% | DOM interaction, user events |
| Hooks | ≥85% | State logic, effects |
| API routes | ≥85% | Validation, auth, business rules |
| **Overall** | **≥80%** | |

## TEST FIXTURES (reusable, type-safe)
```ts
// test/fixtures/messages.ts
import { faker } from '@faker-js/faker';

export function buildMessage(overrides: Partial<Message> = {}): Message {
  return {
    id: faker.string.uuid(),
    content: faker.lorem.sentence(),
    roomId: 'room-1',
    authorId: faker.string.uuid(),
    createdAt: faker.date.recent(),
    ...overrides,
  };
}

export function buildMessageList(count = 5): Message[] {
  return Array.from({ length: count }, () => buildMessage());
}
```

## ANTI-PATTERNS TO AVOID
- ❌ Testing implementation details (state, internal methods) → test behavior
- ❌ snapshot tests that are 200+ lines → keep snapshots focused
- ❌ `fireEvent` instead of `userEvent` → userEvent simulates real interactions
- ❌ `act(() => ...)` wrappers everywhere → wrapQueryClient, waitFor handles it
- ❌ Testing libraries' internals → test your code, not React/Query
- ❌ msw handlers returning stale data → use `server.use(...)` for test-specific overrides
