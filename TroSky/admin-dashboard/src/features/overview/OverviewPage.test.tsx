// Loaded up front: the screens these tests open are lazy, and their first
// load would otherwise eat into the tests' own waiting time.
import './OverviewPage'

import { screen, waitFor, within } from '@testing-library/react'
import { http, HttpResponse } from 'msw'

import { ADMIN, renderApp, STAFF } from '@/test/render'
import { server } from '@/test/server'

function tile(name: RegExp | string) {
  return screen.getByRole('link', { name })
}

describe('Overview', () => {
  it('shows what is happening now, each count opening its screen', async () => {
    renderApp('/overview', { as: ADMIN })

    expect(await screen.findByRole('heading', { name: 'Overview' })).toBeInTheDocument()
    await waitFor(() => expect(tile(/Buses on the road/)).toHaveTextContent(/\d+/))
    expect(tile(/Buses on the road/)).toHaveAttribute('href', '/live')
    await waitFor(() => expect(tile(/Drivers waiting for approval/)).toHaveTextContent('6'))
    expect(tile(/Vehicles waiting for approval/)).toHaveTextContent('4')
    expect(tile(/SOS alerts not yet acknowledged/)).toHaveTextContent('1')
    expect(tile(/Payouts awaiting a decision/)).toHaveAttribute('href', '/payouts?status=pending')
  })

  it('shows the period’s figures, labelled with their period', async () => {
    const { user, router } = renderApp('/overview', { as: ADMIN })

    const paid = await screen.findByRole('button', { name: /^Paid bookings/ })
    expect(paid).toHaveTextContent('Last 30 days')
    expect(paid).toHaveTextContent(/vs previous period/)
    expect(screen.getByRole('button', { name: /^Booking payments/ })).toHaveTextContent('GH₵')
    expect(screen.getByText('All time')).toBeInTheDocument()

    await user.click(screen.getByRole('radio', { name: '7 days' }))
    await waitFor(() => expect(router.state.location.search).toContain('days=7'))
    expect(await screen.findAllByText('Last 7 days')).not.toHaveLength(0)
  })

  it('charts the chosen figure, as a table on request', async () => {
    const { user } = renderApp('/overview?days=7', { as: ADMIN })
    await user.click(await screen.findByRole('button', { name: /^Completed trips/ }))
    expect(await screen.findByText('Completed trips per day')).toBeInTheDocument()

    await user.click(screen.getByRole('button', { name: 'Show as a table' }))
    const table = screen.getByRole('table', { name: 'Completed trips per day' })
    // A header row and one row per day.
    expect(within(table).getAllByRole('row')).toHaveLength(8)
  })

  it('lists what needs attention, SOS first', async () => {
    renderApp('/overview', { as: ADMIN })
    const region = await screen.findByRole('region', { name: 'Needs attention' })
    const items = await within(region).findAllByRole('listitem')
    const first = within(items[0]!).getByRole('link')
    expect(first).toHaveTextContent(/SOS from/)
    expect(first.getAttribute('href')).toMatch(/^\/safety\?status=open&alert=/)
  })

  it('keeps the rest of the page when the figures fail', async () => {
    server.use(
      http.get('*/api/v1/admin/reports/overview', () =>
        HttpResponse.json(
          { error: { code: 'BOOM', message: 'Reports are down.', details: {}, request_id: 'x' } },
          { status: 500 },
        ),
      ),
    )
    renderApp('/overview', { as: ADMIN })
    expect(await screen.findByText('Reports are down.')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Try again' })).toBeInTheDocument()
    expect(tile(/Buses on the road/)).toBeInTheDocument()
  })

  it('shows staff only the counts their permissions open', async () => {
    renderApp('/overview', { as: STAFF })
    expect(
      await screen.findByRole('link', { name: /Complaints open or in review/ }),
    ).toBeInTheDocument()
    expect(
      screen.getByRole('link', { name: /SOS alerts not yet acknowledged/ }),
    ).toBeInTheDocument()
    expect(screen.queryByRole('link', { name: /Payouts awaiting/ })).not.toBeInTheDocument()
    expect(screen.queryByRole('link', { name: /Buses on the road/ })).not.toBeInTheDocument()
  })
})
