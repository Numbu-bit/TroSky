// Loaded up front: the screens these tests open are lazy.
import './TripsScreen'
import '@/components/map/RouteMap'

import { fireEvent, screen, waitFor, within } from '@testing-library/react'

import { getDb, index, touch } from '@/api/demo/db'
import { accraDateKey } from '@/lib/format'
import { ADMIN, renderApp, staffWith } from '@/test/render'

const tomorrow = () => accraDateKey(new Date(Date.now() + 86_400_000))

async function choose(
  user: ReturnType<typeof renderApp>['user'],
  label: RegExp | string,
  option: RegExp | string,
) {
  await user.click(screen.getByRole('combobox', { name: label }))
  await user.click(await screen.findByRole('option', { name: option }))
}

/** A trip still ahead, chosen from the demo platform. */
function aheadTrip(match: (trip: ReturnType<typeof getDb>['trips'][number]) => boolean) {
  const trip = getDb().trips.find(
    (candidate) =>
      candidate.status === 'scheduled' &&
      Date.parse(candidate.scheduled_departure_at) > Date.now() + 3_600_000 &&
      match(candidate),
  )
  if (!trip) throw new Error('No such trip in the demo data')
  return trip
}

describe('Trips list', () => {
  it('shows today’s unfinished trips, soonest first', async () => {
    renderApp('/trips', { as: ADMIN })
    const table = await screen.findByRole('table', { name: 'Trips' })
    const rows = within(table).getAllByRole('row').slice(1)
    expect(rows.length).toBeGreaterThan(0)
    for (const status of ['Completed', 'Cancelled']) {
      expect(within(table).queryByText(status)).not.toBeInTheDocument()
    }
  })

  it('filters by status, and remembers it in the address', async () => {
    const { user, router } = renderApp('/trips', { as: ADMIN })
    await screen.findByRole('table', { name: 'Trips' })
    await choose(user, 'Status', 'In progress')
    await waitFor(() => expect(router.state.location.search).toContain('status=in_progress'))
    const table = await screen.findByRole('table', { name: 'Trips' })
    await waitFor(() =>
      expect(within(table).getAllByText('In progress').length).toBe(
        within(table).getAllByRole('row').length - 1,
      ),
    )
  })

  it('shows nothing to change to those who only watch trips', async () => {
    renderApp('/trips', { as: staffWith('trips:monitor_live') })
    await screen.findByRole('table', { name: 'Trips' })
    expect(screen.queryByRole('button', { name: 'New trip' })).not.toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'From timetable' })).not.toBeInTheDocument()
  })
})

describe('Creating trips', () => {
  it('checks the form, then opens the new trip', async () => {
    const { user, router } = renderApp('/trips', { as: ADMIN })
    await user.click(await screen.findByRole('button', { name: 'New trip' }))
    const dialog = await screen.findByRole('dialog')
    await user.click(within(dialog).getByRole('button', { name: 'Create trip' }))
    expect(await within(dialog).findByText('Choose a route.')).toBeInTheDocument()
    expect(within(dialog).getByText('Choose the departure time.')).toBeInTheDocument()

    await choose(user, 'Route', /Circle – Madina/)
    fireEvent.change(within(dialog).getByLabelText('Day'), { target: { value: tomorrow() } })
    fireEvent.change(within(dialog).getByLabelText('Departure'), { target: { value: '07:15' } })
    await user.type(within(dialog).getByLabelText(/Fare per seat/), '9.5x')
    await user.click(within(dialog).getByRole('button', { name: 'Create trip' }))
    expect(await within(dialog).findByText(/Enter an amount in cedis/)).toBeInTheDocument()
    await user.clear(within(dialog).getByLabelText(/Fare per seat/))
    await user.type(within(dialog).getByLabelText(/Fare per seat/), '9.50')
    await user.click(within(dialog).getByRole('button', { name: 'Create trip' }))

    expect(await screen.findByRole('heading', { name: 'Circle – Madina' })).toBeInTheDocument()
    expect(router.state.location.pathname).toMatch(/^\/trips\/[0-9a-f-]{36}$/)
    expect(screen.getByText('No driver on this trip yet.')).toBeInTheDocument()
    expect(screen.getByText('GH₵9.50')).toBeInTheDocument()
  })

  it('makes a trip from a timetable entry', async () => {
    const { user } = renderApp('/trips', { as: ADMIN })
    await user.click(await screen.findByRole('button', { name: 'From timetable' }))
    const dialog = await screen.findByRole('dialog')
    await choose(user, 'Route', /Achimota – Amasaman/)
    await choose(user, 'Timetable entry', /05:45/)
    fireEvent.change(within(dialog).getByLabelText('Day'), { target: { value: tomorrow() } })
    await user.click(within(dialog).getByRole('button', { name: 'Create trip' }))

    expect(await screen.findByRole('heading', { name: 'Achimota – Amasaman' })).toBeInTheDocument()
    expect(screen.getByText('The timetable')).toBeInTheDocument()
  })
})

