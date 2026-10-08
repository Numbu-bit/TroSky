// Loaded up front: the screens these tests open are lazy.
import './AlertsPage'
import '@/app/layout/SearchDialog'

import { screen, waitFor, within } from '@testing-library/react'

import { getDb } from '@/api/demo/db'
import { ADMIN, renderApp, staffWith } from '@/test/render'

const RANK = { Critical: 0, High: 1, Medium: 2, Low: 3 } as const

const alertItems = () => within(screen.getByRole('list', { name: 'Alerts' })).getAllByRole('link')

describe('Alerts', () => {
  it('lists what needs attention, most severe first', async () => {
    renderApp('/alerts', { as: ADMIN })
    await screen.findByRole('list', { name: 'Alerts' })
    const ranks = alertItems().map(
      (item) =>
        RANK[/^(Critical|High|Medium|Low)/.exec(item.textContent!)![1] as keyof typeof RANK],
    )
    expect(ranks[0]).toBe(0)
    expect(ranks).toEqual([...ranks].sort((a, b) => a - b))
  })

  it('filters by kind, kept in the address, each opening where it is dealt with', async () => {
    const { user, router } = renderApp('/alerts', { as: ADMIN })
    await screen.findByRole('list', { name: 'Alerts' })
    const kinds = screen.getByRole('toolbar', { name: 'Kind of alert' })
    await user.click(within(kinds).getByRole('button', { name: /^Complaints overdue/ }))
    await waitFor(() => expect(router.state.location.search).toBe('?type=complaint_overdue'))
    await waitFor(() => {
      const items = alertItems()
      expect(items.length).toBeGreaterThan(0)
      for (const item of items) {
        expect(item).toHaveTextContent('Complaints overdue')
        expect(item.getAttribute('href')).toMatch(/^\/complaints\/[\w-]+$/)
      }
    })
  })

  it('shows only the kinds an admin deals with', async () => {
    renderApp('/alerts', { as: staffWith('complaints:manage') })
    await screen.findByRole('list', { name: 'Alerts' })
    const kinds = screen.getByRole('toolbar', { name: 'Kind of alert' })
    expect(within(kinds).getAllByRole('button')).toHaveLength(1)
    for (const item of alertItems()) expect(item).toHaveTextContent('Complaints overdue')
  })
})

describe('Global search', () => {
  it('finds a vehicle by its plate and opens it', async () => {
    const vehicle = getDb().vehicles[0]!
    const { user, router } = renderApp('/overview', { as: ADMIN })
    await user.click(await screen.findByRole('button', { name: 'Search' }))
    const dialog = await screen.findByRole('dialog', { name: 'Search' })
    const input = within(dialog).getByRole('combobox', { name: 'Search' })
    await user.type(input, vehicle.registration_number.slice(0, 1))
    expect(within(dialog).getByText('Type at least 2 characters.')).toBeInTheDocument()
    await user.type(input, vehicle.registration_number.slice(1))
    const group = await within(dialog).findByRole('group', { name: 'Vehicles' })
    await user.click(
      within(group).getByRole('option', { name: new RegExp(vehicle.registration_number) }),
    )
    await waitFor(() =>
      expect(router.state.location.pathname).toBe(`/fleet/vehicles/${vehicle.id}`),
    )
    expect(
      await screen.findByRole('heading', { name: vehicle.registration_number }),
    ).toBeInTheDocument()
  })

  it('searches only what the admin may see', async () => {
    const booking = getDb().bookings[0]!
    const { user } = renderApp('/complaints', { as: staffWith('bookings:view_any') })
    await user.click(await screen.findByRole('button', { name: 'Search' }))
    const dialog = await screen.findByRole('dialog', { name: 'Search' })
    await user.type(within(dialog).getByRole('combobox', { name: 'Search' }), booking.reference)
    expect(await within(dialog).findByRole('group', { name: 'Bookings' })).toBeInTheDocument()
    expect(within(dialog).queryByRole('group', { name: 'Accounts' })).toBeNull()
    expect(within(dialog).queryByRole('group', { name: 'Vehicles' })).toBeNull()
  })
})
