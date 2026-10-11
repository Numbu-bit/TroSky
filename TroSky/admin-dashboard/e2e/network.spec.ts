import { expect } from '@playwright/test'

import { signIn, test } from './support'

test('won’t retire a route that trips still run on, and says why', async ({ page }) => {
  await signIn(page)
  await page.goto('/network')
  const first = page.getByRole('table', { name: 'Routes' }).getByRole('link').first()
  const name = (await first.textContent())!.trim()
  await first.click()
  await expect(page.getByRole('heading', { level: 1, name })).toBeVisible()

  await page.getByRole('button', { name: 'Retire route' }).click()
  const dialog = page.getByRole('alertdialog')
  await dialog.getByRole('button', { name: 'Retire route' }).click()
  // The refusal shows in the dialog, which stays open; the route stays active.
  await expect(dialog).toContainText(/still scheduled or under way on this route/)
  await dialog.getByRole('button', { name: 'Cancel' }).click()
  await expect(page.getByRole('button', { name: 'Retire route' })).toBeVisible()
})
