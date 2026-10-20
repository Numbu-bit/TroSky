import { expect, type Page } from '@playwright/test'

import { confirm, expectToast, signIn, test } from './support'

/** Open the driver who has waited longest; their name heads the review. */
async function openFirstDriver(page: Page) {
  await page.goto('/approvals')
  const first = page.getByRole('list', { name: 'Drivers waiting' }).getByRole('link').first()
  const name = (await first.locator('.font-medium').first().textContent())!.trim()
  await first.click()
  await expect(page.getByRole('heading', { level: 2, name })).toBeVisible()
  return name
}

test.beforeEach(async ({ page }) => {
  await signIn(page)
})

test('approves a driver once every check is ticked', async ({ page }) => {
  const name = await openFirstDriver(page)
  const approve = page.getByRole('button', { name: 'Approve driver' })
  await expect(approve).toBeDisabled()

  const checks = page.getByRole('group', { name: /Checks/ }).getByRole('checkbox')
  for (const check of await checks.all()) await check.check()
  await expect(approve).toBeEnabled()
  await approve.click()
  await expect(page.getByRole('alertdialog')).toContainText(`Approve ${name}?`)
  await confirm(page, 'Approve driver')

  await expectToast(page, `${name} approved.`)
  // The next application opens, with nothing ticked.
  await expect(page.getByRole('heading', { level: 2 })).not.toHaveText(name)
  await expect(page.getByRole('button', { name: 'Approve driver' })).toBeDisabled()
})

test('rejects a driver only with a reason', async ({ page }) => {
  const name = await openFirstDriver(page)
  await page.getByRole('button', { name: 'Reject', exact: true }).click()
  const dialog = page.getByRole('alertdialog')
  await expect(dialog.getByRole('button', { name: 'Reject', exact: true })).toBeDisabled()
  await confirm(page, 'Reject', 'The licence photo is too blurred to read.')
  await expectToast(page, `${name} rejected.`)
})
