// Loaded up front: the screen these tests open is lazy.
import './UserGrowthPage'

import { screen, waitFor, within } from '@testing-library/react'

import { ADMIN, renderApp } from '@/test/render'

describe('User growth', () => {
  it('shows sign-ups, activity, and the funnel from search to boarding', async () => {
    renderApp('/user-growth', { as: ADMIN })
    expect(await screen.findByText('New users')).toBeInTheDocument()
    expect(screen.getByText('Active in the last 30 days')).toBeInTheDocument()
    expect(screen.getByText('Booked within a week of joining')).toBeInTheDocument()

    const funnel = await screen.findByRole('list', { name: 'Funnel stages' })
    const stages = within(funnel).getAllByRole('listitem')
    expect(stages.map((stage) => stage.firstElementChild?.firstElementChild?.textContent)).toEqual([
      'Searched',
      'Reserved a seat',
      'Paid',
      'Boarded',
    ])
    // Each stage is no bigger than the one before it (after the searches).
    const counts = stages
      .slice(1)
      .map((stage) =>
        Number(/^[\d,]+/.exec(stage.querySelector('.figure')!.textContent!)![0].replace(/,/g, '')),
      )
    expect(counts).toEqual([...counts].sort((a, b) => b - a))
  })

  it('shows who came back, week by week, also as a table', async () => {
    const { user } = renderApp('/user-growth', { as: ADMIN })
    const cohorts = await screen.findByRole('table', {
      name: 'Retention by the week people joined',
    })
    expect(within(cohorts).getAllByRole('row').length).toBeGreaterThan(1)
    await user.click(screen.getAllByRole('button', { name: 'Show as a table' })[0]!)
    expect(screen.getAllByRole('button', { name: 'Show as a chart' })).toHaveLength(1)
  })

  it('changes the period, kept in the address', async () => {
    const { user, router } = renderApp('/user-growth', { as: ADMIN })
    await screen.findByText('New users')
    await user.click(screen.getByRole('radio', { name: '90 days' }))
    await waitFor(() => expect(router.state.location.search).toBe('?days=90'))
    expect(await screen.findByText(/^Last 90 days/)).toBeInTheDocument()
  })
})
