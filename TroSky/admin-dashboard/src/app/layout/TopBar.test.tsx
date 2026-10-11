// Loaded up front: the screens these tests open are lazy, and their first
// load would otherwise eat into the tests' own waiting time.
import '@/features/overview/OverviewPage'

import { screen, within } from '@testing-library/react'

import { ADMIN, renderApp, STAFF } from '@/test/render'

describe('the top bar', () => {
  it('lists what is waiting for the admin, each opening its queue', async () => {
    const { user } = renderApp('/overview', { as: ADMIN })
    const bell = await screen.findByRole('button', { name: /items waiting for you/ })
    await user.click(bell)

    // The menu, not the Overview's own tiles with the same names.
    const menu = await screen.findByRole('dialog')
    const sos = await within(menu).findByRole('link', { name: /SOS alerts not yet acknowledged/ })
    expect(sos).toHaveAttribute('href', '/safety?status=active')
    expect(await within(sos).findByText('1')).toBeInTheDocument()
    expect(within(menu).getByRole('link', { name: /Approved payouts to send/ })).toBeInTheDocument()
  })

  it('shows staff only their own queues', async () => {
    const { user } = renderApp('/overview', { as: STAFF })
    await user.click(await screen.findByRole('button', { name: /waiting for you/ }))
    const menu = await screen.findByRole('dialog')
    expect(
      await within(menu).findByRole('link', { name: /Complaints open or in review/ }),
    ).toBeInTheDocument()
    expect(within(menu).queryByRole('link', { name: /Payouts awaiting/ })).not.toBeInTheDocument()
  })

  it('says how live data arrives, and saves data on request', async () => {
    const { user } = renderApp('/overview', { as: ADMIN })
    const indicator = await screen.findByRole('button', { name: /Live updates: Every 8 s/ })
    await user.click(indicator)
    await user.click(await screen.findByRole('switch', { name: /Data saver/ }))
    expect(
      await screen.findByRole('button', { name: /Live updates: Every 30 s/ }),
    ).toBeInTheDocument()
  })
})
