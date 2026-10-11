// Loaded up front: the screen these tests open is lazy.
import './AuditLogScreen'

import { screen, waitFor, within } from '@testing-library/react'

import { api } from '@/api/client'
import { getDb } from '@/api/demo/db'
import { ADMIN, renderApp, signInAs } from '@/test/render'

const entryRows = () =>
  within(screen.getByRole('table', { name: 'Audit log' }))
    .getAllByRole('row')
    .slice(1)

describe('Audit log', () => {
  it('records an approval: who, why, and the values before and after', async () => {
    const driver = getDb().drivers.find((candidate) => candidate.status === 'pending')!
    const before = driver.status
    signInAs(ADMIN)
    await api.POST('/api/v1/admin/drivers/{driver_id}/approve', {
      params: { path: { driver_id: driver.id } },
      body: { notes: 'Licence checked with the DVLA.' },
    })

    const { user, router } = renderApp('/audit-log', { as: ADMIN })
    await screen.findByRole('table', { name: 'Audit log' })
    const first = entryRows()[0]!
    expect(first).toHaveTextContent('Approve driver')
    expect(first).toHaveTextContent(ADMIN.full_name)
    expect(first).toHaveTextContent('Drivers')
    expect(first).toHaveTextContent('Licence checked with the DVLA.')

    await user.click(within(first).getByRole('button', { name: 'Approve driver' }))
    await waitFor(() => expect(router.state.location.search).toMatch(/^\?entry=[\w-]+$/))
    const drawer = await screen.findByRole('dialog', { name: 'Approve driver' })
    const changes = await within(drawer).findByRole('table', { name: 'Values before and after' })
    const status = within(changes).getByRole('row', { name: /^status/ })
    expect(
      within(status)
        .getAllByRole('cell')
        .map((cell) => cell.textContent),
    ).toEqual([before, 'approved'])
  })

  it('filters by the kind of record, kept in the address', async () => {
    const { user, router } = renderApp('/audit-log', { as: ADMIN })
    await screen.findByRole('table', { name: 'Audit log' })
    await user.click(screen.getByRole('combobox', { name: 'Record' }))
    await user.click(await screen.findByRole('option', { name: 'Settings' }))
    await waitFor(() =>
      expect(router.state.location.search).toContain('entity_type=system_settings'),
    )
    await waitFor(() => {
      const rows = entryRows()
      expect(rows.length).toBeGreaterThan(0)
      for (const row of rows) expect(row).toHaveTextContent('Settings')
    })
  })
})
