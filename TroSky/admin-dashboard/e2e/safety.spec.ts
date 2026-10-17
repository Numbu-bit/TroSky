import { expect } from '@playwright/test'

import { expectToast, signIn, test } from './support'

test('acknowledges an SOS from the banner, then resolves it with a note', async ({ page }) => {
  await signIn(page)
  const banner = page.getByText('SOS not yet acknowledged')
  await expect(banner).toBeVisible()
  await page.getByRole('link', { name: 'Open SOS' }).click()
  const drawer = page.getByRole('dialog')
  await expect(drawer).toContainText(/SOS from/)
  // Who raised it, and the national numbers, one tap away.
  await expect(drawer.getByRole('link', { name: /Call raised by/ })).toHaveAttribute(
    'href',
    /^tel:\+233/,
  )
  await expect(drawer.getByRole('link', { name: /Ghana Police Service \(191\)/ })).toBeVisible()

  await drawer.getByRole('button', { name: 'Acknowledge' }).click()
  await expectToast(page, /help is on the way/)
  await expect(banner).toBeHidden()
  await expect(drawer).toContainText('Acknowledged')

  await drawer.getByRole('button', { name: 'Resolve' }).click()
  const dialog = page.getByRole('alertdialog')
  await expect(dialog.getByRole('button', { name: 'Resolve' })).toBeDisabled()
  await dialog.getByLabel('Resolution note').fill('Passenger safe; the driver was warned.')
  await dialog.getByRole('button', { name: 'Resolve' }).click()
  await expectToast(page, 'SOS resolved.')
  await expect(drawer).toContainText('Passenger safe; the driver was warned.')
})
