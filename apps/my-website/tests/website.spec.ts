import { expect, test } from '@playwright/test';

test('SSR metadata content and complete post list are available without JavaScript', async ({ browser }) => {
  const context = await browser.newContext({ javaScriptEnabled: false });
  const page = await context.newPage();
  await page.goto('/blog');
  await expect(page).toHaveTitle("Saikat's Blog");
  await expect(page.getByRole('list', { name: 'Blog posts' }).getByRole('listitem')).toHaveCount(30);
  await expect(page.getByRole('textbox', { name: 'Search blog posts' })).toBeDisabled();
  await expect(page.getByRole('button', { name: 'Toggle navigation menu' })).toBeDisabled();
  await expect(page.locator('meta[property="og:title"]')).toHaveAttribute('content', "Saikat's Blog");
  await page.goto('/blog/posts/react-hooks-usestate');
  await expect(page.getByRole('heading', { level: 1 })).toHaveText('React Hooks: useState');
  await expect(page.locator('article')).toContainText('Thu Aug 29 2019');
  await context.close();
});

test('client-side search matches title description tags and clears without network', async ({ page }) => {
  await page.goto('/blog');
  const search = page.getByRole('textbox', { name: 'Search blog posts' });
  const cards = page.getByRole('list', { name: 'Blog posts' }).getByRole('listitem');
  await expect(cards).toHaveCount(30);
  await expect(search).toBeEnabled();
  await page.context().setOffline(true);
  await search.fill('USESTATE');
  await expect(cards).toHaveCount(1);
  await expect(cards).toContainText('React Hooks: useState');
  await search.fill('COMMAND-LINE');
  await expect(cards).not.toHaveCount(0);
  await expect(cards.first()).toContainText('#command-line');
  await search.fill('uniquely-nonexistent-term');
  await expect(cards).toHaveCount(0);
  await search.fill('');
  await expect(cards).toHaveCount(30);
});

test('mobile menu toggles closes on Escape and navigation', async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto('/');
  const toggle = page.getByRole('button', { name: 'Toggle navigation menu' });
  const navigation = page.getByRole('navigation', { name: 'Main navigation' });
  await expect(toggle).toBeEnabled();
  await expect(toggle).toHaveAttribute('aria-expanded', 'false');
  await toggle.click();
  await expect(navigation).toBeVisible();
  await page.keyboard.press('Escape');
  await expect(navigation).toBeHidden();
  await toggle.click();
  await navigation.getByRole('link', { name: 'Blog', exact: true }).click();
  await expect(page).toHaveURL('/blog');
  await expect(navigation).toBeHidden();
});

test('desktop auto-opens and retains menu on navigation then closes on mobile resize', async ({ page }) => {
  await page.setViewportSize({ width: 1600, height: 1000 });
  await page.goto('/');
  const navigation = page.getByRole('navigation', { name: 'Main navigation' });
  await expect(page.getByRole('button', { name: 'Toggle navigation menu' })).toBeEnabled();
  await expect(navigation).toBeVisible();
  await navigation.getByRole('link', { name: "Things I've built" }).click();
  await expect(page).toHaveURL('/projects');
  await expect(navigation).toBeVisible();
  await page.setViewportSize({ width: 390, height: 844 });
  await expect(navigation).toBeHidden();
});

test('controls remain disabled while hydration scripts are delayed and become interactive after mount', async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  let releaseHydration!: () => void;
  const hydrationAllowed = new Promise<void>((resolve) => { releaseHydration = resolve; });
  await page.route('**/_app/immutable/**/*.js', async (route) => {
    await hydrationAllowed;
    await route.continue();
  });
  const search = page.getByRole('textbox', { name: 'Search blog posts' });
  const toggle = page.getByRole('button', { name: 'Toggle navigation menu' });
  const navigation = page.getByRole('navigation', { name: 'Main navigation' });
  const cards = page.getByRole('list', { name: 'Blog posts' }).getByRole('listitem');
  try {
    await page.goto('/blog', { waitUntil: 'domcontentloaded' });
    await expect(cards).toHaveCount(30);
    await expect(search).toBeDisabled();
    await expect(toggle).toBeDisabled();
    await expect(toggle).toHaveAttribute('aria-expanded', 'false');
    await expect(navigation).toBeHidden();
  } finally {
    releaseHydration();
  }
  await expect(search).toBeEnabled();
  await expect(toggle).toBeEnabled();
  await page.context().setOffline(true);
  await search.fill('USESTATE');
  await expect(cards).toHaveCount(1);
  await expect(cards).toContainText('React Hooks: useState');
  await toggle.click();
  await expect(navigation).toBeVisible();
  await page.keyboard.press('Escape');
  await expect(navigation).toBeHidden();
});

test('project HTML assets dates and technology list survive prerendering', async ({ page, request }) => {
  await page.goto('/projects/entries/the-knotty-tales');
  await expect(page.getByRole('heading', { level: 1 })).toHaveText('The Knotty Tales');
  await expect(page.locator('article')).toContainText('Sep 2019');
  await expect(page.locator('article')).toContainText('Mar 2020');
  await expect(page.locator('iframe')).toHaveAttribute('src', 'https://www.youtube.com/embed/gNjVTMeOS7A');
  await expect(page.getByRole('heading', { name: 'This Project Uses' })).toBeVisible();
  for (const asset of ['/favicon.png', '/manifest.webmanifest', '/assets/logos/logo-square-192.png', '/assets/images/routes/__error/pupper.jpg', '/offline.html']) {
    expect((await request.get(asset)).status()).toBe(200);
  }
});

test('unknown posts projects URLs and explicit 404 return real HTTP 404 with preserved view', async ({ page }) => {
  for (const path of ['/blog/posts/missing', '/projects/entries/missing', '/missing', '/404', '/previews']) {
    const response = await page.goto(path);
    expect(response?.status()).toBe(404);
    await expect(page.getByText('Hey there, time traveller!', { exact: false })).toBeVisible();
    await expect(page.getByAltText('Sorry looking pupper')).toBeVisible();
  }
});
