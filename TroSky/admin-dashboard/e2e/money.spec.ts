import { expect } from '@playwright/test'

import { confirm, expectToast, signIn, test } from './support'

test.beforeEach(async ({ page }) => {
  await signIn(page)
})

test('approves a refund, which pays it back', async ({ page }) => {
  await page.goto('/bookings/refunds')
  const table = page.getByRole('table', { name: 'Refund requests' })
  const waiting = page.getByText(/^\d+ records?$/)
  await expect(waiting).toBeVisible()
  const before = Number(/\d+/.exec((await waiting.textContent()) ?? '')![0])

  await table
    .getByRole('button', { name: /^Approve the refund/ })
    .first()
    .click()
  const dialog = page.getByRole('alertdialog')
  // Who gets the money, how, and that it can't be undone.
  await expect(dialog).toContainText(/\+233 24 ••• \d{4}/)
  await expect(dialog).toContainText('This can’t be undone')
  await confirm(page, /^Pay back GH₵/)
  await expectToast(page, /^Paid back GH₵/)
  await expect(waiting).toHaveText(`${before - 1} record${before - 1 === 1 ? '' : 's'}`)
})

test('approves a payout, then marks it failed: the money goes back', async ({ page }) => {
  await page.goto('/payouts')
  const table = page.getByRole('table', { name: 'Payouts' })
  await table.locator('tbody tr').first().click()
  const drawer = page.getByRole('dialog')
  await expect(drawer).toBeVisible()

  await drawer.getByRole('button', { name: 'Approve payout' }).click()
  await expect(page.getByRole('alertdialog')).toContainText('leaves their wallet now')
  await confirm(page, 'Approve payout')
  await expectToast(page, /^Approved\. Send GH₵/)
  await expect(drawer).toContainText(/Approved by you/)

  await drawer.getByRole('button', { name: 'Mark failed' }).click()
  await expect(
    page.getByRole('alertdialog').getByRole('button', { name: 'Mark failed' }),
  ).toBeDisabled()
  await confirm(page, 'Mark failed', 'MTN MoMo rejected the transfer: wallet limit reached.')
  await expectToast(page, /is back in the wallet/)
  await expect(drawer).toContainText(/went back to the wallet/)
})
