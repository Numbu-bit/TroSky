// Loaded up front: the screens these tests open are lazy.
import './AccountsScreen'
import '@/features/overview/OverviewPage'

import { fireEvent, screen, waitFor, within } from '@testing-library/react'

import { getDb } from '@/api/demo/db'
import { sessionsFor } from '@/api/demo/db/extras'
import { ADMIN, renderApp, staffWith } from '@/test/render'

/** A passenger signed in on at least one device. */
function signedInPassenger() {
  const user = getDb().users.find(
    (candidate) =>
      candidate.roles.includes('passenger') &&
      !candidate.is_suspended &&
      sessionsFor(candidate.id).length > 0,
  )
  if (!user) throw new Error('No such passenger in the demo data')
  return user
}

describe('Accounts', () => {
  it('are found by phone number, which stays out of the address', async () => {
    const person = signedInPassenger()
    const { user, router } = renderApp('/accounts', { as: ADMIN })
    await screen.findByRole('table', { name: 'Accounts' })
    await user.type(
      screen.getByRole('searchbox', { name: 'Search' }),
      `0${person.phone_number.slice(4)}`,
    )
    await waitFor(() => {
      const rows = within(screen.getByRole('table', { name: 'Accounts' })).getAllByRole('row')
      expect(rows).toHaveLength(2)
      expect(rows[1]).toHaveTextContent(person.full_name)
    })
    expect(router.state.location.search).not.toContain(person.phone_number.slice(4))
    // Lists show numbers and emails masked.
    expect(screen.getByRole('table', { name: 'Accounts' })).toHaveTextContent(/\+233 24 ••• \d{4}/)
  })

  it('are suspended with a reason, which signs them out everywhere', async () => {
    const person = signedInPassenger()
    const devices = sessionsFor(person.id).length
    const { user } = renderApp(`/accounts/${person.id}`, { as: ADMIN })
    expect(await screen.findByRole('heading', { name: person.full_name })).toBeInTheDocument()
    expect(await screen.findAllByRole('button', { name: 'Sign out' })).toHaveLength(devices)

    await user.click(screen.getByRole('button', { name: 'Suspend' }))
    const dialog = await screen.findByRole('alertdialog')
    expect(
      within(dialog).getByText(/signs them out of every device straight away/),
    ).toBeInTheDocument()
    expect(within(dialog).getByRole('button', { name: 'Suspend account' })).toBeDisabled()
    await user.type(within(dialog).getByRole('textbox'), 'Fare dispute under review.')
    await user.click(within(dialog).getByRole('button', { name: 'Suspend account' }))

    expect(await screen.findByText(/is suspended and signed out everywhere/)).toBeInTheDocument()
    expect(await screen.findByText('Suspended: “Fare dispute under review.”')).toBeInTheDocument()
    expect(await screen.findByText('Not signed in anywhere.')).toBeInTheDocument()

    await user.click(screen.getByRole('button', { name: 'Reactivate' }))
    await user.click(
      within(await screen.findByRole('alertdialog')).getByRole('button', { name: 'Reactivate' }),
    )
    expect(await screen.findByText(/can use TroSky again/)).toBeInTheDocument()
    expect(await screen.findByRole('button', { name: 'Suspend' })).toBeInTheDocument()
  })

  it('are signed out of one device at a time', async () => {
    const person = signedInPassenger()
    const devices = sessionsFor(person.id).length
    const { user } = renderApp(`/accounts/${person.id}`, { as: ADMIN })
    await user.click((await screen.findAllByRole('button', { name: 'Sign out' }))[0]!)
    await user.click(
      within(await screen.findByRole('alertdialog')).getByRole('button', { name: 'Sign out' }),
    )
    expect(await screen.findByText('Signed out of that device.')).toBeInTheDocument()
    await waitFor(() =>
      expect(screen.queryAllByRole('button', { name: 'Sign out' })).toHaveLength(devices - 1),
    )
  })

  it('can be looked at, but not suspended, without users:suspend', async () => {
    const person = signedInPassenger()
    renderApp(`/accounts/${person.id}`, { as: staffWith('users:manage') })
    expect(await screen.findByRole('heading', { name: person.full_name })).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'Suspend' })).not.toBeInTheDocument()
  })

  it('are found from any page with Ctrl+K', async () => {
    const person = signedInPassenger()
    const { user, router } = renderApp('/overview', { as: ADMIN })
    await screen.findByRole('heading', { name: 'Overview' })
    fireEvent.keyDown(window, { key: 'k', ctrlKey: true })
    const dialog = await screen.findByRole('dialog', { name: 'Search' })
    await user.type(within(dialog).getByRole('combobox'), person.full_name)
    await user.click(
      await within(dialog).findByRole('option', { name: new RegExp(person.full_name) }),
    )
    await waitFor(() => expect(router.state.location.pathname).toBe(`/accounts/${person.id}`))
    expect(await screen.findByRole('heading', { name: person.full_name })).toBeInTheDocument()
  })
})
