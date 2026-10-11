import { expect, type Page } from '@playwright/test'

import { expectAccessible, navigate, signIn, test } from './support'

/** The page has drawn its content: a heading, and no requests in flight. */
async function settled(page: Page) {
  await expect(page.getByRole('heading', { level: 1 }).first()).toBeVisible({ timeout: 30_000 })
  await page.waitForLoadState('networkidle')
}

/** Pages that finish drawing after their data arrives: wait for that too. */
const READY: Record<string, (page: Page) => Promise<void>> = {
  // The map loads, places the buses, then enables "Show all buses".
  '/live': (page) =>
    expect(page.getByRole('button', { name: 'Show all buses' })).toBeEnabled({ timeout: 30_000 }),
  // "Excel" and "PDF" are disabled until the report arrives, then fade in.
  '/reports': (page) =>
    expect(page.getByRole('button', { name: 'PDF', exact: true })).toBeEnabled({ timeout: 30_000 }),
}

/** Open ``path`` inside the app and wait for it to settle. */
async function open(page: Page, path: string) {
  await navigate(page, path)
  await settled(page)
  await READY[path]?.(page)
}

/** Open the first row of a table (a record page or a drawer). */
async function openFirstRow(page: Page, caption: string) {
  await page.getByRole('table', { name: caption }).locator('tbody tr').first().click()
}

// Every screen in the menu (src/app/screens.ts) and its tabs, as a super
// admin: one test each, so they run side by side and a failure names it.
const SCREENS = [
  '/overview',
  '/live',
  '/alerts',
  '/safety',
  '/trips',
  '/dispatch',
  '/network',
  '/network/stops',
  '/approvals',
  '/approvals?queue=vehicles',
  '/fleet/vehicles',
  '/fleet/drivers',
  '/fleet/fleets',
  '/bookings',
  '/bookings/refunds',
  '/bookings/cancellations',
  '/payouts',
  '/revenue',
  '/wallets',
  '/complaints',
  '/accounts',
  '/driver-ratings',
  '/driver-performance',
  '/user-growth',
  '/demand',
  '/reports',
  '/fraud',
  '/fraud/rules',
  '/team',
  '/audit-log',
  '/settings',
  '/me/sessions',
  '/no-such-page',
]

test('the sign-in page', async ({ page }) => {
  await page.goto('/login')
  await expect(page.getByRole('heading', { name: 'Sign in' })).toBeVisible()
  await expectAccessible(page, '/login')
})

test.describe('every screen', () => {
  for (const path of SCREENS) {
    test(path, async ({ page }) => {
      await signIn(page, 'superAdmin')
      await open(page, path)
      await expectAccessible(page, path)
    })
  }
})

// A record page, opened from the first row of its list.
const RECORDS: { what: string; list: string; open: (page: Page) => Promise<void> }[] = [
  { what: 'a trip', list: '/trips?status=all', open: (page) => openFirstRow(page, 'Trips') },
  { what: 'a route', list: '/network', open: (page) => openFirstRow(page, 'Routes') },
  {
    what: 'a driver’s application',
    list: '/approvals',
    open: (page) =>
      page.getByRole('list', { name: 'Drivers waiting' }).getByRole('link').first().click(),
  },
  { what: 'a vehicle', list: '/fleet/vehicles', open: (page) => openFirstRow(page, 'Vehicles') },
  { what: 'a complaint', list: '/complaints', open: (page) => openFirstRow(page, 'Complaints') },
  { what: 'an account', list: '/accounts', open: (page) => openFirstRow(page, 'Accounts') },
  { what: 'a fraud flag', list: '/fraud', open: (page) => openFirstRow(page, 'Fraud flags') },
  {
    what: 'a driver’s performance',
    list: '/driver-performance',
    open: (page) => openFirstRow(page, 'Driver performance'),
  },
]

test.describe('records', () => {
  for (const record of RECORDS) {
    test(record.what, async ({ page }) => {
      await signIn(page, 'superAdmin')
      await open(page, record.list)
      await record.open(page)
      await settled(page)
      await expectAccessible(page, record.what)
    })
  }
})

// Drawers and dialogs: checked within themselves (the page behind is inert).
test.describe('drawers and dialogs', () => {
  test.beforeEach(async ({ page }) => {
    await signIn(page, 'superAdmin')
  })

  test('a booking', async ({ page }) => {
    await open(page, '/bookings')
    await openFirstRow(page, 'Bookings')
    await expect(page.getByRole('dialog')).toBeVisible()
    await page.waitForLoadState('networkidle')
    await expectAccessible(page, 'a booking (drawer)', '[role="dialog"]')
  })

  test('a payout’s confirmation', async ({ page }) => {
    await open(page, '/payouts')
    await openFirstRow(page, 'Payouts')
    await page.getByRole('dialog').getByRole('button', { name: 'Approve payout' }).click()
    await expect(page.getByRole('alertdialog')).toBeVisible()
    await expectAccessible(page, 'a payout’s confirmation', '[role="alertdialog"]')
  })

  test('an audit entry', async ({ page }) => {
    await open(page, '/audit-log')
    await openFirstRow(page, 'Audit log')
    await expect(page.getByRole('dialog')).toBeVisible()
    await page.waitForLoadState('networkidle')
    await expectAccessible(page, 'an audit entry (drawer)', '[role="dialog"]')
  })

  test('an SOS', async ({ page }) => {
    await page.getByRole('link', { name: 'Open SOS' }).click()
    await expect(page.getByRole('dialog')).toBeVisible()
    await page.waitForLoadState('networkidle')
    await expectAccessible(page, 'an SOS (drawer)', '[role="dialog"]')
  })

  test('the global search', async ({ page }) => {
    await page.keyboard.press('Control+k')
    await page.getByRole('combobox', { name: 'Search' }).fill('Ama')
    await expect(page.getByRole('option').first()).toBeVisible()
    await expectAccessible(page, 'the global search', '[role="dialog"]')
  })
})

test.describe('dark mode', () => {
  for (const path of ['/overview', '/live', '/trips', '/revenue', '/fraud', '/settings']) {
    test(path, async ({ page }) => {
      await page.emulateMedia({ colorScheme: 'dark' })
      await signIn(page, 'superAdmin')
      await open(page, path)
      await expectAccessible(page, `${path} (dark)`)
    })
  }
})

test('a page the admin may not open', async ({ page }) => {
  await signIn(page, 'staff')
  await page.goto('/payouts')
  await expect(
    page.getByRole('heading', { name: 'You don’t have access to this page' }),
  ).toBeVisible()
  await expectAccessible(page, 'no access')
})
