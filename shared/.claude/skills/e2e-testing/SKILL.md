# SKILL: E2E Testing · v2026.11
> Load when: writing end-to-end or integration tests, setting up Playwright (web) or Detox/Maestro (Flutter), or debugging flaky tests.
> Covers: Playwright (web/Next.js), Detox (Flutter), Maestro (Flutter), CI integration, Page Object Model, test data

## DETECT FIRST
```bash
# Existing E2E setup?
cat package.json | grep -E "playwright|cypress|detox|puppeteer"
ls playwright.config.ts playwright.config.js .maestro/ e2e/ cypress/ 2>/dev/null
ls integration_test/ test/e2e/ 2>/dev/null  # Flutter

# What's already configured?
npx playwright show-report 2>/dev/null | head -5
```

---

## WHAT GETS E2E TESTS

**E2E tests are expensive — be selective.**

```
✅ Critical user journeys (sign up, login, checkout, core feature)
✅ Cross-system flows (auth → API → DB → UI)
✅ Regression traps (bugs that slipped through unit/integration)
✅ Smoke tests (is the app up and not broken?)

❌ UI styling/layout details (use visual regression or screenshot tests)
❌ Logic that unit tests already cover
❌ Every permutation of a form (unit test the validator)
```

Rule: ~5-10% of your test suite. If E2E takes >15 min in CI, cut it.

---

## PLAYWRIGHT — Web (Next.js / React)

### Install + config
```bash
npm install -D @playwright/test
npx playwright install chromium  # install browsers

# Minimal CI — chromium only. Local: all browsers.
```

```typescript
// playwright.config.ts
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 4 : undefined,
  reporter: [['html'], ['github']],  // github reporter for CI annotations
  use: {
    baseURL: process.env.E2E_BASE_URL ?? 'http://localhost:3000',
    trace: 'on-first-retry',         // saves trace on failure
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
    // Add firefox/webkit only if you have separate budget
  ],
  webServer: process.env.CI ? undefined : {
    command: 'npm run dev',
    url: 'http://localhost:3000',
    reuseExistingServer: true,
  },
});
```

### Page Object Model (POM) — mandatory for anything >10 tests
```typescript
// e2e/pages/LoginPage.ts
import { Page, Locator } from '@playwright/test';

export class LoginPage {
  readonly emailInput: Locator;
  readonly passwordInput: Locator;
  readonly submitButton: Locator;
  readonly errorMessage: Locator;

  constructor(private page: Page) {
    this.emailInput    = page.getByLabel('Email');
    this.passwordInput = page.getByLabel('Password');
    this.submitButton  = page.getByRole('button', { name: 'Sign in' });
    this.errorMessage  = page.getByRole('alert');
  }

  async goto() {
    await this.page.goto('/login');
  }

  async login(email: string, password: string) {
    await this.emailInput.fill(email);
    await this.passwordInput.fill(password);
    await this.submitButton.click();
  }
}
```

### Critical journey test
```typescript
// e2e/auth.spec.ts
import { test, expect } from '@playwright/test';
import { LoginPage } from './pages/LoginPage';

test.describe('Authentication', () => {
  test('user can sign up, log in, and access dashboard', async ({ page }) => {
    const loginPage = new LoginPage(page);
    const testEmail = `test+${Date.now()}@example.com`;

    // Sign up
    await page.goto('/signup');
    await page.getByLabel('Email').fill(testEmail);
    await page.getByLabel('Password').fill('SecurePass123!');
    await page.getByRole('button', { name: 'Create account' }).click();
    await expect(page).toHaveURL('/onboarding');

    // Verify email flow (test env: skip)
    // Log in
    await loginPage.goto();
    await loginPage.login(testEmail, 'SecurePass123!');
    await expect(page).toHaveURL('/dashboard');
    await expect(page.getByText('Welcome')).toBeVisible();
  });

  test('shows error on invalid credentials', async ({ page }) => {
    const loginPage = new LoginPage(page);
    await loginPage.goto();
    await loginPage.login('nobody@example.com', 'wrongpassword');
    await expect(loginPage.errorMessage).toContainText('Invalid');
    await expect(page).toHaveURL('/login'); // did not navigate away
  });
});
```

### Authentication state — don't log in every test
```typescript
// e2e/fixtures/auth.ts — reuse auth state across tests
import { test as base } from '@playwright/test';
import { LoginPage } from '../pages/LoginPage';

export const test = base.extend<{ authenticatedPage: void }>({
  authenticatedPage: [async ({ page }, use) => {
    // Log in once, reuse browser session
    const loginPage = new LoginPage(page);
    await loginPage.goto();
    await loginPage.login(
      process.env.E2E_USER_EMAIL!,
      process.env.E2E_USER_PASSWORD!
    );
    await page.waitForURL('/dashboard');
    await use(); // run the test
  }, { auto: true }],
});

// Or: storageState (persist cookies to file, load in all tests)
// Run setup project once: npx playwright test --project=setup
```

