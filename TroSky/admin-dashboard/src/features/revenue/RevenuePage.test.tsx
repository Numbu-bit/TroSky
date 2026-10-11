// Loaded up front: the screens these tests open are lazy.
import './RevenuePage'
import '@/app/layout/SearchDialog'

import { screen, waitFor, within } from '@testing-library/react'

import { getDb } from '@/api/demo/db'
import { paymentReference } from '@/api/demo/handlers/bookings'
import { accraDateKey } from '@/lib/format'
import { ADMIN, renderApp } from '@/test/render'

const DAY = 86_400_000

const paymentRows = () =>
  within(screen.getByRole('table', { name: 'Payments' }))
    .getAllByRole('row')
    .slice(1)

describe('Revenue', () => {
  it('shows money in and out, and the payments in the period', async () => {
    renderApp('/revenue', { as: ADMIN })
    expect(await screen.findByText('Gross')).toBeInTheDocument()
    for (const tile of ['Refunds paid', 'Net', 'Platform fees', 'Payouts waiting']) {
      expect(screen.getByText(tile)).toBeInTheDocument()
    }
    expect(screen.getByText('By payment method')).toBeInTheDocument()
    await screen.findByRole('table', { name: 'Payments' })
    expect(paymentRows().length).toBeGreaterThan(1)
  })

  it('filters payments by status, kept in the address', async () => {
    const { user, router } = renderApp('/revenue', { as: ADMIN })
    await screen.findByRole('table', { name: 'Payments' })
    await user.click(screen.getByRole('combobox', { name: 'Status' }))
    await user.click(await screen.findByRole('option', { name: 'Paid' }))
    await waitFor(() => expect(router.state.location.search).toContain('status=successful'))
    await waitFor(() => {
      const rows = paymentRows()
      expect(rows.length).toBeGreaterThan(0)
      for (const row of rows) expect(row).toHaveTextContent('Paid')
    })
  })

  it('finds a payment from the global search, even before the period shown', async () => {
    const payment = getDb().payments.find(
      (candidate) =>
        candidate.booking_id && Date.parse(candidate.created_at) < Date.now() - 45 * DAY,
    )!
    const reference = paymentReference(payment)
    const { user, router } = renderApp('/overview', { as: ADMIN })
    await user.click(await screen.findByRole('button', { name: 'Search' }))
    const dialog = await screen.findByRole('dialog', { name: 'Search' })
    await user.type(within(dialog).getByRole('combobox', { name: 'Search' }), reference)
    await user.click(await within(dialog).findByRole('option', { name: new RegExp(reference) }))

    await waitFor(() => expect(router.state.location.pathname).toBe('/revenue'))
    // The period moves to the payment's day; the reference is not in the address.
    const day = accraDateKey(payment.created_at)
    await waitFor(() =>
      expect(router.state.location.search).toBe(`?days=custom&from=${day}&to=${day}`),
    )
    expect(screen.getByRole('searchbox', { name: 'Find' })).toHaveValue(reference)
    await waitFor(() => {
      const rows = paymentRows()
      expect(rows).toHaveLength(1)
      expect(rows[0]).toHaveTextContent(reference)
    })
  })
})
