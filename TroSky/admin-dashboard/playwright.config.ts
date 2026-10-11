import { defineConfig, devices } from '@playwright/test'

const PORT = 4180
const CI = Boolean(process.env.CI)

/**
 * End-to-end tests run in demo mode (spec section 8): the demo build is
 * served as it would be deployed, and every request is answered in the
 * browser. Each test starts from the same seeded platform.
 */
export default defineConfig({
  testDir: './e2e',
  fullyParallel: true,
  forbidOnly: CI,
  retries: CI ? 1 : 0,
  workers: CI ? 2 : undefined,
  reporter: CI
    ? [['github'], ['html', { open: 'never' }]]
    : [['list'], ['html', { open: 'never' }]],
  timeout: 90_000,
  expect: { timeout: 15_000 },
  use: {
    baseURL: `http://127.0.0.1:${PORT}`,
    locale: 'en-GH',
    timezoneId: 'Africa/Accra',
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
  },
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'], viewport: { width: 1440, height: 900 } },
    },
  ],
  webServer: {
    command: 'npm run e2e:serve',
    url: `http://127.0.0.1:${PORT}/login`,
    reuseExistingServer: !CI,
    timeout: 240_000,
    stdout: 'ignore',
    stderr: 'pipe',
  },
})
