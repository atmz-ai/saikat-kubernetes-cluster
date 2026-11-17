import { expect, test } from '@playwright/test';

test('SSR metadata content and complete post list are available without JavaScript', async ({ browser }) => {
  const context = await browser.newContext({ javaScriptEnabled: false, viewport: { width: 390, height: 844 } });
  const page = await context.newPage();
  await page.goto('/blog');
  await expect(page).toHaveTitle("Saikat's Blog");
  await expect(page.getByRole('list', { name: 'Blog posts' }).getByRole('listitem')).toHaveCount(30);
  await expect(page.getByRole('textbox', { name: 'Search blog posts' })).toBeDisabled();
  await expect(page.getByRole('button', { name: 'Toggle navigation menu' })).toBeDisabled();
  await expect(page.locator('.no-script-links').getByRole('link', { name: 'Blog', exact: true })).toBeVisible();
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
  await expect(navigation).not.toHaveClass(/initializing/);
  await expect(navigation).toBeVisible();
  await page.keyboard.press('Escape');
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

test('all screens follow device appearance without JavaScript and retain readable text', async ({ browser }) => {
  const context = await browser.newContext({ javaScriptEnabled: false });
  const page = await context.newPage();
  for (const colorScheme of ['light', 'dark'] as const) {
    await page.emulateMedia({ colorScheme });
    for (const path of ['/', '/blog', '/projects', '/blog/posts/react-hooks-usestate', '/projects/entries/the-knotty-tales', '/missing']) {
      await page.goto(path);
      const appearance = await page.evaluate(() => {
        const styles = getComputedStyle(document.body);
        const colors = [styles.backgroundColor, styles.color, styles.getPropertyValue('--text-secondary'), styles.getPropertyValue('--accent')].map((color) => {
          const element = document.createElement('span');
          element.style.color = color.trim();
          document.body.append(element);
          const channels = getComputedStyle(element).color.match(/[\d.]+/g)!.slice(0, 3).map(Number);
          element.remove();
          return channels.map((channel) => channel / 255).map((channel) => channel <= 0.04045 ? channel / 12.92 : ((channel + 0.055) / 1.055) ** 2.4).reduce((total, channel, index) => total + channel * [0.2126, 0.7152, 0.0722][index], 0);
        });
        const background = colors[0];
        return { background, contrast: colors.slice(1).map((color) => (Math.max(background, color) + 0.05) / (Math.min(background, color) + 0.05)), scheme: getComputedStyle(document.documentElement).colorScheme };
      });
      expect(appearance.scheme).toBe('light dark');
      if (colorScheme === 'dark') expect(appearance.background).toBeLessThan(0.03);
      else expect(appearance.background).toBeGreaterThan(0.85);
      for (const contrast of appearance.contrast) expect(contrast).toBeGreaterThanOrEqual(4.5);
    }
  }
  await context.close();
});

test('device appearance changes live and code blocks remain legible in both themes', async ({ page }) => {
  await page.goto('/blog/posts/react-hooks-usestate');
  await page.emulateMedia({ colorScheme: 'light' });
  const lightBackground = await page.locator('body').evaluate((element) => getComputedStyle(element).backgroundColor);
  const lightCodeBackground = await page.locator('pre').first().evaluate((element) => getComputedStyle(element).backgroundColor);
  await page.emulateMedia({ colorScheme: 'dark' });
  await expect(page.locator('body')).not.toHaveCSS('background-color', lightBackground);
  await expect(page.locator('pre').first()).not.toHaveCSS('background-color', lightCodeBackground);
  await expect(page.locator('article')).toContainText('React Hooks: useState');
  await page.emulateMedia({ colorScheme: 'light' });
  await expect(page.locator('body')).toHaveCSS('background-color', lightBackground);
});

test('mobile layouts contain cards media and code without horizontal page overflow', async ({ page }) => {
  for (const width of [320, 390, 768, 1280]) {
    await page.setViewportSize({ width, height: 844 });
    for (const path of ['/', '/blog', '/projects', '/blog/posts/git-branching', '/projects/entries/the-knotty-tales', '/missing']) {
      await page.goto(path);
      const geometry = await page.evaluate(() => ({ viewport: document.documentElement.clientWidth, content: document.documentElement.scrollWidth }));
      expect(geometry.content, `${width}px ${path}`).toBeLessThanOrEqual(geometry.viewport);
    }
  }
});

test('search has a useful empty state and clearing restores every article', async ({ page }) => {
  await page.goto('/blog');
  const search = page.getByRole('textbox', { name: 'Search blog posts' });
  await expect(search).toBeEnabled();
  await search.fill('uniquely-nonexistent-term');
  await expect(page.getByRole('heading', { name: 'No matching articles.' })).toBeVisible();
  await expect(page.getByRole('status')).toHaveText('0 articles found');
  await page.getByRole('button', { name: 'Clear search' }).click();
  await expect(search).toHaveValue('');
  await expect(page.getByRole('list', { name: 'Blog posts' }).getByRole('listitem')).toHaveCount(30);
});

test('navigation identifies the current section and the keyboard skip link reaches content', async ({ page }) => {
  await page.goto('/');
  await page.keyboard.press('Tab');
  const skipLink = page.getByRole('link', { name: 'Skip to content' });
  await expect(skipLink).toBeFocused();
  await expect(skipLink).toBeVisible();
  await page.keyboard.press('Enter');
  await expect(page.locator('#main-content')).toBeFocused();
  await page.goto('/blog/posts/react-hooks-usestate');
  await expect(page.getByRole('navigation', { name: 'Main navigation' }).getByRole('link', { name: 'Blog', exact: true })).toHaveAttribute('aria-current', 'page');
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await expect(page.locator('.site-navigation a').first()).toHaveCSS('transition-duration', '0s');
  await page.goto('/blog-not-a-route');
  await expect(page.locator('.site-navigation [aria-current]')).toHaveCount(0);
});

test('wide pages fill the viewport while reading columns remain centered and readable', async ({ page }) => {
  await page.setViewportSize({ width: 1920, height: 1080 });
  for (const path of ['/', '/blog', '/projects']) {
    await page.goto(path);
    const geometry = await page.evaluate(() => ({
      viewport: document.documentElement.clientWidth,
      sections: ['.header-inner', '.page-shell', '.site-footer'].map((selector) => {
        const bounds = document.querySelector(selector)!.getBoundingClientRect();
        return { left: bounds.left, width: bounds.width };
      })
    }));
    for (const section of geometry.sections) {
      expect(section.left, path).toBeCloseTo(0, 0);
      expect(section.width, path).toBeCloseTo(geometry.viewport, 0);
    }
  }
  await page.goto('/blog/posts/react-hooks-usestate');
  const readingGeometry = await page.locator('.reading-shell').evaluate((element) => {
    const bounds = element.getBoundingClientRect();
    return { width: bounds.width, left: bounds.left, right: document.documentElement.clientWidth - bounds.right };
  });
  expect(readingGeometry.width).toBeLessThanOrEqual(840);
  expect(readingGeometry.left).toBeGreaterThan(0);
  expect(readingGeometry.left).toBeCloseTo(readingGeometry.right, 0);
});

test('short pages keep the footer at the viewport bottom without adding scroll', async ({ page }) => {
  await page.setViewportSize({ width: 1440, height: 1600 });
  await page.goto('/missing');
  const geometry = await page.evaluate(() => ({
    viewport: innerHeight,
    document: document.documentElement.scrollHeight,
    footerBottom: document.querySelector('footer')!.getBoundingClientRect().bottom
  }));
  expect(geometry.footerBottom).toBeCloseTo(geometry.viewport, 0);
  expect(geometry.document).toBeLessThanOrEqual(geometry.viewport);
});
