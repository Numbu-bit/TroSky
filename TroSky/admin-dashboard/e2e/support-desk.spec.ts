import { expect, test } from '@playwright/test'

import { confirm, expectToast, signIn } from './support'

test.beforeEach(async ({ page }) => {
  await signIn(page)
})

test('resolves a complaint with a note, which closes it to changes', async ({ page }) => {
  await page.goto('/complaints?status=open')
  const first = page.getByRole('table', { name: 'Complaints' }).locator('tbody tr').first()
  await first.click()
  await expect(page).toHaveURL(/\/complaints\/[0-9a-f-]{36}$/)
  await expect(page.getByRole('heading', { level: 1 })).toBeVisible()

  await page.getByRole('button', { name: 'Resolve', exact: true }).click()
  await expect(
    page.getByRole('alertdialog').getByRole('button', { name: 'Resolve', exact: true }),
  ).toBeDisabled()
  await confirm(page, 'Resolve', 'Refunded the extra fare and warned the mate.')
  await expectToast(page, 'Complaint resolved.')
  await expect(page.getByText('How it was resolved')).toBeVisible()
  await expect(page.getByText('Refunded the extra fare and warned the mate.')).toBeVisible()
  await expect(page.getByRole('button', { name: 'Resolve', exact: true })).toHaveCount(0)
})

test('suspends an account with a reason, then reactivates it', async ({ page }) => {
  await page.goto('/accounts?role=passenger&status=active')
  const first = page.getByRole('table', { name: 'Accounts' }).locator('tbody tr').first()
  const name = (await first.locator('.font-medium').first().textContent())!.trim()
  await first.click()
  await expect(page.getByRole('heading', { level: 1, name })).toBeVisible()

  await page.getByRole('button', { name: 'Suspend', exact: true }).click()
  await expect(page.getByRole('alertdialog')).toContainText(
    /signs them out of every device straight away/,
  )
  await confirm(page, 'Suspend account', 'Fare dispute under review.')
  await expectToast(page, /is suspended and signed out everywhere/)
  await expect(page.getByText('Suspended: “Fare dispute under review.”')).toBeVisible()

  await page.getByRole('button', { name: 'Reactivate', exact: true }).click()
  await confirm(page, 'Reactivate')
  await expectToast(page, /can use TroSky again/)
  await expect(page.getByRole('button', { name: 'Suspend', exact: true })).toBeVisible()
})
