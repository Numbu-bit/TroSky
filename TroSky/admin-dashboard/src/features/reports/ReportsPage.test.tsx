// Loaded up front: the screen these tests open is lazy.
import './ReportsPage'

import { screen, waitFor, within } from '@testing-library/react'

import { ADMIN, renderApp } from '@/test/render'

/** The files the page hands the browser to save. */
function captureDownloads() {
  const click = vi.spyOn(HTMLAnchorElement.prototype, 'click').mockImplementation(() => {})
  onTestFinished(() => click.mockRestore())
  return () => click.mock.contexts.map((anchor) => (anchor as HTMLAnchorElement).download)
}

describe('Reports', () => {
  it('shows the daily rides report with its totals', async () => {
    renderApp('/reports', { as: ADMIN })
    const report = await screen.findByRole('region', { name: 'Daily rides' })
    const table = within(report).getByRole('table', { name: 'Daily rides' })
    const rows = within(table).getAllByRole('row')
    // The header, a row a day for 30 days, and the totals.
    expect(rows).toHaveLength(32)
    expect(rows.at(-1)).toHaveTextContent(/^Total/)
  })

  it('switches report, kept in the address', async () => {
    const { user, router } = renderApp('/reports', { as: ADMIN })
    await screen.findByRole('region', { name: 'Daily rides' })
    expect(screen.getByRole('combobox', { name: 'Rows per' })).toBeInTheDocument()
    await user.click(screen.getByRole('combobox', { name: 'Report' }))
    await user.click(await screen.findByRole('option', { name: 'Peak hours' }))
    await waitFor(() => expect(router.state.location.search).toContain('report=peak_hours'))
    expect(await screen.findByRole('region', { name: 'Peak hours' })).toBeInTheDocument()
    // Hours are not a series: no rows per day, week or month.
    expect(screen.queryByRole('combobox', { name: 'Rows per' })).toBeNull()
  })

  it('downloads as CSV and Excel, and prints as PDF', async () => {
    const downloads = captureDownloads()
    const print = vi.spyOn(window, 'print').mockImplementation(() => {})
    onTestFinished(() => print.mockRestore())
    const { user } = renderApp('/reports', { as: ADMIN })
    await screen.findByRole('region', { name: 'Daily rides' })

    await user.click(screen.getByRole('button', { name: 'CSV' }))
    await waitFor(() => expect(downloads()).toHaveLength(1))
    expect(downloads()[0]).toMatch(/^daily-rides-\d{4}-\d{2}-\d{2}-\d{4}-\d{2}-\d{2}\.csv$/)

    await user.click(screen.getByRole('button', { name: 'Excel' }))
    expect(downloads()[1]).toMatch(/^daily-rides-.*\.xlsx$/)

    await user.click(screen.getByRole('button', { name: 'PDF' }))
    expect(print).toHaveBeenCalledOnce()
  })
})
