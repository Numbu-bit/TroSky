// Loaded up front: the screens these tests open are lazy.
import './DispatchPage'

import { screen, waitFor, within } from '@testing-library/react'

import { getDb, index, touch } from '@/api/demo/db'
import { ADMIN, renderApp, staffWith } from '@/test/render'

async function requests() {
  return screen.findByRole('list', { name: 'Bookings waiting for a driver' })
}

describe('Bookings waiting for drivers', () => {
  it('are listed with the time left to answer', async () => {
    renderApp('/dispatch', { as: ADMIN })
    const list = await requests()
    const items = within(list).getAllByRole('listitem')
    expect(items.length).toBeGreaterThan(0)
    expect(
      within(items[0]!).getByLabelText(/seconds left to answer|Time is up/),
    ).toBeInTheDocument()
    expect(screen.getByRole('link', { name: /Waiting for drivers/ })).toHaveTextContent(
      String(items.length),
    )
  })

  it('can be accepted for the driver', async () => {
    const { user } = renderApp('/dispatch', { as: ADMIN })
    const list = await requests()
    const before = within(list).getAllByRole('listitem').length
    await user.click(within(list).getAllByRole('button', { name: 'Accept' })[0]!)
    expect(await screen.findByText(/The passenger is asked to pay/)).toBeInTheDocument()
    await waitFor(() =>
      expect(
        within(screen.getByRole('list', { name: /waiting for a driver/ })).getAllByRole('listitem')
          .length,
      ).toBeLessThanOrEqual(before),
    )
  })

  it('are declined with a reason, and offered to another vehicle', async () => {
    const { user } = renderApp('/dispatch', { as: ADMIN })
    const list = await requests()
    await user.click(within(list).getAllByRole('button', { name: 'Decline' })[0]!)
    const confirm = await screen.findByRole('alertdialog')
    expect(within(confirm).getByLabelText(/Move it to another vehicle/)).toBeChecked()
    const decline = within(confirm).getByRole('button', { name: 'Decline' })
    expect(decline).toBeDisabled()
    await user.type(within(confirm).getByLabelText('Reason'), 'The minibus is already full.')
    await user.click(decline)
    expect(
      await screen.findByText('Declined. It is offered to another vehicle if one has seats.'),
    ).toBeInTheDocument()
  })

  it('can be moved to another trip on the same route that day', async () => {
    // Make sure the first request's route has another trip that day.
    const offer = getDb()
      .offers.filter((candidate) => candidate.status === 'pending')
      .sort((a, b) => a.expires_at.localeCompare(b.expires_at))[0]!
    const trip = index().trips.get(offer.trip_id)!
    getDb().trips.push({
      ...trip,
      id: '7a1e0000-0000-4000-8000-000000000001',
      scheduled_departure_at: trip.scheduled_departure_at.replace(/T\d\d:/, 'T23:'),
      status: 'scheduled',
      live: false,
    })
    touch()

    const { user } = renderApp(`/dispatch`, { as: ADMIN })
    const list = await requests()
    const first = within(list).getAllByRole('listitem')[0]!
    await user.click(within(first).getByRole('button', { name: /to another trip/ }))
    const dialog = await screen.findByRole('alertdialog')
    await user.click(within(dialog).getByRole('combobox', { name: 'Trip' }))
    await user.click((await screen.findAllByRole('option', { name: /^23:/ }))[0]!)
    await user.click(within(dialog).getByRole('button', { name: 'Move' }))
    expect(await screen.findByText('Moved. It is waiting for that driver now.')).toBeInTheDocument()
  })

  it('can only be watched by those who monitor trips', async () => {
    renderApp('/dispatch', { as: staffWith('trips:monitor_live') })
    const list = await requests()
    expect(within(list).queryByRole('button', { name: 'Accept' })).not.toBeInTheDocument()
  })
})

describe('What drivers did', () => {
  it('lists actions newest first, filtered by what was done', async () => {
    const { user, router } = renderApp('/dispatch/actions', { as: ADMIN })
    const table = await screen.findByRole('table', { name: 'What drivers did' })
    expect(within(table).getAllByRole('row').length).toBeGreaterThan(1)

    await user.click(screen.getByRole('combobox', { name: 'What' }))
    await user.click(await screen.findByRole('option', { name: 'Declined the trip' }))
    await waitFor(() => expect(router.state.location.search).toContain('kind=trip_declined'))
    await waitFor(() => {
      const rows = within(screen.getByRole('table', { name: 'What drivers did' })).getAllByRole(
        'row',
      )
      expect(rows.length).toBeGreaterThan(1)
      for (const row of rows.slice(1)) expect(row).toHaveTextContent('Declined the trip')
    })
  })

  it('names the driver it is filtered by, from the address or as picked', async () => {
    const { driver_id: driverId } = getDb().driverActions.find((action) => action.driver_id)!
    const driver = index().drivers.get(driverId!)!
    const name = index().users.get(driver.user_id)!.full_name!
    const { user, router } = renderApp(`/dispatch/actions?driver=${driverId}`, { as: ADMIN })
    const picker = await screen.findByRole('combobox', { name: 'Driver' })
    await waitFor(() => expect(picker).toHaveTextContent(name))

    await user.click(picker)
    const other = (await screen.findAllByRole('option')).find(
      (option) =>
        option.textContent && !option.textContent.startsWith(name) && option.textContent !== 'Any',
    )!
    const otherName = within(other).getAllByText(/./)[0]!.textContent!
    await user.click(other)
    await waitFor(() => expect(router.state.location.search).not.toContain(driverId!))
    expect(screen.getByRole('combobox', { name: 'Driver' })).toHaveTextContent(otherName)
  })

  it('shows who acted for the driver', async () => {
    const { user } = renderApp('/dispatch/actions', { as: ADMIN })
    await screen.findByRole('table', { name: 'What drivers did' })
    await user.click(screen.getByRole('combobox', { name: 'Done by' }))
    await user.click(await screen.findByRole('option', { name: 'The system' }))
    await waitFor(() => {
      const rows = within(screen.getByRole('table', { name: 'What drivers did' })).getAllByRole(
        'row',
      )
      for (const row of rows.slice(1)) expect(row).toHaveTextContent('The system')
    })
  })
})
