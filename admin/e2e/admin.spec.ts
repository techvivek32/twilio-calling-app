import { expect, test, type Page } from '@playwright/test';

import { E2E_NUMBER } from './global-setup';

const ADMIN_EMAIL = process.env.SEED_ADMIN_EMAIL ?? 'admin@businessconnect.local';
const ADMIN_PASSWORD = process.env.SEED_ADMIN_PASSWORD ?? 'ChangeMe123!';

const USER_NAME = 'E2E Test User';
const USER_EMAIL = 'e2e-user@businessconnect.local';
const USER_PASSWORD = 'TestPassword123!';

/** The desktop sidebar; scopes nav lookups away from in-page links. */
function nav(page: Page) {
  return page.getByRole('complementary');
}

/**
 * Server components stream in before React attaches handlers, so every
 * interaction waits for the app to hydrate first.
 */
async function hydrated(page: Page) {
  await expect(page.locator('body')).toHaveAttribute('data-hydrated', 'true');
}

async function goTo(page: Page, label: string) {
  await nav(page).getByRole('link', { name: label, exact: true }).click();
  await hydrated(page);
}

/** Expands one of the "add" panels; a no-op when it is already open. */
async function openPanel(page: Page, label: string) {
  const button = page.getByRole('button', { name: label });
  if ((await button.getAttribute('aria-expanded')) !== 'true') {
    await button.click();
  }
  await expect(button).toHaveAttribute('aria-expanded', 'true');
}

async function signIn(page: Page) {
  await page.goto('/login');
  await hydrated(page);
  await page.getByLabel('Email').fill(ADMIN_EMAIL);
  await page.getByLabel('Password').fill(ADMIN_PASSWORD);
  await page.getByRole('button', { name: 'Sign in' }).click();
  await expect(page).toHaveURL(/\/dashboard/);
  await hydrated(page);
}

/** Creates the shared test user through the UI. */
async function createTestUser(page: Page) {
  await goTo(page, 'Users');
  await openPanel(page, 'Add a user');
  await page.getByLabel('Full name').fill(USER_NAME);
  await page.getByLabel('Email').fill(USER_EMAIL);
  await page.getByLabel('Password', { exact: true }).fill(USER_PASSWORD);
  await page.getByRole('button', { name: 'Create user' }).click();
  await expect(page.getByText(`Created ${USER_NAME}.`)).toBeVisible();
}

/** Adds the reserved test number through the UI. */
async function createTestNumber(page: Page) {
  await goTo(page, 'Phone Numbers');
  await openPanel(page, 'Add a number manually');
  await page.getByLabel('Phone number').fill(E2E_NUMBER);
  await page.getByLabel('Label').fill('E2E line');
  await page.getByRole('button', { name: 'Add number' }).click();
  await expect(page.getByText(`Added ${E2E_NUMBER}.`)).toBeVisible();
}

test.describe('access control', () => {
  test('rejects a wrong password and blocks unauthenticated pages', async ({
    page,
  }) => {
    await page.goto('/dashboard');
    await expect(page).toHaveURL(/\/login/);
    await hydrated(page);

    await page.getByLabel('Email').fill(ADMIN_EMAIL);
    await page.getByLabel('Password').fill('definitely-wrong');
    await page.getByRole('button', { name: 'Sign in' }).click();

    await expect(page.getByText('Invalid email or password.')).toBeVisible();
    await expect(page).toHaveURL(/\/login/);
  });

  test('signs out back to the login screen', async ({ page }) => {
    await signIn(page);
    await nav(page).getByRole('button', { name: 'Sign out' }).click();
    await expect(page).toHaveURL(/\/login/);

    await page.goto('/users');
    await expect(page).toHaveURL(/\/login/);
  });
});