### API mocking — isolate from flaky backends
```typescript
test('shows empty state when no orders', async ({ page }) => {
  await page.route('**/api/orders', route =>
    route.fulfill({ status: 200, body: JSON.stringify([]) })
  );
  await page.goto('/orders');
  await expect(page.getByText('No orders yet')).toBeVisible();
});

// Mock slow network
test('shows loading skeleton', async ({ page }) => {
  await page.route('**/api/orders', async route => {
    await page.waitForTimeout(1000);
    await route.continue();
  });
  await page.goto('/orders');
  await expect(page.getByTestId('skeleton')).toBeVisible();
});
```

### Commands
```bash
npx playwright test                         # all tests
npx playwright test e2e/auth.spec.ts        # one file
npx playwright test --ui                    # interactive UI mode
npx playwright test --headed                # see browser
npx playwright test --debug                 # step through
npx playwright show-report                  # view HTML report
npx playwright codegen http://localhost:3000 # record interactions → generate code
```

---

## MAESTRO — Flutter (recommended: simpler than Detox)

### Install
```bash
# macOS/Linux
curl -Ls "https://get.maestro.mobile.dev" | bash

# Run test
maestro test .maestro/login.yaml
maestro test .maestro/         # all flows
```

### Flow definition
```yaml
# .maestro/login.yaml
appId: com.example.myapp
---
- launchApp:
    clearState: true

- assertVisible: "Welcome back"

- tapOn:
    text: "Email"
- inputText: "test@example.com"

- tapOn:
    text: "Password"
- inputText: "SecurePass123!"

- tapOn:
    text: "Sign in"

- assertVisible: "Dashboard"
- assertNotVisible: "Sign in"
```

```yaml
# .maestro/checkout.yaml
appId: com.example.myapp
---
- launchApp
- runFlow: .maestro/login.yaml  # reuse

- tapOn:
    id: "product_item_0"
- tapOn:
    text: "Add to cart"
- tapOn:
    text: "Checkout"
- assertVisible: "Order confirmed"
```

---

## DETOX — Flutter (more control, more setup)

```bash
# Install
npm install -D detox @config-plugins/detox

# Build app for testing
detox build --configuration ios.sim.debug

# Run
detox test --configuration ios.sim.debug
```

```typescript
// e2e/login.test.ts
describe('Login flow', () => {
  beforeAll(async () => {
    await device.launchApp({ newInstance: true });
  });

  beforeEach(async () => {
    await device.reloadReactNative();
  });

  it('should login successfully', async () => {
    await element(by.id('email-input')).typeText('test@example.com');
    await element(by.id('password-input')).typeText('password123');
    await element(by.id('login-button')).tap();
    await expect(element(by.id('dashboard-screen'))).toBeVisible();
  });
});
```

---

## CI INTEGRATION

```yaml
# .github/workflows/e2e.yml
name: E2E Tests
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  e2e:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '22' }
      - run: npm ci
      - run: npx playwright install --with-deps chromium

      - name: Build app
        run: npm run build
        env:
          DATABASE_URL: ${{ secrets.E2E_DATABASE_URL }}

      - name: Run E2E
        run: npx playwright test
        env:
          E2E_BASE_URL: http://localhost:3000
          E2E_USER_EMAIL: ${{ secrets.E2E_USER_EMAIL }}
          E2E_USER_PASSWORD: ${{ secrets.E2E_USER_PASSWORD }}

      - uses: actions/upload-artifact@v4
        if: failure()
        with:
          name: playwright-report
          path: playwright-report/
          retention-days: 7
```

---

## FIXING FLAKY TESTS

| Symptom | Cause | Fix |
|---------|-------|-----|
| `locator.click()` timing out | Element not yet visible | Use `waitFor` / Playwright auto-waits — avoid `sleep` |
| Tests pass solo, fail parallel | Shared test data collision | Isolate test data per run (unique email `+Date.now()`) |
| Different results on CI vs local | Timezone / env diff | Set `TZ=UTC` in CI; use deterministic seeds |
| Selector breaks on refactor | Brittle CSS selector | Use `getByRole`, `getByLabel`, `getByTestId` (a11y-first) |
| Auth state leaking between tests | No cleanup | `clearState: true` in Maestro; `beforeEach` in Playwright |
| Video/screenshot not saving | Wrong reporter config | `trace: 'on-first-retry'`, `screenshot: 'only-on-failure'` |

---

## SELECTOR PRIORITY (Playwright)

```
1. getByRole()        ← a11y-first, most resilient
2. getByLabel()       ← form fields
3. getByPlaceholder() ← inputs without labels
4. getByText()        ← visible text
5. getByTestId()      ← data-testid attribute (last resort but acceptable)
❌ CSS selectors      ← breaks on every refactor
❌ XPath              ← fragile, unreadable
```
