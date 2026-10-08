// Loaded up front: the screens these tests open are lazy, and their first
// load would otherwise eat into the tests' own waiting time.
import './LiveMapPage'

import { screen, waitFor, within } from '@testing-library/react'

import { ADMIN, renderApp } from '@/test/render'

describe('Live map', () => {
  it('lists every bus on the road, SOS first, with a list in place of the map here', async () => {
    renderApp('/live?view=list', { as: ADMIN })
    expect(await screen.findByText(/can’t draw maps/)).toBeInTheDocument()

    const list = await screen.findByRole('table', { name: /Buses on the road/ })
    expect(within(list).getAllByRole('row').slice(1).length).toBeGreaterThanOrEqual(20)
    // The SOS alerts may arrive after the buses: the rows then re-sort.
    await waitFor(() =>
      expect(
        within(screen.getByRole('table', { name: /Buses on the road/ })).getAllByRole('row')[1],
      ).toHaveTextContent('SOS open'),
    )
  })

  it('filters to the buses asked for', async () => {
    const { user } = renderApp('/live?view=list', { as: ADMIN })
    await screen.findByRole('table', { name: /Buses on the road/ })
    await user.click(screen.getByRole('radio', { name: 'Paused' }))

    const list = await screen.findByRole('table', { name: /Buses on the road/ })
    const rows = within(list).getAllByRole('row').slice(1)
    expect(rows.length).toBeGreaterThan(0)
    for (const row of rows) expect(row).toHaveTextContent('Paused')
  })

  it('opens a bus: its route, driver, live position and arrival time', async () => {
    const { user, router } = renderApp('/live?view=list&show=moving', { as: ADMIN })
    const list = await screen.findByRole('table', { name: /Buses on the road/ })
    const moving = within(list)
      .getAllByRole('row')
      .slice(1)
      .find((row) => row.textContent?.includes('On the road'))!
    await user.click(within(moving).getByRole('button'))

    const drawer = await screen.findByRole('dialog')
    expect(router.state.location.search).toContain('trip=')
    expect(await within(drawer).findByText('Driver and vehicle')).toBeInTheDocument()
    expect(await within(drawer).findByText(/km\/h · updated/)).toBeInTheDocument()
    expect(await within(drawer).findByText(/km to go/)).toBeInTheDocument()
    expect(within(drawer).getByRole('link', { name: 'Open trip' })).toHaveAttribute(
      'href',
      expect.stringMatching(/^\/trips\//),
    )
  })
})