test.describe('theme', () => {
  test('switches between light and dark and remembers the choice', async ({
    page,
  }) => {
    await signIn(page);

    const html = page.locator('html');
    const group = nav(page).getByRole('radiogroup', { name: 'Colour theme' });

    await group.getByRole('radio', { name: 'Dark' }).click();
    await expect(html).toHaveClass(/dark/);

    // The choice must survive a full page load, with no flash of light.
    await page.reload();
    await hydrated(page);
    await expect(html).toHaveClass(/dark/);
    await expect(group.getByRole('radio', { name: 'Dark' })).toHaveAttribute(
      'aria-checked',
      'true',
    );

    await group.getByRole('radio', { name: 'Light' }).click();
    await expect(html).not.toHaveClass(/dark/);

    await page.reload();
    await hydrated(page);
    await expect(html).not.toHaveClass(/dark/);
  });

  test('dark mode reaches the signed-out screens too', async ({ page }) => {
    await signIn(page);
    await nav(page)
      .getByRole('radiogroup', { name: 'Colour theme' })
      .getByRole('radio', { name: 'Dark' })
      .click();
    await expect(page.locator('html')).toHaveClass(/dark/);

    await nav(page).getByRole('button', { name: 'Sign out' }).click();
    await expect(page).toHaveURL(/\/login/);
    await expect(page.locator('html')).toHaveClass(/dark/);

    // Leave the browser on the default so later specs are unaffected.
    await hydrated(page);
    await page
      .getByRole('radiogroup', { name: 'Colour theme' })
      .getByRole('radio', { name: 'Light' })
      .click();
  });
});

test.describe('provisioning', () => {
  test('creates a user, gives them a number, then takes it back', async ({
    page,
  }) => {
    await signIn(page);
    await createTestUser(page);
    await createTestNumber(page);

    const row = page.locator('tr', { hasText: '000-0123' });
    const select = row.getByLabel('Assigned to');
    await expect(select).toHaveValue('');

    await select.selectOption({ label: USER_NAME });
    await expect(row.getByText('Since')).toBeVisible();
    await expect(select).not.toHaveValue('');

    // The users table must reflect the same assignment.
    await goTo(page, 'Users');
    const userRow = page.locator('tr', { hasText: USER_NAME });
    await expect(userRow.getByText('+1 (555) 000-0123')).toBeVisible();

    // The app account can sign in and sees the number the admin gave it.
    const login = await page.request.post('/api/mobile/auth/login', {
      data: { email: USER_EMAIL, password: USER_PASSWORD },
    });
    expect(login.status()).toBe(200);
    const payload = await login.json();
    expect(payload.token).toBeTruthy();
    expect(payload.number?.phoneNumber).toBe(E2E_NUMBER);

    // Release it again.
    await goTo(page, 'Phone Numbers');
    const resetRow = page.locator('tr', { hasText: '000-0123' });
    await resetRow.getByLabel('Assigned to').selectOption('');
    await expect(resetRow.getByLabel('Assigned to')).toHaveValue('');

    // Which the app sees on its next sign-in.
    const afterRelease = await page.request.post('/api/mobile/auth/login', {
      data: { email: USER_EMAIL, password: USER_PASSWORD },
    });
    expect((await afterRelease.json()).number).toBeNull();

    // Remove the number, then the user.
    page.once('dialog', (dialog) => dialog.accept());
    await resetRow.getByRole('button', { name: 'Remove' }).click();
    await expect(page.locator('tr', { hasText: '000-0123' })).toHaveCount(0);

    await goTo(page, 'Users');
    await page
      .locator('tr', { hasText: USER_NAME })
      .getByRole('link', { name: `Manage ${USER_NAME}` })
      .click();
    await expect(page.getByRole('heading', { name: USER_NAME })).toBeVisible();

    page.once('dialog', (dialog) => dialog.accept());
    await page.getByRole('button', { name: 'Delete user' }).click();

    await expect(page).toHaveURL(/\/users$/);
    await expect(page.getByText(USER_NAME)).toHaveCount(0);

    // And can no longer sign in.
    const afterDelete = await page.request.post('/api/mobile/auth/login', {
      data: { email: USER_EMAIL, password: USER_PASSWORD },
    });
    expect(afterDelete.status()).toBe(401);
  });

  test('rejects a duplicate email', async ({ page }) => {
    await signIn(page);
    await createTestUser(page);

    await openPanel(page, 'Add a user');
    await page.getByLabel('Full name').fill('Duplicate');
    await page.getByLabel('Email').fill(USER_EMAIL);
    await page.getByLabel('Password', { exact: true }).fill(USER_PASSWORD);
    await page.getByRole('button', { name: 'Create user' }).click();

    await expect(
      page.getByText(`${USER_EMAIL} is already registered.`),
    ).toBeVisible();
  });

  test('rejects a short password server-side', async ({ page }) => {
    await signIn(page);
    await goTo(page, 'Users');
    await openPanel(page, 'Add a user');

    await page.getByLabel('Full name').fill('Short Password');
    await page.getByLabel('Email').fill('e2e-short@businessconnect.local');
    const password = page.getByLabel('Password', { exact: true });
    // Drop the browser minlength check to prove the server validates too.
    await password.evaluate((el) => el.removeAttribute('minlength'));
    await password.fill('short');
    await page.getByRole('button', { name: 'Create user' }).click();

    await expect(
      page.getByText('Password must be at least 8 characters.'),
    ).toBeVisible();
  });
});

