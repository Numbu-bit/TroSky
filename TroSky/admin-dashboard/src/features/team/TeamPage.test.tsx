// Loaded up front: the screen these tests open is lazy.
import './TeamPage'

import { screen, waitFor, within } from '@testing-library/react'

import { getDb } from '@/api/demo/db'
import { ADMIN, renderApp, STAFF, SUPER_ADMIN } from '@/test/render'

type User = ReturnType<typeof renderApp>['user']

const row = (name: string) =>
  within(screen.getByRole('table', { name: 'Admin team' }))
    .getAllByRole('row')
    .find((candidate) => candidate.textContent?.includes(name))

async function invite(user: User, fields: { name: string; phone: string; reason: string }) {
  await user.click(await screen.findByRole('button', { name: 'Add someone' }))
  const dialog = await screen.findByRole('dialog', { name: 'Add someone to the team' })
  await user.type(within(dialog).getByLabelText('Full name'), fields.name)
  await user.type(within(dialog).getByLabelText('Phone'), fields.phone)
  await user.type(within(dialog).getByLabelText('Why (for the audit log)'), fields.reason)
  return dialog
}

describe('Admin team', () => {
  it('shows each member’s role and what they may do', async () => {
    renderApp('/team', { as: ADMIN })
    await screen.findByRole('table', { name: 'Admin team' })
    expect(row(SUPER_ADMIN.full_name)).toHaveTextContent('Everything')
    expect(row(ADMIN.full_name)).toHaveTextContent('(you)')
    expect(row(ADMIN.full_name)).toHaveTextContent('Everything but managing super admins')
    expect(row(STAFF.full_name)).toHaveTextContent('Handle complaints')
    // No one changes their own access, or that of someone above them.
    expect(within(row(ADMIN.full_name)!).queryByRole('button')).toBeNull()
    expect(within(row(SUPER_ADMIN.full_name)!).queryByRole('button')).toBeNull()
    expect(
      within(row(STAFF.full_name)!).getByRole('button', {
        name: `Change ${STAFF.full_name} access`,
      }),
    ).toBeInTheDocument()
  })

  it('adds a new staff member with what they may do', async () => {
    expect(getDb().users.some((user) => user.phone_number === '+233559876543')).toBe(false)
    const { user } = renderApp('/team', { as: ADMIN })
    const dialog = await invite(user, {
      name: 'Efua Mensah',
      phone: '055 987 6543',
      reason: 'Joins the support desk.',
    })
    await user.click(within(dialog).getByRole('button', { name: 'Add to the team' }))
    expect(within(dialog).getByRole('alert')).toHaveTextContent(
      'Tick at least one thing a staff member may do.',
    )
    await user.click(within(dialog).getByRole('checkbox', { name: /^Handle complaints/ }))
    await user.click(within(dialog).getByRole('button', { name: 'Add to the team' }))
    expect(
      await screen.findByText('Efua Mensah joined the team. A code to set a password was sent.'),
    ).toBeInTheDocument()
    await waitFor(() => expect(row('Efua Mensah')).toHaveTextContent('Handle complaints'))
    expect(row('Efua Mensah')).toHaveTextContent('+233 55 ••• 6543')
  })

  it('says when someone is already on the team', async () => {
    const { user } = renderApp('/team', { as: ADMIN })
    const dialog = await invite(user, {
      name: STAFF.full_name,
      phone: `0${STAFF.phone_number.slice(4)}`,
      reason: 'Invited twice by mistake.',
    })
    await user.click(within(dialog).getByRole('checkbox', { name: /^Handle complaints/ }))
    await user.click(within(dialog).getByRole('button', { name: 'Add to the team' }))
    expect(await within(dialog).findByRole('alert')).toHaveTextContent(
      'This person is already on the admin team.',
    )
  })

  it('changes a staff member’s access, then removes them with a reason', async () => {
    const { user } = renderApp('/team', { as: ADMIN })
    await screen.findByRole('table', { name: 'Admin team' })
    await user.click(screen.getByRole('button', { name: 'Change Yaw Boateng access' }))
    const dialog = await screen.findByRole('dialog', { name: 'Change Yaw Boateng’s access' })
    await user.click(within(dialog).getByRole('checkbox', { name: /^Handle SOS alerts/ }))
    await user.click(within(dialog).getByRole('button', { name: 'Save access' }))
    expect(await screen.findByText('Yaw Boateng’s access changed.')).toBeInTheDocument()
    await waitFor(() => expect(row('Yaw Boateng')).toHaveTextContent('Handle SOS alerts'))

    await user.click(within(row('Yaw Boateng')!).getByRole('button', { name: 'Remove' }))
    const confirm = await screen.findByRole('alertdialog', {
      name: 'Take Yaw Boateng off the team?',
    })
    expect(within(confirm).getByRole('button', { name: 'Remove from the team' })).toBeDisabled()
    await user.type(within(confirm).getByRole('textbox'), 'Moved to another team.')
    await user.click(within(confirm).getByRole('button', { name: 'Remove from the team' }))
    expect(await screen.findByText('Yaw Boateng left the team.')).toBeInTheDocument()
    await waitFor(() => expect(row('Yaw Boateng')).toBeUndefined())
  })
})
