// Loaded up front: the screen these tests open is lazy.
import './FraudScreen'

import { screen, waitFor, within } from '@testing-library/react'

import { walletFor } from '@/api/demo/db/extras'
import { fraudState, OPEN_FLAGS } from '@/api/demo/db/fraud'
import { ADMIN, renderApp, staffWith } from '@/test/render'

const flagRows = () =>
  within(screen.getByRole('table', { name: 'Fraud flags' }))
    .getAllByRole('row')
    .slice(1)

/** An open flag about an account whose wallet isn't frozen. */
function openFlag() {
  const flag = fraudState().flags.find(
    (candidate) =>
      OPEN_FLAGS.has(candidate.status) &&
      candidate.subject_user_id &&
      !walletFor(candidate.subject_user_id).frozen_at,
  )
  if (!flag) throw new Error('No such flag in the demo data')
  return flag
}

describe('Fraud & risk', () => {
  it('lists the open flags, riskiest first', async () => {
    renderApp('/fraud', { as: ADMIN })
    await screen.findByRole('table', { name: 'Fraud flags' })
    expect(screen.getByRole('region', { name: 'Fraud figures' })).toBeInTheDocument()
    const risks = flagRows().map((row) =>
      Number(within(row).getByRole('img', { name: /^Risk \d+ of 100/ }).textContent),
    )
    expect(risks.length).toBeGreaterThan(1)
    expect(risks).toEqual([...risks].sort((a, b) => b - a))
    for (const row of flagRows()) expect(row).toHaveTextContent(/Open|Being looked into/)
  })

  it('confirms fraud only with a reason', async () => {
    const flag = openFlag()
    const { user } = renderApp(`/fraud/${flag.id}`, { as: ADMIN })
    expect(await screen.findByRole('heading', { name: flag.summary })).toBeInTheDocument()
    await user.click(screen.getByRole('button', { name: 'Confirm fraud' }))
    const dialog = await screen.findByRole('alertdialog')
    expect(within(dialog).getByRole('button', { name: 'Confirm fraud' })).toBeDisabled()
    await user.type(within(dialog).getByRole('textbox'), 'Same card on six accounts.')
    await user.click(within(dialog).getByRole('button', { name: 'Confirm fraud' }))
    expect(await screen.findByText('Confirmed as fraud.')).toBeInTheDocument()
    expect(await screen.findByRole('button', { name: 'Reopen' })).toBeInTheDocument()
    expect(screen.getByText(/^Reviewed .*: “Same card on six accounts.”$/)).toBeInTheDocument()
  })

  it('freezes the wallet of the account, with a reason, and links to it', async () => {
    const flag = openFlag()
    const { user } = renderApp(`/fraud/${flag.id}`, { as: ADMIN })
    await user.click(await screen.findByRole('button', { name: 'Freeze the wallet' }))
    const dialog = await screen.findByRole('alertdialog')
    await user.type(within(dialog).getByRole('textbox'), 'Money moved out within minutes.')
    await user.click(within(dialog).getByRole('button', { name: 'Freeze the wallet' }))
    expect(
      await screen.findByText('Wallet frozen: no payments or payouts leave it.'),
    ).toBeInTheDocument()
    await waitFor(() => expect(walletFor(flag.subject_user_id!).frozen_at).not.toBeNull())
    expect(await screen.findByRole('button', { name: 'Unfreeze the wallet' })).toBeInTheDocument()
    const linked = screen.getByRole('region', { name: 'Linked to' })
    expect(within(linked).getByText('Wallet frozen')).toBeInTheDocument()
    expect(
      within(linked)
        .getAllByRole('link', { name: 'Wallet' })
        .map((link) => link.getAttribute('href')),
    ).toContain(`/wallets/${flag.subject_user_id}`)
  })

  it('changes a rule, checking it first, and runs the checks', async () => {
    const { user } = renderApp('/fraud/rules', { as: ADMIN })
    const table = await screen.findByRole('table', { name: 'Fraud rules' })
    await user.click(within(table).getAllByRole('button', { name: /^Edit / })[0]!)
    const dialog = await screen.findByRole('dialog')
    const threshold = within(dialog).getByLabelText(/^Threshold/)
    await user.clear(threshold)
    await user.type(threshold, '0')
    await user.click(within(dialog).getByRole('button', { name: 'Save rule' }))
    expect(within(dialog).getByRole('alert')).toHaveTextContent(
      'The threshold must be a number above 0.',
    )
    await user.clear(threshold)
    await user.type(threshold, '4')
    await user.type(within(dialog).getByLabelText('Why (for the audit log)'), 'Too noisy.')
    await user.click(within(dialog).getByRole('button', { name: 'Save rule' }))
    expect(await screen.findByText(/” saved\.$/)).toBeInTheDocument()

    await user.click(screen.getByRole('button', { name: 'Run the checks now' }))
    expect(await screen.findByText(/^Checks done: /)).toBeInTheDocument()
  })

  it('keeps the rules and actions from those who may only look', async () => {
    const flag = openFlag()
    const viewer = staffWith('fraud:view')
    const { router } = renderApp('/fraud/rules', { as: viewer })
    await screen.findByRole('table', { name: 'Fraud flags' })
    expect(router.state.location.pathname).toBe('/fraud')
    expect(screen.queryByRole('link', { name: 'Rules' })).toBeNull()

    await router.navigate(`/fraud/${flag.id}`)
    expect(await screen.findByRole('heading', { name: flag.summary })).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'Confirm fraud' })).toBeNull()
    expect(screen.queryByRole('button', { name: 'Freeze the wallet' })).toBeNull()
  })
})
