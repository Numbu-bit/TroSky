// Loaded up front: the screen these tests open is lazy.
import './FleetScreen'

import { screen, waitFor, within } from '@testing-library/react'

import { getDb } from '@/api/demo/db'
import { ADMIN, renderApp, staffWith } from '@/test/render'

const rowsOf = (caption: string) =>
  within(screen.getByRole('table', { name: caption }))
    .getAllByRole('row')
    .slice(1)

describe('Fleet', () => {
  it('lists every vehicle by plate, and filters by what it is doing now', async () => {
    const { user, router } = renderApp('/fleet', { as: ADMIN })
    await screen.findByRole('table', { name: 'Vehicles' })
    expect(router.state.location.pathname).toBe('/fleet/vehicles')
    const plates = rowsOf('Vehicles').map(
      (row) => within(row).getAllByRole('link')[0]!.textContent ?? '',
    )
    expect(plates).toEqual([...plates].sort((a, b) => a.localeCompare(b)))

    await user.click(screen.getByRole('combobox', { name: 'Availability' }))
    await user.click(await screen.findByRole('option', { name: 'On a trip' }))
    await waitFor(() => expect(router.state.location.search).toContain('live=on_trip'))
    await waitFor(() => {
      const rows = rowsOf('Vehicles')
      expect(rows.length).toBeGreaterThan(0)
      for (const row of rows) expect(row).toHaveTextContent('On a trip')
    })
  })

  it('warns about documents running out, and shows those vehicles', async () => {
    const { user, router } = renderApp('/fleet/vehicles', { as: ADMIN })
    const warning = await screen.findByText(/approved vehicles? (has|have) insurance/)
    await user.click(
      within(warning.closest('[role="status"]')!).getByRole('button', { name: 'Show them' }),
    )
    await waitFor(() => {
      expect(router.state.location.search).toContain('expiring=30')
      expect(router.state.location.search).toContain('status=approved')
    })
    await waitFor(() => expect(screen.queryByText(/approved vehicles? (has|have)/)).toBeNull())
  })

  it('opens a vehicle with its documents, fleet and last 30 days', async () => {
    const vehicle = getDb().vehicles.find((candidate) => candidate.status === 'approved')!
    const fleet = getDb().fleets.find((candidate) => candidate.id === vehicle.fleet_id)!
    renderApp(`/fleet/vehicles/${vehicle.id}`, { as: ADMIN })
    expect(
      await screen.findByRole('heading', { name: vehicle.registration_number }),
    ).toBeInTheDocument()
    expect(screen.getByRole('region', { name: 'Documents' })).toBeInTheDocument()
    expect(screen.getByText('Last 30 days')).toBeInTheDocument()
    expect(screen.getByRole('link', { name: fleet.name })).toHaveAttribute(
      'href',
      `/fleet/fleets/${fleet.id}`,
    )
    expect(screen.getByRole('link', { name: 'Vehicles' })).toHaveAttribute(
      'href',
      '/fleet/vehicles',
    )
  })

  describe('reviewing a document', () => {
    const insured = () =>
      getDb().vehicles.find(
        (vehicle) =>
          vehicle.status === 'approved' &&
          vehicle.documents.some((document) => document.document_type === 'vehicle_insurance'),
      )!
    const insuranceOf = (vehicle: ReturnType<typeof insured>) =>
      vehicle.documents.find((document) => document.document_type === 'vehicle_insurance')!

    const openInsurance = async (user: ReturnType<typeof renderApp>['user']) => {
      await user.click(await screen.findByRole('button', { name: /^Insurance certificate/ }))
      return screen.findByRole('region', { name: 'Review Insurance certificate' })
    }

    it('accepts insurance with the date printed on it', async () => {
      const vehicle = insured()
      const { user } = renderApp(`/fleet/vehicles/${vehicle.id}`, { as: ADMIN })
      const panel = await openInsurance(user)
      const date = within(panel).getByLabelText('Expires on')
      await user.clear(date)
      await user.type(date, '2031-05-17')
      await user.click(within(panel).getByRole('button', { name: /Accept|Save date/ }))
      await waitFor(() => expect(insuranceOf(vehicle).status).toBe('approved'))
      expect(insuranceOf(vehicle).expires_at).toBe('2031-05-17')
    })

    it('does not accept insurance without a date', async () => {
      const vehicle = insured()
      const { user } = renderApp(`/fleet/vehicles/${vehicle.id}`, { as: ADMIN })
      const panel = await openInsurance(user)
      await user.clear(within(panel).getByLabelText('Expires on'))
      expect(within(panel).getByRole('button', { name: /Accept|Save date/ })).toBeDisabled()
    })

    it('sends a document back with a reason', async () => {
      const vehicle = insured()
      const { user } = renderApp(`/fleet/vehicles/${vehicle.id}`, { as: ADMIN })
      const panel = await openInsurance(user)
      await user.click(within(panel).getByRole('button', { name: 'Send back' }))
      const send = within(panel).getByRole('button', { name: 'Send it back' })
      expect(send).toBeDisabled()
      await user.type(within(panel).getByLabelText(/What’s wrong/), 'The photo is too blurred.')
      await user.click(send)
      await waitFor(() => expect(insuranceOf(vehicle).status).toBe('rejected'))
      expect(insuranceOf(vehicle).rejection_reason).toBe('The photo is too blurred.')
    })

    it('is not offered to someone who may not review it', async () => {
      const vehicle = insured()
      const { user } = renderApp(`/fleet/vehicles/${vehicle.id}`, {
        as: staffWith('trips:monitor_live'),
      })
      const open = await screen.findByRole('button', { name: /^Insurance certificate/ })
      await user.click(open)
      expect(
        screen.queryByRole('region', { name: 'Review Insurance certificate' }),
      ).not.toBeInTheDocument()
    })
  })

  it('opens a driver with links to their ratings, performance and account', async () => {
    const driver = getDb().drivers.find((candidate) => candidate.status === 'approved')!
    renderApp(`/fleet/drivers/${driver.id}`, { as: ADMIN })
    expect(await screen.findByRole('link', { name: 'Ratings' })).toHaveAttribute(
      'href',
      `/driver-ratings?driver=${driver.id}`,
    )
    expect(screen.getByRole('link', { name: 'Performance' })).toHaveAttribute(
      'href',
      `/driver-performance/${driver.id}`,
    )
    expect(screen.getByRole('link', { name: 'Account' })).toHaveAttribute(
      'href',
      `/accounts/${driver.user_id}`,
    )
    // The phone number is masked until asked for.
    expect(screen.getByText(/\+233 \d{2} ••• \d{4}/)).toBeInTheDocument()
  })

  it('opens a fleet with its figures, vehicles and drivers', async () => {
    const { user } = renderApp('/fleet/fleets', { as: ADMIN })
    await screen.findByRole('table', { name: 'Fleets' })
    const first = within(rowsOf('Fleets')[0]!).getAllByRole('link')[0]!
    const name = first.textContent ?? ''
    await user.click(first)
    expect(await screen.findByRole('heading', { name })).toBeInTheDocument()
    expect(screen.getByText('Vehicles approved')).toBeInTheDocument()
    expect(screen.getByRole('table', { name: 'The fleet’s vehicles' })).toBeInTheDocument()
    expect(screen.getByRole('table', { name: 'The fleet’s drivers' })).toBeInTheDocument()
  })

  it('shows only the tabs an admin may open', async () => {
    renderApp('/fleet', { as: staffWith('trips:monitor_live') })
    await screen.findByRole('table', { name: 'Vehicles' })
    const tabs = screen.getByRole('navigation', { name: 'Fleet' })
    expect(within(tabs).getByRole('link', { name: 'Vehicles' })).toBeInTheDocument()
    expect(within(tabs).getByRole('link', { name: 'Drivers' })).toBeInTheDocument()
    expect(within(tabs).queryByRole('link', { name: 'Fleets' })).toBeNull()
  })

  it('says so when a vehicle doesn’t exist', async () => {
    renderApp('/fleet/vehicles/00000000-0000-4000-8000-000000000000', { as: ADMIN })
    expect(await screen.findByText('Vehicle not found')).toBeInTheDocument()
  })
})
