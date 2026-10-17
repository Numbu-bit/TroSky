import { expect } from '@playwright/test'

import { ACCOUNTS, PASSWORD, signIn, test } from './support'

test('signs in to the Overview, and out again', async ({ page }) => {
  await page.goto('/')
  await expect(page).toHaveURL(/\/login/)
  await expect(page.getByRole('heading', { name: 'Sign in' })).toBeVisible()
  await expect(page.getByText('DEMO DATA').first()).toBeVisible()

  await page.getByLabel('Phone number or email').fill(ACCOUNTS.admin)
  await page.getByLabel('Password', { exact: true }).fill('not-the-password')
  await page.getByRole('button', { name: 'Sign in' }).click()
  await expect(page.getByRole('alert')).toContainText('The provided credentials are incorrect.')

  await page.getByLabel('Password', { exact: true }).fill(PASSWORD)
  await page.getByRole('button', { name: 'Sign in' }).click()
  await expect(page).toHaveURL(/\/overview$/)
  await expect(page.getByRole('heading', { level: 1, name: 'Overview' })).toBeVisible()
  // The demo badge stays on every page.
  await expect(page.getByText('DEMO DATA').first()).toBeVisible()

  await page.getByRole('button', { name: 'Your account' }).click()
  await page.getByRole('menuitem', { name: 'Sign out' }).click()
  await expect(page).toHaveURL(/\/login$/)
})

test('a reload keeps the admin signed in', async ({ page }) => {
  await signIn(page)
  await page.goto('/payouts')
  await expect(page.getByRole('heading', { level: 1, name: 'Payouts' })).toBeVisible()
})

test('a missing permission hides the module, and its address says so', async ({ page }) => {
  await signIn(page, 'staff')
  for (const shown of ['Complaints', 'Bookings & refunds', 'Safety']) {
    await expect(page.getByRole('link', { name: shown, exact: true }).first()).toBeVisible()
  }
  for (const hidden of ['Payouts', 'Approvals', 'Network', 'Trips', 'Admin team', 'Settings']) {
    await expect(page.getByRole('link', { name: hidden, exact: true })).toHaveCount(0)
  }
  await page.goto('/payouts')
  await expect(
    page.getByRole('heading', { name: 'You don’t have access to this page' }),
  ).toBeVisible()
})
