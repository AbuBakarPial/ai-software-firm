# SKILL: Testing Web · v2026.10
> Load when: writing tests for React/Next.js/Node.js.

## PYRAMID
```
~5%  E2E (Playwright) — critical user journeys only
~15% Integration (MSW + RTL) — component + API contracts
~80% Unit (Vitest) — services, utils, hooks
```

## UNIT (Vitest)
```typescript
describe('MessageService.create', () => {
  it('assigns userId from auth context', async () => {
    const msg = await service.create('user-1', { content: 'hi', roomId: 'r1' });
    expect(msg.userId).toBe('user-1');
  });
  it('throws 404 when room not found', async () => {
    await expect(service.create('u1', { content: 'hi', roomId: 'missing' }))
      .rejects.toThrow(NotFoundError);
  });
});
```

## COMPONENT (React Testing Library)
```typescript
// Behavior, not implementation
test('shows skeleton while loading, then messages', async () => {
  render(<MessageList roomId="r1" />);
  expect(screen.getByTestId('messages-skeleton')).toBeInTheDocument();
  await waitFor(() => expect(screen.queryByTestId('messages-skeleton')).not.toBeInTheDocument());
  expect(screen.getAllByRole('article')).toHaveLength(3);
});

// Accessibility test
test('send button is accessible', () => {
  render(<SendButton />);
  expect(screen.getByRole('button', { name: /send message/i })).toBeInTheDocument();
});
```

## API MOCKING (MSW)
```typescript
const handlers = [
  http.get('/api/messages', ({ request }) => {
    const url = new URL(request.url);
    return HttpResponse.json({ messages: fixtures.messages });
  }),
  http.post('/api/messages', async ({ request }) => {
    const body = await request.json();
    return HttpResponse.json({ ...body, id: 'new-1' }, { status: 201 });
  }),
];
```

## E2E (Playwright)
```typescript
test('user sends message', async ({ page }) => {
  await page.goto('/chat/room-1');
  await page.fill('[data-testid="message-input"]', 'hello world');
  await page.click('[data-testid="send-btn"]');
  await expect(page.getByText('hello world')).toBeVisible();
});
test('unauthenticated redirects to login', async ({ page }) => {
  await page.goto('/dashboard');
  await expect(page).toHaveURL('/auth/login');
});
```

## RULES
- Test behavior, not implementation details
- No `getByTestId` for text/semantic queries — use `getByRole`/`getByText` first
- Each test has ONE clear assertion focus
- No mocking internal modules — mock at the boundary (HTTP, DB)
- `data-testid` only for elements with no semantic query option
