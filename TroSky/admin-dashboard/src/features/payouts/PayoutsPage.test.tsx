// Loaded up front: the screen these tests open is lazy.
import './PayoutsPage'

import { screen, waitFor, within } from '@testing-library/react'

import { getDb } from '@/api/demo/db'
import { walletFor } from '@/api/demo/db/extras'
import { formatMoney } from '@/lib/format'
import { ADMIN, renderApp, staffWith } from '@/test/render'

type User = ReturnType<typeof renderApp>['user']

async function openFirst(user: User) {
  const table = await screen.findByRole('table', { name: 'Payouts' })
  await user.click(within(table).getAllByRole('row')[1]!)
  return screen.findByRole('dialog')
}

describe('Payouts', () => {
  it('wait for a decision, newest first, with the number masked', async () => {
    renderApp('/payouts', { as: ADMIN })
    const table = await screen.findByRole('table', { name: 'Payouts' })
    const rows = within(table).getAllByRole('row').slice(1)
    expect(rows).toHaveLength(6)
    for (const row of rows) {
      expect(row).toHaveTextContent('Waiting for a decision')
      expect(row).toHaveTextContent(/\+233 24 ••• \d{4}/)
    }
  })

  it('are approved (money leaves the wallet), then marked failed (it comes back)', async () => {
    const payout = getDb()
      .withdrawals.filter((candidate) => candidate.status === 'pending')
      .sort((a, b) => b.created_at.localeCompare(a.created_at))[0]!
    const before = walletFor(payout.user_id).balance
    const { user } = renderApp(`/payouts?payout=${payout.id}`, { as: ADMIN })
    const drawer = await screen.findByRole('dialog')
    await user.click(await within(drawer).findByRole('button', { name: 'Approve payout' }))
    const approve = await screen.findByRole('alertdialog')
    expect(
      within(approve).getByText(`${formatMoney(payout.amount)} leaves their wallet now.`, {
        exact: false,
      }),
    ).toBeInTheDocument()
    expect(within(approve).getByText('Method')).toBeInTheDocument()
    await user.click(within(approve).getByRole('button', { name: 'Approve payout' }))
    expect(await screen.findByText(/Approved. Send GH₵/)).toBeInTheDocument()
    expect(walletFor(payout.user_id).balance).toBeCloseTo(before - payout.amount, 2)
    expect(await within(drawer).findByText(/Approved by you/)).toBeInTheDocument()

    await user.click(within(drawer).getByRole('button', { name: 'Mark failed' }))
    const fail = await screen.findByRole('alertdialog')
    expect(within(fail).getByRole('button', { name: 'Mark failed' })).toBeDisabled()
    await user.type(within(fail).getByRole('textbox'), 'MTN MoMo rejected the transfer.')
    await user.click(within(fail).getByRole('button', { name: 'Mark failed' }))
    expect(await screen.findByText(/is back in the wallet/)).toBeInTheDocument()
    expect(walletFor(payout.user_id).balance).toBeCloseTo(before, 2)
    expect(await within(drawer).findByText(/went back to the wallet/)).toBeInTheDocument()
  })

  it('are marked sent with the provider’s reference', async () => {
    const { user } = renderApp('/payouts?status=approved', { as: ADMIN })
    const drawer = await openFirst(user)
    await user.click(await within(drawer).findByRole('button', { name: 'Mark sent' }))
    const dialog = await screen.findByRole('alertdialog')
    await user.type(within(dialog).getByRole('textbox'), 'MP2610041234')
    await user.click(within(dialog).getByRole('button', { name: 'Mark sent' }))
    expect(await screen.findByText('Marked sent.')).toBeInTheDocument()
    expect(
      await within(drawer).findByText('Reference MP2610041234', { exact: false }),
    ).toBeInTheDocument()
  })

  it('are rejected only with a reason', async () => {
    const { user } = renderApp('/payouts', { as: ADMIN })
    const drawer = await openFirst(user)
    await user.click(await within(drawer).findByRole('button', { name: 'Reject' }))
    const dialog = await screen.findByRole('alertdialog')
    expect(within(dialog).getByRole('button', { name: 'Reject payout' })).toBeDisabled()
    await user.type(within(dialog).getByRole('textbox'), 'Wrong number on the request.')
    await user.click(within(dialog).getByRole('button', { name: 'Reject payout' }))
    expect(await screen.findByText('Payout rejected.')).toBeInTheDocument()
  })

  it('show the driver’s name only to those who may look accounts up', async () => {
    renderApp('/payouts', { as: staffWith('withdrawals:review') })
    const table = await screen.findByRole('table', { name: 'Payouts' })
    await waitFor(() => expect(within(table).getAllByText('Driver').length).toBe(6))
  })
})
