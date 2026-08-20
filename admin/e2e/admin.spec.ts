import { expect, test, type Page } from '@playwright/test';

const ADMIN_EMAIL = process.env.SEED_ADMIN_EMAIL ?? 'admin@businessconnect.local';
const ADMIN_PASSWORD = process.env.SEED_ADMIN_PASSWORD ?? 'ChangeMe123!';

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

/** Follows a sidebar link and waits for the destination to be interactive. */
async function goTo(page: Page, label: string) {
  await nav(page).getByRole('link', { name: label, exact: true }).click();
  await hydrated(page);
}

/** Expands one of the "add" panels on a list page. */
async function openPanel(page: Page, label: string) {
  const button = page.getByRole('button', { name: label });
  await button.click();
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

test.describe('admin panel', () => {
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
  });

  test('dashboard shows live counters', async ({ page }) => {
    await signIn(page);

    await expect(
      page.getByRole('heading', { name: 'Dashboard' }),
    ).toBeVisible();
    await expect(
      page.getByText('Phone numbers', { exact: true }),
    ).toBeVisible();
    await expect(page.getByText('Calls today')).toBeVisible();
    await expect(page.getByText('Busiest users')).toBeVisible();
  });

  test('assigns a number to a user and releases it again', async ({ page }) => {
    await signIn(page);
    await goTo(page, 'Phone Numbers');
    await expect(
      page.getByRole('heading', { name: 'Phone Numbers' }),
    ).toBeVisible();

    // The seeded spare number starts unassigned.
    const row = page.locator('tr', { hasText: '077-7333' });
    await expect(row).toBeVisible();

    const select = row.locator('select');
    await expect(select).toHaveValue('');

    await select.selectOption({ label: 'Priya Nair' });
    await expect(row.getByText('Since')).toBeVisible();
    await expect(select).not.toHaveValue('');

    // The users table must reflect the same assignment.
    await goTo(page, 'Users');
    const priyaRow = page.locator('tr', { hasText: 'Priya Nair' });
    await expect(priyaRow.getByText('+1 (555) 077-7333')).toBeVisible();

    // Put it back so the test is repeatable.
    await goTo(page, 'Phone Numbers');
    const resetRow = page.locator('tr', { hasText: '077-7333' });
    await resetRow.locator('select').selectOption('');
    await expect(resetRow.locator('select')).toHaveValue('');
  });

  test('creates a user with a number, then deletes them', async ({ page }) => {
    await signIn(page);
    await goTo(page, 'Users');

    const email = `e2e-user@businessconnect.local`;

    await openPanel(page, 'Add a user');
    await page.getByLabel('Full name').fill('E2E Test User');
    await page.getByLabel('Email').fill(email);
    await page.getByLabel('Password').fill('TestPassword123!');
    await page.getByRole('button', { name: 'Create user' }).click();

    await expect(page.getByText('Created E2E Test User.')).toBeVisible();
    const row = page.locator('tr', { hasText: 'E2E Test User' });
    await expect(row).toBeVisible();

    // The new account must be able to sign in to the mobile API.
    const login = await page.request.post('/api/mobile/auth/login', {
      data: { email, password: 'TestPassword123!' },
    });
    expect(login.status()).toBe(200);
    const payload = await login.json();
    expect(payload.token).toBeTruthy();
    expect(payload.user.email).toBe(email);

    // Clean up through the UI, which also proves delete works.
    await row.getByRole('link', { name: 'Manage' }).click();
    await expect(
      page.getByRole('heading', { name: 'E2E Test User' }),
    ).toBeVisible();

    page.once('dialog', (dialog) => dialog.accept());
    await page.getByRole('button', { name: 'Delete user' }).click();

    // Deleting sends the admin back to the list, which must no longer show them.
    await expect(page).toHaveURL(/\/users$/);
    await expect(page.getByText('E2E Test User')).toHaveCount(0);

    // And the account can no longer sign in to the mobile API.
    const afterDelete = await page.request.post('/api/mobile/auth/login', {
      data: { email, password: 'TestPassword123!' },
    });
    expect(afterDelete.status()).toBe(401);
  });

  test('rejects a duplicate email', async ({ page }) => {
    await signIn(page);
    await goTo(page, 'Users');

    await openPanel(page, 'Add a user');
    await page.getByLabel('Full name').fill('Duplicate');
    await page.getByLabel('Email').fill('alex@businessconnect.local');
    await page.getByLabel('Password').fill('TestPassword123!');
    await page.getByRole('button', { name: 'Create user' }).click();

    await expect(
      page.getByText('alex@businessconnect.local is already registered.'),
    ).toBeVisible();
  });

  test('saves Twilio settings and validates the SID format', async ({
    page,
  }) => {
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

  test('adds a number by hand and removes it', async ({ page }) => {
    await signIn(page);
    await goTo(page, 'Phone Numbers');

    await openPanel(page, 'Add a number manually');
    await page.getByLabel('Phone number').fill('+15550000123');
    await page.getByLabel('Label').fill('E2E spare');
    await page.getByRole('button', { name: 'Add number' }).click();

    await expect(page.getByText('Added +15550000123.')).toBeVisible();
    const row = page.locator('tr', { hasText: '000-0123' });
    await expect(row).toBeVisible();
    await expect(row.getByText('E2E spare')).toBeVisible();

    page.once('dialog', (dialog) => dialog.accept());
    await row.getByRole('button', { name: 'Remove' }).click();
    await expect(page.locator('tr', { hasText: '000-0123' })).toHaveCount(0);
    await expect(page.getByLabel('Assigned to').first()).toBeVisible();
  });

  test('signs out back to the login screen', async ({ page }) => {
    await signIn(page);
    await nav(page).getByRole('button', { name: 'Sign out' }).click();
    await expect(page).toHaveURL(/\/login/);

    await page.goto('/users');
    await expect(page).toHaveURL(/\/login/);
  });
});
