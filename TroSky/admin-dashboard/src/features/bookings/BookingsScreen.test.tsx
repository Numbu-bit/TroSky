// Loaded up front: the screens these tests open are lazy.
import './BookingsScreen'

import { screen, waitFor, within } from '@testing-library/react'

import { getDb, index } from '@/api/demo/db'
import type { BookingRec } from '@/api/demo/db/model'
import { formatMoney } from '@/lib/format'
import { ADMIN, renderApp, staffWith } from '@/test/render'

type User = ReturnType<typeof renderApp>['user']

function bookingWhere(match: (booking: BookingRec, tripStatus: string) => boolean): BookingRec {
  const found = getDb().bookings.find((booking) =>
    match(booking, index().trips.get(booking.trip_id)!.status),
  )
  if (!found) throw new Error('No such booking in the demo data')
  return found
}

async function confirmIn(user: User, button: string | RegExp, reason?: string) {
  const dialog = await screen.findByRole('alertdialog')
  if (reason) await user.type(within(dialog).getByRole('textbox'), reason)
  await user.click(within(dialog).getByRole('button', { name: button }))
  return dialog
}

describe('All bookings', () => {
  it('are listed newest first and filtered by status', async () => {
    const { user, router } = renderApp('/bookings', { as: ADMIN })
    const table = await screen.findByRole('table', { name: 'Bookings' })
    expect(within(table).getAllByRole('row').length).toBeGreaterThan(5)
    await user.click(screen.getByRole('combobox', { name: 'Status' }))
    await user.click(await screen.findByRole('option', { name: 'Refund waiting' }))
    await waitFor(() => expect(router.state.location.search).toContain('status=refund_pending'))
    await waitFor(() => {
      const rows = within(screen.getByRole('table', { name: 'Bookings' })).getAllByRole('row')
      for (const row of rows.slice(1)) expect(row).toHaveTextContent('Refund waiting')
    })
  })

  it('open in a drawer with the trip, passengers, money and tickets', async () => {
    const booking = bookingWhere((candidate) => candidate.status === 'completed')
    const { user } = renderApp(`/bookings?booking=${booking.id}`, { as: ADMIN })
    const drawer = await screen.findByRole('dialog')
    expect(await within(drawer).findByText(booking.reference)).toBeInTheDocument()
    expect(within(drawer).getByText(formatMoney(booking.total_amount))).toBeInTheDocument()
    // One ticket per passenger.
    expect(await within(drawer).findAllByText(/Scanned on board|Expired/)).toHaveLength(
      booking.passengers.length,
    )
    expect(await within(drawer).findByLabelText('Payments')).toHaveTextContent('Paid')
    // Phone numbers are masked until asked for.
    const passenger = booking.passengers[0]!
    expect(within(drawer).getByText(/\+233 24 ••• \d{4}/)).toBeInTheDocument()
    await user.click(within(drawer).getAllByRole('button', { name: 'Show the full number' })[0]!)
    expect(within(drawer).getByRole('link', { name: /\+233 24 \d{3} \d{4}/ })).toHaveAttribute(
      'href',
      `tel:${passenger.phone_number}`,
    )
    // Travelled: nothing to cancel.
    expect(within(drawer).queryByRole('button', { name: 'Cancel booking' })).not.toBeInTheDocument()
  })

  it('are cancelled before departure at once, with the refund queued', async () => {
    const booking = bookingWhere(
      (candidate, trip) => candidate.status === 'confirmed' && trip === 'scheduled',
    )
    const { user } = renderApp(`/bookings?booking=${booking.id}`, { as: ADMIN })
    const drawer = await screen.findByRole('dialog')
    await user.click(await within(drawer).findByRole('button', { name: 'Cancel booking' }))
    const dialog = await screen.findByRole('alertdialog')
    expect(within(dialog).getByText(/goes to the refund queue for approval/)).toBeInTheDocument()
    expect(within(dialog).getByRole('button', { name: 'Cancel booking' })).toBeDisabled()
    await confirmIn(user, 'Cancel booking', 'Booked twice by mistake.')
    expect(
      await screen.findByText(
        `Cancelled. A refund of ${formatMoney(booking.total_amount)} is waiting for approval.`,
      ),
    ).toBeInTheDocument()
    expect(await within(drawer).findByText('Refund waiting')).toBeInTheDocument()
  })

  it('are sent for a decision once the trip has started', async () => {
    const booking = bookingWhere(
      (candidate, trip) => candidate.status === 'confirmed' && trip === 'in_progress',
    )
    const { user } = renderApp(`/bookings?booking=${booking.id}`, { as: ADMIN })
    const drawer = await screen.findByRole('dialog')
    await user.click(await within(drawer).findByRole('button', { name: 'Cancel booking' }))
    const dialog = await screen.findByRole('alertdialog')
    expect(within(dialog).getByText(/goes to the queue for a decision/)).toBeInTheDocument()
    await confirmIn(user, 'Cancel booking', 'Got off early: family emergency.')
    expect(
      await screen.findByText('Sent for a decision: it is in Cancellations.'),
    ).toBeInTheDocument()
  })

  it('let an admin mark a passenger off the bus', async () => {
    const booking = bookingWhere(
      (candidate, trip) =>
        candidate.status === 'confirmed' &&
        trip === 'in_progress' &&
        candidate.passengers.every((passenger) => !passenger.alighted_at),
    )
    const { user } = renderApp(`/bookings?booking=${booking.id}`, { as: ADMIN })
    const drawer = await screen.findByRole('dialog')
    await user.click((await within(drawer).findAllByRole('button', { name: 'Got off' }))[0]!)
    await confirmIn(user, 'Mark off')
    expect(await screen.findByText(/is marked off. The seat is free again./)).toBeInTheDocument()
  })
})

