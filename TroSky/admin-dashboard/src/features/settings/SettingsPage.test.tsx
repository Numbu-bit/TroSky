// Loaded up front: the screen these tests open is lazy.
import './SettingsPage'

import { screen, within } from '@testing-library/react'

import { ADMIN, renderApp, staffWith } from '@/test/render'

type User = ReturnType<typeof renderApp>['user']

const card = (element: HTMLElement) => element.closest<HTMLElement>('[data-slot="card"]')!

async function confirmWith(user: User, reason: string) {
  const dialog = await screen.findByRole('alertdialog')
  if (reason) await user.type(within(dialog).getByRole('textbox'), reason)
  await user.click(within(dialog).getByRole('button', { name: 'Save' }))
}

describe('Settings', () => {
  it('checks a setting’s limits, saves it with a reason, and puts the default back', async () => {
    const { user } = renderApp('/settings', { as: ADMIN })
    const fee = await screen.findByLabelText('Platform fee per seat')
    expect(fee).toHaveValue('0.50')
    const box = card(fee)
    expect(within(box).getByText('Default')).toBeInTheDocument()

    await user.clear(fee)
    await user.type(fee, '150')
    await user.click(within(box).getByRole('button', { name: 'Save' }))
    expect(within(box).getByRole('alert')).toHaveTextContent(
      'Enter a number with at most 2 decimals from 0 to 100.',
    )
    expect(screen.queryByRole('alertdialog')).toBeNull()

    await user.clear(fee)
    await user.type(fee, '0.75')
    await user.click(within(box).getByRole('button', { name: 'Save' }))
    expect(
      await screen.findByRole('alertdialog', { name: 'Save platform fee per seat?' }),
    ).toBeInTheDocument()
    await confirmWith(user, 'Covering the new SMS costs.')
    expect(await screen.findByText('Platform fee per seat saved.')).toBeInTheDocument()
    const saved = await screen.findByLabelText('Platform fee per seat')
    expect(saved).toHaveValue('0.75')
    expect(within(card(saved)).getByText(/^Changed /)).toBeInTheDocument()

    await user.click(within(card(saved)).getByRole('button', { name: 'Back to default' }))
    expect(
      await screen.findByRole('alertdialog', {
        name: 'Put platform fee per seat back to the default?',
      }),
    ).toBeInTheDocument()
    await confirmWith(user, '')
    expect(
      await screen.findByText('Platform fee per seat: back to the default.'),
    ).toBeInTheDocument()
    expect(await screen.findByLabelText('Platform fee per seat')).toHaveValue('0.50')
  })

  it('turns a feature flag off, and checks a rollout', async () => {
    const { user } = renderApp('/settings', { as: ADMIN })
    const flags = await screen.findByRole('region', { name: 'Feature flags' })
    const share = await within(flags).findByRole('switch', { name: 'trip_share_links' })
    expect(share).toBeChecked()
    // Platform-wide flags are on or off for everyone: no rollout.
    expect(within(flags).getAllByLabelText('Share of users who get it')).toHaveLength(1)

    const rollout = within(flags).getByLabelText('Share of users who get it')
    await user.clear(rollout)
    await user.type(rollout, '150')
    await user.click(within(rollout.closest('form')!).getByRole('button', { name: 'Save' }))
    expect(await screen.findByText('Rollout is a whole number from 0 to 100.')).toBeInTheDocument()
    expect(screen.queryByRole('alertdialog')).toBeNull()

    await user.click(share)
    expect(
      await screen.findByRole('alertdialog', { name: 'Turn trip_share_links off?' }),
    ).toBeInTheDocument()
    await confirmWith(user, 'Paused while the link page is fixed.')
    expect(await screen.findByText('trip_share_links saved.')).toBeInTheDocument()
    expect(await screen.findByRole('switch', { name: 'trip_share_links' })).not.toBeChecked()
  })

  it('shows only what an admin may change', async () => {
    renderApp('/settings', { as: staffWith('feature_flags:manage') })
    expect(await screen.findByRole('region', { name: 'Feature flags' })).toBeInTheDocument()
    expect(screen.queryByRole('region', { name: 'Platform settings' })).toBeNull()
  })
})
