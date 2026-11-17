import { defineConfig } from '@playwright/test';

const existingServerUrl = process.env.PLAYWRIGHT_BASE_URL;

export default defineConfig({
  testDir: './tests',
  reporter: 'list',
  use: { baseURL: existingServerUrl ?? 'http://127.0.0.1:4179', browserName: 'chromium', channel: 'chrome' },
  webServer: existingServerUrl ? undefined : {
    command: 'node build',
    url: 'http://127.0.0.1:4179',
    env: { HOST: '127.0.0.1', PORT: '4179', ORIGIN: 'http://127.0.0.1:4179' },
    reuseExistingServer: false,
    stdout: 'pipe',
    stderr: 'pipe'
  }
});
