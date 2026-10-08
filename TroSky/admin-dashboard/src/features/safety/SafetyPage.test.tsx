// Loaded up front: the screens these tests open are lazy, and their first
// load would otherwise eat into the tests' own waiting time.
import './SafetyPage'
import './SosMap'
import '@/features/overview/OverviewPage'

import { screen, waitFor, within } from '@testing-library/react'

import { raiseDemoSos } from '@/api/demo/handlers/safety'
import { ADMIN, renderApp, STAFF } from '@/test/render'

async function openTheSos(user: ReturnType<typeof renderApp>['user']) {
  await user.click(await screen.findByRole('link', { name: 'Open SOS' }))
  return screen.findByRole('dialog')
}

describe('SOS alerts', () => {
  it('raise a red banner on every page until acknowledged', async () => {
    const { user } = renderApp('/overview', { as: ADMIN })
    expect(await screen.findByText('SOS not yet acknowledged')).toBeInTheDocument()

    const drawer = await openTheSos(user)
    expect(await within(drawer).findByText(/SOS from/)).toBeInTheDocument()
    expect(within(drawer).getByRole('link', { name: /Call raised by/ })).toHaveAttribute(
      'href',
      expect.stringMatching(/^tel:\+23324000/),
    )
    expect(
      within(drawer).getByRole('link', { name: /Ghana Police Service \(191\)/ }),
    ).toHaveAttribute('href', 'tel:191')

    await user.click(within(drawer).getByRole('button', { name: 'Acknowledge' }))

    expect(await screen.findByText(/help is on the way/)).toBeInTheDocument()
    await waitFor(() =>
      expect(screen.queryByText('SOS not yet acknowledged')).not.toBeInTheDocument(),
    )
    expect(await within(drawer).findByText('Acknowledged')).toBeInTheDocument()
  })

  it('count every one not yet acknowledged', async () => {
    raiseDemoSos()
    renderApp('/safety', { as: ADMIN })
    expect(await screen.findByText('2 SOS alerts not yet acknowledged')).toBeInTheDocument()
  })

  it('are resolved with a note, or closed as a false alarm', async () => {
    const { user } = renderApp('/safety', { as: ADMIN })
    const drawer = await openTheSos(user)
    await user.click(await within(drawer).findByRole('button', { name: 'Resolve' }))

    const confirm = await screen.findByRole('alertdialog')
    const close = within(confirm).getByRole('button', { name: 'Resolve' })
    expect(close).toBeDisabled() // a note is required
    await user.type(within(confirm).getByLabelText('Resolution note'), 'Pressed by mistake.')
    await user.click(within(confirm).getByLabelText('It was a false alarm'))
    await user.click(within(confirm).getByRole('button', { name: 'Close as false alarm' }))

    expect(await screen.findByText('Closed as a false alarm.')).toBeInTheDocument()
    expect(await within(drawer).findByText('Pressed by mistake.')).toBeInTheDocument()
  })

  it('keep a log of who was called', async () => {
    const { user } = renderApp('/safety', { as: ADMIN })
    const drawer = await openTheSos(user)
    expect(await within(drawer).findByText('Nobody has been called yet.')).toBeInTheDocument()

    await user.type(within(drawer).getByLabelText('Name (optional)'), 'Inspector Mensah')
    await user.type(
      within(drawer).getByLabelText('What was agreed (optional)'),
      'A patrol car is on its way.',
    )
    await user.click(within(drawer).getByRole('button', { name: 'Log escalation' }))

    expect(await screen.findByText('Escalation logged.')).toBeInTheDocument()
    expect(await within(drawer).findByText('A patrol car is on its way.')).toBeInTheDocument()
    expect(within(drawer).getByText(/Police · Inspector Mensah/)).toBeInTheDocument()
  })

  it('list the open ones with who raised them and from which bus', async () => {
    renderApp('/safety', { as: ADMIN })
    const table = await screen.findByRole('table', { name: 'SOS alerts' })
    await waitFor(() => expect(within(table).getAllByRole('row')).toHaveLength(3))
    expect(within(table).getByText('Not acknowledged')).toBeInTheDocument()
    expect(within(table).getByText('Acknowledged')).toBeInTheDocument()
    expect(await within(table).findAllByText(/\+233 24 ••• \d{4}/)).toHaveLength(2)
  })
})

describe('Incidents', () => {
  it('are resolved with a note', async () => {
    const { user } = renderApp('/safety/incidents?status=reported', { as: ADMIN })
    const table = await screen.findByRole('table', { name: 'Incidents reported on trips' })
    const before = within(table).getAllByRole('row').length - 1
    await user.click(within(table).getAllByRole('button', { name: 'Resolve' })[0]!)
    const confirm = await screen.findByRole('alertdialog')
    await user.type(
      within(confirm).getByLabelText('Resolution note'),
      'Driver took the Mallam road.',
    )
    await user.click(within(confirm).getByRole('button', { name: 'Resolve' }))

    expect(await screen.findByText('Incident resolved.')).toBeInTheDocument()
    await waitFor(() =>
      expect(
        within(screen.getByRole('table', { name: 'Incidents reported on trips' })).getAllByRole(
          'row',
        ),
      ).toHaveLength(before),
    )
  })

  it('are only for those who manage incidents', async () => {
    renderApp('/safety/incidents', { as: STAFF })
    // Staff hold sos:review but not incidents:manage: back to the SOS alerts.
    expect(await screen.findByRole('table', { name: 'SOS alerts' })).toBeInTheDocument()
    expect(screen.queryByRole('link', { name: 'Incidents' })).not.toBeInTheDocument()
  })
})
