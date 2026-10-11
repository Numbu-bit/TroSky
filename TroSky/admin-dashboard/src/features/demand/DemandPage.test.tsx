// Loaded up front: the screen these tests open is lazy.
import './DemandPage'
import './DemandHeatMap'

import { screen, waitFor, within } from '@testing-library/react'

import { ADMIN, renderApp } from '@/test/render'

describe('Demand map', () => {
  it('shows where people searched, by place, journey, day and hour', async () => {
    renderApp('/demand', { as: ADMIN })
    expect(await screen.findByText('Searches in the period')).toBeInTheDocument()
    expect(screen.getByText('Places shown')).toBeInTheDocument()
    expect(screen.getByText('Kept back')).toBeInTheDocument()
    expect(screen.getByText('Busiest pickup stops')).toBeInTheDocument()
    expect(screen.getByText('Busiest journeys')).toBeInTheDocument()
    const grid = screen.getByRole('table', {
      name: 'Demand by day of the week and hour of the day',
    })
    // A header row, then a row a day.
    expect(within(grid).getAllByRole('row')).toHaveLength(8)
  })

  it('shows where searches found no bus, kept in the address', async () => {
    const { user, router } = renderApp('/demand', { as: ADMIN })
    await screen.findByText('Searches in the period')
    await user.click(screen.getByRole('radio', { name: 'Found nothing' }))
    await waitFor(() => expect(router.state.location.search).toContain('type=unmet'))
    expect(await screen.findByText('Found nothing in the period')).toBeInTheDocument()
    expect(screen.getByRole('region', { name: 'Where searches found nothing' })).toBeInTheDocument()
  })

  it('narrows to some days of the week', async () => {
    const { user, router } = renderApp('/demand', { as: ADMIN })
    await screen.findByText('Searches in the period')
    const days = screen.getByRole('toolbar', { name: 'Days of the week' })
    await user.click(within(days).getByRole('button', { name: 'Sat' }))
    await user.click(within(days).getByRole('button', { name: 'Sun' }))
    await waitFor(() => expect(router.state.location.search).toContain('days=sat%2Csun'))
  })
})
