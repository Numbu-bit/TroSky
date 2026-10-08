// Loaded up front: the screen these tests open is lazy.
import './DriverPerformanceScreen'

import { screen, waitFor, within } from '@testing-library/react'

import { ADMIN, renderApp } from '@/test/render'

const rows = () =>
  within(screen.getByRole('table', { name: 'Driver performance' }))
    .getAllByRole('row')
    .slice(1)

describe('Driver performance', () => {
  it('ranks drivers worst first', async () => {
    renderApp('/driver-performance', { as: ADMIN })
    await screen.findByRole('table', { name: 'Driver performance' })
    const scores = rows()
      .map((row) => Number(within(row).getAllByRole('cell')[1]!.textContent))
      .filter((score) => !Number.isNaN(score))
    expect(scores.length).toBeGreaterThan(1)
    expect(scores).toEqual([...scores].sort((a, b) => a - b))
  })

  it('points out the drivers at risk', async () => {
    const { user, router } = renderApp('/driver-performance', { as: ADMIN })
    const warning = await screen.findByText(/drivers? (is|are) at risk in this period/)
    await user.click(
      within(warning.closest('[role="status"]')!).getByRole('button', { name: 'Show them' }),
    )
    await waitFor(() => expect(router.state.location.search).toContain('risk=yes'))
    await waitFor(() => {
      const shown = rows()
      expect(shown.length).toBeGreaterThan(0)
      for (const row of shown) expect(row).toHaveTextContent('At risk')
    })
  })

  it('opens a driver’s score, what it is made of, and their reviews', async () => {
    const { user } = renderApp('/driver-performance', { as: ADMIN })
    await screen.findByRole('table', { name: 'Driver performance' })
    const link = within(rows()[0]!).getAllByRole('link')[0]!
    const name = link.textContent ?? ''
    await user.click(link)
    expect(await screen.findByRole('heading', { name })).toBeInTheDocument()
    const parts = screen.getByRole('list', { name: 'What the score is made of' })
    expect(within(parts).getAllByRole('listitem')).toHaveLength(5)
    expect(within(parts).getByText('Rating')).toBeInTheDocument()
    expect(screen.getByRole('region', { name: 'Latest reviews' })).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'Driver profile' })).toHaveAttribute(
      'href',
      expect.stringMatching(/^\/fleet\/drivers\//),
    )
  })

  it('says so when the driver doesn’t exist', async () => {
    renderApp('/driver-performance/00000000-0000-4000-8000-000000000000', { as: ADMIN })
    expect(await screen.findByText('Driver not found')).toBeInTheDocument()
  })
})
