// Loaded up front: the screens these tests open are lazy.
import './WalletsPage'
import '@/features/payouts/PayoutsPage'

import { screen, waitFor, within } from '@testing-library/react'

import { getDb } from '@/api/demo/db'
import { walletFor } from '@/api/demo/db/extras'
import { formatMoney } from '@/lib/format'
import { ADMIN, renderApp } from '@/test/render'

const person = () =>
  getDb().users.find((user) => user.roles.includes('passenger') && user.full_name)!

/** The "Adjust the balance" card, where its own problems show. */
const adjustCard = () =>
  screen.getByText('Adjust the balance').closest<HTMLElement>('[data-slot="card"]')!

describe('Wallets', () => {
  it('are found by name, then opened', async () => {
    const owner = person()
    const { user, router } = renderApp('/wallets', { as: ADMIN })
    await user.type(await screen.findByLabelText('Whose wallet'), owner.full_name!)
    const found = await screen.findByRole('list', { name: 'Accounts found' })
    await user.click(within(found).getByRole('link', { name: new RegExp(owner.full_name!) }))
    await waitFor(() => expect(router.state.location.pathname).toBe(`/wallets/${owner.id}`))
    expect(
      await screen.findByRole('heading', { name: `${owner.full_name}’s wallet` }),
    ).toBeInTheDocument()
    // The name typed never reaches the address.
    expect(router.state.location.search).toBe('')
  })

  it('are adjusted with a reason, after a check', async () => {
    const owner = person()
    const before = walletFor(owner.id).balance
    const { user } = renderApp(`/wallets/${owner.id}`, { as: ADMIN })
    const amount = await screen.findByLabelText('Amount (GH₵)')
    const reason = screen.getByLabelText('Why (kept on the transaction)')

    await user.type(amount, '25')
    await user.type(reason, 'Bus')
    await user.click(screen.getByRole('button', { name: 'Add money' }))
    expect(within(adjustCard()).getByRole('alert')).toHaveTextContent(
      'Say why, in at least 5 characters.',
    )

    await user.type(reason, ' broke down on the way')
    await user.click(screen.getByRole('button', { name: 'Add money' }))
    const dialog = await screen.findByRole('alertdialog', {
      name: `Add ${formatMoney(25)} to ${owner.full_name}’s wallet?`,
    })
    expect(within(dialog).getByText(formatMoney(before + 25))).toBeInTheDocument()
    await user.click(within(dialog).getByRole('button', { name: 'Add money' }))
    expect(
      await screen.findByText(`Done. The balance is now ${formatMoney(before + 25)}.`),
    ).toBeInTheDocument()
    expect(walletFor(owner.id).balance).toBeCloseTo(before + 25, 2)
    const table = await screen.findByRole('table', { name: 'Wallet transactions' })
    expect(within(table).getAllByRole('row')[1]).toHaveTextContent('Adjusted by an admin')
  })

  it('can’t give away more than the wallet holds', async () => {
    const owner = person()
    const { user } = renderApp(`/wallets/${owner.id}`, { as: ADMIN })
    await user.click(await screen.findByRole('radio', { name: 'Take money' }))
    await user.type(screen.getByLabelText('Amount (GH₵)'), '999999')
    await user.type(screen.getByLabelText('Why (kept on the transaction)'), 'Reversing a top-up')
    await user.click(screen.getByRole('button', { name: 'Take money' }))
    expect(within(adjustCard()).getByRole('alert')).toHaveTextContent(
      `The wallet holds only ${formatMoney(walletFor(owner.id).balance)}.`,
    )
    expect(screen.queryByRole('alertdialog')).toBeNull()
  })

  it('open from a payout', async () => {
    const payout = getDb().withdrawals.find((candidate) => candidate.status === 'pending')!
    renderApp(`/payouts?payout=${payout.id}`, { as: ADMIN })
    const drawer = await screen.findByRole('dialog')
    expect(await within(drawer).findByRole('link', { name: 'Open their wallet' })).toHaveAttribute(
      'href',
      `/wallets/${payout.user_id}`,
    )
  })

  it('say so when the account doesn’t exist', async () => {
    renderApp('/wallets/00000000-0000-4000-8000-000000000000', { as: ADMIN })
    expect(await screen.findByText('No such account')).toBeInTheDocument()
  })
})
