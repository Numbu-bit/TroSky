// Loaded up front: the screens these tests open are lazy.
import './ComplaintsScreen'

import { screen, waitFor, within } from '@testing-library/react'

import { getDb } from '@/api/demo/db'
import { ADMIN, renderApp, STAFF, SUPER_ADMIN } from '@/test/render'

type User = ReturnType<typeof renderApp>['user']

/** An open complaint nobody has taken yet. */
function openComplaint() {
  const complaint = getDb().complaints.find(
    (candidate) => candidate.status === 'open' && !candidate.assigned_to,
  )
  if (!complaint) throw new Error('No open complaint in the demo data')
  return complaint
}

async function decide(user: User, button: 'Resolve' | 'Dismiss', note: string) {
  await user.click(screen.getByRole('button', { name: button }))
  const dialog = await screen.findByRole('alertdialog')
  expect(within(dialog).getByRole('button', { name: button })).toBeDisabled()
  await user.type(within(dialog).getByRole('textbox'), note)
  await user.click(within(dialog).getByRole('button', { name: button }))
}

describe('Complaints', () => {
  it('show what is open and overdue; the tiles filter the list', async () => {
    const { user, router } = renderApp('/complaints', { as: ADMIN })
    const figures = await screen.findByRole('region', { name: 'Complaint figures' })
    const overdue = within(figures).getByRole('button', { name: /Overdue/ })
    const count = Number(/\d+/.exec(overdue.textContent!)![0])
    await user.click(overdue)
    await waitFor(() => expect(router.state.location.search).toContain('overdue=yes'))
    await waitFor(() => {
      const rows = within(screen.getByRole('table', { name: 'Complaints' })).getAllByRole('row')
      expect(rows.length - 1).toBe(Math.min(count, 20))
      for (const row of rows.slice(1)) expect(row).toHaveTextContent(/Overdue/)
    })
  })

  it('are taken, given a priority and reviewed', async () => {
    const complaint = openComplaint()
    const { user } = renderApp(`/complaints/${complaint.id}`, { as: STAFF })
    expect(await screen.findByRole('heading', { name: complaint.subject })).toBeInTheDocument()

    await user.click(screen.getByRole('button', { name: 'Take it' }))
    expect(await screen.findByText('It’s yours.')).toBeInTheDocument()
    expect(await screen.findByRole('button', { name: 'Give it back' })).toBeInTheDocument()

    await user.click(screen.getByRole('combobox', { name: 'Priority' }))
    await user.click(await screen.findByRole('option', { name: 'Urgent' }))
    expect(await screen.findByText(/Priority set to urgent/)).toBeInTheDocument()

    await user.click(screen.getByRole('button', { name: 'Start review' }))
    expect(await screen.findByText('Review started.')).toBeInTheDocument()
    expect(await screen.findByText('In review', { selector: 'span' })).toBeInTheDocument()
  })

  it('are assigned to anyone on the team who handles complaints', async () => {
    const complaint = openComplaint()
    const { user } = renderApp(`/complaints/${complaint.id}`, { as: SUPER_ADMIN })
    await user.click(await screen.findByRole('combobox', { name: 'With' }))
    // Akosua Darko reviews payouts, not complaints: she isn't offered.
    expect(screen.queryByRole('option', { name: /Akosua Darko/ })).not.toBeInTheDocument()
    await user.click(await screen.findByRole('option', { name: 'Yaw Boateng' }))
    expect(await screen.findByText('Assigned.')).toBeInTheDocument()
  })

  it('keep internal notes apart from messages to the passenger', async () => {
    const complaint = openComplaint()
    const { user } = renderApp(`/complaints/${complaint.id}`, { as: ADMIN })
    const box = await screen.findByLabelText('Note')
    await user.type(box, 'Checked the trip log: the driver skipped Lapaz.')
    await user.click(screen.getByRole('button', { name: 'Add note' }))
    expect(await screen.findByText('Note added.')).toBeInTheDocument()

    await user.click(screen.getByLabelText('Message to the passenger'))
    await user.type(
      screen.getByLabelText('Message'),
      'Sorry about this. We have spoken to the driver.',
    )
    await user.click(screen.getByRole('button', { name: 'Send message' }))
    expect(await screen.findByText('Sent to the passenger.')).toBeInTheDocument()

    const thread = screen.getByRole('region', { name: 'Notes and messages' })
    const items = await within(thread).findAllByRole('listitem')
    expect(items).toHaveLength(2)
    expect(items[0]).toHaveTextContent('Internal note')
    expect(items[1]).toHaveTextContent('Sent to the passenger')
  })

  it('are resolved with a note, then closed to changes', async () => {
    const complaint = openComplaint()
    const { user } = renderApp(`/complaints/${complaint.id}`, { as: ADMIN })
    await screen.findByRole('heading', { name: complaint.subject })
    await decide(user, 'Resolve', 'Refunded the extra fare and warned the mate.')
    expect(await screen.findByText('Complaint resolved.')).toBeInTheDocument()
    expect(await screen.findByText('How it was resolved')).toBeInTheDocument()
    expect(screen.getByText('Refunded the extra fare and warned the mate.')).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'Resolve' })).not.toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'Start review' })).not.toBeInTheDocument()
  })

  it('are dismissed with a note', async () => {
    const complaint = openComplaint()
    const { user } = renderApp(`/complaints/${complaint.id}`, { as: ADMIN })
    await screen.findByRole('heading', { name: complaint.subject })
    await decide(user, 'Dismiss', 'A duplicate of an earlier complaint.')
    expect(await screen.findByText('Complaint dismissed.')).toBeInTheDocument()
    expect(await screen.findByText('Why it was dismissed')).toBeInTheDocument()
  })

  it('say so when one doesn’t exist', async () => {
    renderApp('/complaints/00000000-0000-4000-8000-000000000000', { as: ADMIN })
    expect(await screen.findByText('Complaint not found')).toBeInTheDocument()
  })
})
