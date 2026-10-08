import { expect, test, type Page } from '@playwright/test'

import { accraDate, confirm, expectToast, signIn } from './support'

async function choose(page: Page, label: string, option: RegExp) {
  await page.getByRole('combobox', { name: label }).click()
  await page.getByRole('option', { name: option }).first().click()
}

test.beforeEach(async ({ page }) => {
  await signIn(page)
})

test('makes a trip from the timetable, then puts an approved driver and vehicle on it', async ({
  page,
}) => {
  await page.goto('/trips')
  await page.getByRole('button', { name: 'From timetable' }).click()
  const dialog = page.getByRole('dialog')
  await choose(page, 'Route', /Achimota – Amasaman/)
  await choose(page, 'Timetable entry', /05:45/)
  await dialog.getByLabel('Day').fill(accraDate(1))
  await dialog.getByRole('button', { name: 'Create trip' }).click()

  await expect(page).toHaveURL(/\/trips\/[0-9a-f-]{36}$/)
  await expect(page.getByRole('heading', { level: 1, name: 'Achimota – Amasaman' })).toBeVisible()
  await expect(page.getByText('The timetable', { exact: true })).toBeVisible()
  await expect(page.getByText('No driver on this trip yet.')).toBeVisible()

  // Only approved drivers are offered; the driver is asked to accept.
  await page.getByRole('combobox', { name: 'Choose the driver' }).click()
  await page.getByRole('option').first().click()
  await expect(page.getByRole('alertdialog')).toContainText('is asked to accept the trip')
  await confirm(page, 'Assign driver')
  await expectToast(page, /is on the trip and has been asked to accept it/)
  await expect(page.getByText('Not answered yet')).toBeVisible()

  await page.getByRole('combobox', { name: 'Choose the vehicle' }).click()
  const vehicle = page.getByRole('option').first()
  const plate = (await vehicle.locator('.truncate').first().textContent())!.trim()
  await vehicle.click()
  await confirm(page, 'Assign vehicle')
  await expectToast(page, `${plate} is on the trip.`)
  await expect(page.getByRole('combobox', { name: 'Change the vehicle' })).toContainText(plate)
})

test('cancels a trip, then works through its refunds until none are left', async ({ page }) => {
  // Tomorrow's trips haven't started; open the first with seats paid for.
  const list = `/trips?status=scheduled&date=${accraDate(1)}`
  await page.goto(list)
  const rows = page.getByRole('table', { name: 'Trips' }).locator('tbody tr')
  await expect(rows.first()).toBeVisible()
  const candidates = rows.filter({ hasNotText: /(^|\D)0 \/ \d+/ })
  const tries = Math.min(await candidates.count(), 6)
  let found = false
  for (let index = 0; index < tries && !found; index += 1) {
    if (index > 0) await page.goto(list)
    await candidates.nth(index).getByRole('link').first().click()
    await expect(page).toHaveURL(/\/trips\/[0-9a-f-]{36}$/)
    const seats = page.getByText(/\d+ paid of \d+/)
    await expect(seats).toBeVisible()
    found = !/^0 paid/.test(((await seats.textContent()) ?? '').trim())
  }
  expect(found, 'a trip tomorrow with seats paid for').toBe(true)

  const reason = 'Engine failure at the depot this morning.'
  await page.getByRole('button', { name: 'Cancel trip' }).click()
  await confirm(page, 'Cancel trip', reason)

  const panel = page.getByRole('status').filter({ hasText: 'The trip is cancelled.' })
  await expect(panel).toBeVisible()
  const summary = (await panel.textContent()) ?? ''
  const queued = Number(/(\d+) refunds? \(/.exec(summary)?.[1] ?? '0')
  expect(queued).toBeGreaterThan(0)

  await panel.getByRole('link', { name: 'Review refunds' }).click()
  await expect(page).toHaveURL(/\/bookings\/refunds/)
  const ours = page
    .getByRole('table', { name: 'Refund requests' })
    .getByRole('row')
    .filter({ hasText: reason })
  await expect(ours).toHaveCount(queued)
  for (let left = queued; left > 0; left -= 1) {
    await ours
      .first()
      .getByRole('button', { name: /^Approve the refund/ })
      .click()
    await confirm(page, /^Pay back GH₵/)
    await expectToast(page, /^Paid back GH₵/)
    await expect(ours).toHaveCount(left - 1)
  }
})
