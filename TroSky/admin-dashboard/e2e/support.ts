import AxeBuilder from '@axe-core/playwright'
import { test as base, expect, type Page } from '@playwright/test'

/**
 * The demo platform is built from the browser's clock (which trips are on the
 * road, recent incidents, report periods), so screens differed with the hour a
 * test ran. Every page's clock starts at this instant instead, the same as the
 * unit tests' (src/test/setup.ts), and runs on from there.
 */
export const TEST_NOW = new Date('2026-10-11T15:20:00Z')

/** Playwright's ``test``, with each page's clock starting at ``TEST_NOW``. */
export const test = base.extend({
  // (Playwright calls this argument "use"; renamed so React's hook rules
  // don't mistake it for React's use().)
  page: async ({ page }, provide) => {
    await page.clock.install({ time: TEST_NOW })
    await provide(page)
  },
})

/** The demo admins (src/api/demo/accounts.ts), all with the same password. */
export const PASSWORD = 'TroSky-demo-2026'
export const ACCOUNTS = {
  superAdmin: 'abena.owusu@trosky.test',
  admin: 'kwame.mensah@trosky.test',
  /** Staff: bookings, complaints, reports and SOS only. */
  staff: 'esi.quaye@trosky.test',
} as const

/**
 * Sign in through the form. Later page loads keep the session (its refresh
 * token is in sessionStorage) and start again from the same seeded data.
 */
export async function signIn(page: Page, who: keyof typeof ACCOUNTS = 'admin') {
  await page.goto('/login')
  await page.getByLabel('Phone number or email').fill(ACCOUNTS[who])
  await page.getByLabel('Password', { exact: true }).fill(PASSWORD)
  await page.getByRole('button', { name: 'Sign in' }).click()
  await expect(page).toHaveURL(/\/overview$/)
}

/**
 * Go to ``path`` inside the app, as a link would: no reload, so the demo
 * data isn't built again (it takes a second or two of the page's time).
 */
export async function navigate(page: Page, path: string) {
  await page.evaluate((to) => {
    window.history.pushState({}, '', to)
    window.dispatchEvent(new PopStateEvent('popstate'))
  }, path)
}

/** In the open confirmation: give the reason it asks for, then confirm. */
export async function confirm(page: Page, button: string | RegExp, reason?: string) {
  const dialog = page.getByRole('alertdialog')
  if (reason !== undefined) await dialog.getByRole('textbox').first().fill(reason)
  await dialog.getByRole('button', { name: button, exact: typeof button === 'string' }).click()
  await expect(dialog).toBeHidden()
}

/** A toast's text, once it shows. */
export async function expectToast(page: Page, text: string | RegExp) {
  await expect(page.locator('[data-sonner-toast]').filter({ hasText: text }).first()).toBeVisible()
}

/** The test day in Ghana (UTC+0 all year, see ``TEST_NOW``), shifted by ``days``. */
export function accraDate(days = 0): string {
  return new Date(TEST_NOW.getTime() + days * 86_400_000).toISOString().slice(0, 10)
}

/**
 * Let one-off animations (a dialog fading in) finish, so colours are
 * measured as they end up. Endless ones (a pulsing SOS icon) are left.
 */
async function animationsDone(page: Page) {
  await page.evaluate(() =>
    Promise.all(
      document
        .getAnimations()
        .filter((animation) => animation.effect?.getTiming().iterations !== Infinity)
        .map((animation) => animation.finished.catch(() => undefined)),
    ),
  )
}

const WCAG = ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22aa']
const MARKERS = '.maplibregl-marker'

/**
 * axe on the page as it is now (WCAG 2.2 A and AA rules): no serious or
 * critical violations (acceptance criterion 8). ``within`` limits it to an
 * open dialog: the page behind it is inert, and checked on its own.
 */
export async function expectAccessible(page: Page, what: string, within?: string) {
  await animationsDone(page)
  const scoped = (builder: AxeBuilder) => (within ? builder.include(within) : builder)
  const runs = [await scoped(new AxeBuilder({ page }).withTags(WCAG).exclude(MARKERS)).analyze()]
  // Map markers are checked on their own, all but their size: buses close
  // together on a map overlap, and WCAG 2.5.8 allows that when the same
  // thing can be done elsewhere on the page (the live map lists every bus
  // beside it, with full-size targets).
  if (!within && (await page.locator(MARKERS).count()) > 0) {
    runs.push(
      await new AxeBuilder({ page })
        .withTags(WCAG)
        .include(MARKERS)
        .disableRules(['target-size'])
        .analyze(),
    )
  }
  const serious = runs
    .flatMap((results) => results.violations)
    .filter((violation) => violation.impact === 'serious' || violation.impact === 'critical')
    .map((violation) => {
      const nodes = violation.nodes.slice(0, 4).map((node) => {
        // Contrast failures carry the colours and ratio measured.
        const data = node.any[0]?.data as
          { fgColor?: string; bgColor?: string; contrastRatio?: number } | undefined
        const colours = data?.contrastRatio
          ? ` [${data.fgColor} on ${data.bgColor}: ${data.contrastRatio}:1]`
          : ''
        return `${node.html.slice(0, 160)}${colours}`
      })
      const list = nodes.map((node) => `\n    ${node}`).join('')
      return `${violation.id} (${violation.impact}): ${violation.help}${list}`
    })
  expect(serious, `axe on ${what}`).toEqual([])
}