describe('Refunds', () => {
  it('show what approving pays out, then pay it', async () => {
    const { user } = renderApp('/bookings/refunds', { as: ADMIN })
    const table = await screen.findByRole('table', { name: 'Refund requests' })
    const waiting = () =>
      Number(/(\d+) records?/.exec(screen.getByText(/\d+ records?/).textContent!)![1])
    const before = waiting()
    await user.click(within(table).getAllByRole('button', { name: /Approve the refund/ })[0]!)
    const dialog = await screen.findByRole('alertdialog')
    expect(await within(dialog).findByText(/\(\+233 24 ••• \d{4}\)/)).toBeInTheDocument()
    expect(within(dialog).getByText('Method')).toBeInTheDocument()
    expect(within(dialog).getByText(/This can’t be undone/)).toBeInTheDocument()
    await user.click(within(dialog).getByRole('button', { name: /^Pay back GH₵/ }))
    expect(await screen.findByText(/^Paid back GH₵/)).toBeInTheDocument()
    await waitFor(() => expect(waiting()).toBe(before - 1))
  })

  it('are rejected only with a reason', async () => {
    const { user } = renderApp('/bookings/refunds', { as: ADMIN })
    const table = await screen.findByRole('table', { name: 'Refund requests' })
    await user.click(within(table).getAllByRole('button', { name: /Reject the refund/ })[0]!)
    const dialog = await screen.findByRole('alertdialog')
    expect(within(dialog).getByRole('button', { name: 'Reject refund' })).toBeDisabled()
    await confirmIn(user, 'Reject refund', 'The trip was completed as booked.')
    expect(await screen.findByText('Refund rejected.')).toBeInTheDocument()
  })
})

describe('Cancellations after departure', () => {
  it('are approved with or without a refund', async () => {
    const { user } = renderApp('/bookings/cancellations', { as: ADMIN })
    const table = await screen.findByRole('table', { name: 'Cancellations after departure' })
    await user.click(within(table).getAllByRole('button', { name: 'Approve' })[0]!)
    const dialog = await screen.findByRole('alertdialog')
    await user.click(await within(dialog).findByLabelText(/Refund the passenger/))
    await user.click(within(dialog).getByRole('button', { name: 'Approve cancellation' }))
    expect(
      await screen.findByText('Approved. The refund is waiting in Refunds.'),
    ).toBeInTheDocument()
  })

  it('are turned down only with a reason', async () => {
    const { user } = renderApp('/bookings/cancellations', { as: ADMIN })
    const table = await screen.findByRole('table', { name: 'Cancellations after departure' })
    await user.click(within(table).getAllByRole('button', { name: 'Turn down' })[0]!)
    const dialog = await screen.findByRole('alertdialog')
    expect(within(dialog).getByRole('button', { name: 'Turn down' })).toBeDisabled()
    await confirmIn(user, 'Turn down', 'The trip was nearly over.')
    expect(await screen.findByText('Turned down. The booking stays as it is.')).toBeInTheDocument()
  })
})

describe('Permissions', () => {
  it('show refunds only to those who approve them', async () => {
    renderApp('/bookings', { as: staffWith('bookings:view_any') })
    await screen.findByRole('table', { name: 'Bookings' })
    expect(screen.queryByRole('link', { name: /Refunds/ })).not.toBeInTheDocument()
  })

  it('send refund approvers without bookings:view_any to the refunds', async () => {
    const { router } = renderApp('/bookings', { as: staffWith('refunds:approve') })
    expect(await screen.findByRole('table', { name: 'Refund requests' })).toBeInTheDocument()
    expect(router.state.location.pathname).toBe('/bookings/refunds')
  })
})