test.describe('twilio settings', () => {
  test('validates and persists credentials', async ({ page }) => {
    await signIn(page);
    await goTo(page, 'Twilio Settings');

    await page.getByLabel('Account SID').fill('not-a-sid');
    await page.getByRole('button', { name: 'Save settings' }).click();
    await expect(
      page.getByText('A Twilio Account SID starts with "AC".'),
    ).toBeVisible();

    const sid = 'AC00000000000000000000000000000000';
    await page.getByLabel('Account SID').fill(sid);
    await page
      .getByLabel('Public webhook base URL')
      .fill('https://e2e.example.com');
    await page.getByRole('button', { name: 'Save settings' }).click();
    await expect(page.getByText('Twilio settings saved.')).toBeVisible();

    // Values survive a reload, proving they reached MongoDB.
    await page.reload();
    await hydrated(page);
    await expect(page.getByLabel('Account SID')).toHaveValue(sid);
    await expect(page.getByLabel('Public webhook base URL')).toHaveValue(
      'https://e2e.example.com',
    );

    // Reset so a re-run starts clean.
    await page.getByLabel('Account SID').fill('');
    await page.getByLabel('Public webhook base URL').fill('');
    await page.getByRole('button', { name: 'Save settings' }).click();
    await expect(page.getByText('Twilio settings saved.')).toBeVisible();
  });
});

test.describe('dashboard', () => {
  test('shows counters and guides setup while unconfigured', async ({
    page,
  }) => {
    await signIn(page);

    await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();
    await expect(page.getByText('Phone numbers', { exact: true })).toBeVisible();
    await expect(page.getByText('Calls today')).toBeVisible();

    // With no Twilio credentials saved the checklist points at Settings first.
    await expect(page.getByText('Finish setting up')).toBeVisible();
    await expect(page.getByText('Connect your Twilio account')).toBeVisible();
  });
});

test.describe('layout', () => {
  test('the sidebar stays pinned while the page scrolls', async ({ page }) => {
    await signIn(page);
    await goTo(page, 'Twilio Settings');

    const aside = nav(page);
    const before = await aside.boundingBox();
    expect(before).not.toBeNull();

    // The page must actually overflow, or this proves nothing.
    const overflow = await page.evaluate(
      () => document.body.scrollHeight - window.innerHeight,
    );
    expect(overflow).toBeGreaterThan(100);

    await page.evaluate(() => window.scrollTo(0, 400));
    await expect
      .poll(async () => page.evaluate(() => window.scrollY))
      .toBeGreaterThan(0);

    // `html`/`body` must grow with the content; capping them at the viewport
    // leaves the sticky rail no room to travel and it scrolls away.
    const after = await aside.boundingBox();
    expect(after!.y).toBeCloseTo(before!.y, 0);
  });

  test('the mobile header stays pinned while the page scrolls', async ({
    page,
  }) => {
    await page.setViewportSize({ width: 420, height: 780 });
    await signIn(page);

    const header = page.getByRole('banner');
    const before = await header.boundingBox();
    expect(before).not.toBeNull();

    await page.evaluate(() => window.scrollTo(0, 400));
    await expect
      .poll(async () => page.evaluate(() => window.scrollY))
      .toBeGreaterThan(0);

    const after = await header.boundingBox();
    expect(after!.y).toBeCloseTo(before!.y, 0);
  });
});