describe('A trip', () => {
  it('gets a driver, who is asked to accept; an admin can accept for them', async () => {
    const trip = aheadTrip(() => true)
    trip.driver_id = null
    trip.driver_response = null
    touch()
    const { user } = renderApp(`/trips/${trip.id}`, { as: ADMIN })
    await user.click(await screen.findByRole('combobox', { name: 'Choose the driver' }))
    const option = (await screen.findAllByRole('option'))[0]!
    const name = option.querySelector('.truncate')?.textContent ?? ''
    await user.click(option)
    const confirm = await screen.findByRole('alertdialog')
    expect(within(confirm).getByText(/is asked to accept the trip/)).toBeInTheDocument()
    await user.click(within(confirm).getByRole('button', { name: 'Assign driver' }))

    expect(
      await screen.findByText(/is on the trip and has been asked to accept it/),
    ).toBeInTheDocument()
    expect(await screen.findByText('Not answered yet')).toBeInTheDocument()
    expect(screen.getByText(name, { selector: 'p' })).toBeInTheDocument()

    await user.click(screen.getByRole('button', { name: 'Accept for the driver' }))
    await user.click(
      within(await screen.findByRole('alertdialog')).getByRole('button', { name: 'Accept' }),
    )
    expect(await screen.findByText('Accepted for the driver.')).toBeInTheDocument()
    expect(await screen.findByText('Accepted', { selector: 'span' })).toBeInTheDocument()
  })

  it('declines for the driver only with a reason', async () => {
    const trip = aheadTrip((candidate) => candidate.driver_response === 'pending')
    const { user } = renderApp(`/trips/${trip.id}`, { as: ADMIN })
    await user.click(await screen.findByRole('button', { name: 'Decline for the driver' }))
    const confirm = await screen.findByRole('alertdialog')
    const decline = within(confirm).getByRole('button', { name: 'Decline' })
    expect(decline).toBeDisabled()
    await user.type(within(confirm).getByLabelText('Reason'), 'Called in sick.')
    await user.click(decline)
    expect(await screen.findByText(/Declined for the driver/)).toBeInTheDocument()
    expect(await screen.findByText('No driver on this trip yet.')).toBeInTheDocument()
    expect(
      await screen.findByText(/declined \(answered by an admin\): “Called in sick.”/),
    ).toBeInTheDocument()
  })

  it('is cancelled with a reason, and says what happened to its bookings', async () => {
    const trip = aheadTrip((candidate) =>
      (index().bookingsByTrip.get(candidate.id) ?? []).some(
        (booking) => booking.status === 'confirmed',
      ),
    )
    const { user } = renderApp(`/trips/${trip.id}`, { as: ADMIN })
    await user.click(await screen.findByRole('button', { name: 'Cancel trip' }))
    const confirm = await screen.findByRole('alertdialog')
    await user.type(within(confirm).getByLabelText(/Reason/), 'The vehicle broke down.')
    await user.click(within(confirm).getByRole('button', { name: 'Cancel trip' }))

    const panel = await screen.findByRole('status')
    expect(within(panel).getByText('The trip is cancelled.')).toBeInTheDocument()
    expect(
      within(panel).getByText(/bookings? cancelled and the passengers told/),
    ).toBeInTheDocument()
    expect(within(panel).getByText(/waiting for approval/)).toBeInTheDocument()
    expect(within(panel).getByRole('link', { name: 'Review refunds' })).toHaveAttribute(
      'href',
      '/bookings/refunds',
    )
    expect(await screen.findByText('Cancelled', { selector: 'span' })).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'Cancel trip' })).not.toBeInTheDocument()
  })

  it('plays a finished trip back from its recorded positions', async () => {
    const trip = getDb().trips.find(
      (candidate) => candidate.status === 'completed' && candidate.actual_departure_at,
    )!
    const { user } = renderApp(`/trips/${trip.id}`, { as: ADMIN })
    const replay = await screen.findByRole('group', { name: 'Trip replay' })
    expect(screen.getByRole('button', { name: /Positions \(CSV\)/ })).toBeEnabled()
    const slider = within(replay).getByRole('slider', { name: 'Moment in the trip' })
    // Not replaying: the whole trip, the slider at its end.
    expect(slider).toHaveAttribute('aria-valuenow', slider.getAttribute('aria-valuemax'))

    await user.click(within(replay).getByRole('button', { name: 'Replay the trip' }))
    // From the start, and moving: a minute of the trip a second at 60x.
    expect(within(replay).getByRole('button', { name: 'Pause' })).toBeInTheDocument()
    const first = slider.getAttribute('aria-valuetext')
    await waitFor(() => expect(slider.getAttribute('aria-valuetext')).not.toBe(first))
    expect(Number(slider.getAttribute('aria-valuenow'))).toBeGreaterThan(0)
    await user.click(within(replay).getByRole('button', { name: 'Pause' }))
    const paused = slider.getAttribute('aria-valuetext')
    expect(within(replay).getByText(/ km\/h · | of [\d.]+ km/)).toBeInTheDocument()

    // The keyboard moves it too, and the speed can change.
    slider.focus()
    await user.keyboard('{PageUp}')
    expect(slider.getAttribute('aria-valuetext')).not.toBe(paused)
    await user.click(within(replay).getByRole('radio', { name: '240 times as fast' }))
    expect(within(replay).getByRole('radio', { name: '240 times as fast' })).toBeChecked()

    await user.click(within(replay).getByRole('button', { name: 'Whole trip' }))
    expect(within(replay).getByRole('button', { name: 'Replay the trip' })).toBeInTheDocument()
    expect(slider).toHaveAttribute('aria-valuenow', slider.getAttribute('aria-valuemax'))
  })

  it('says so when it doesn’t exist', async () => {
    renderApp('/trips/00000000-0000-4000-8000-000000000000', { as: ADMIN })
    expect(await screen.findByText('Trip not found')).toBeInTheDocument()
  })
})
