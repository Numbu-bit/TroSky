import { getDb } from '../db'
import { csvAnswer, endpoint, paginate } from '../http'
import {
  adminComplaint,
  cancellationRequest,
  driverResponse,
  refundRequest,
  vehicleResponse,
  withdrawal,
} from '../views'

// The backend's enum order: ascending runs low to urgent.
const PRIORITY_RANK: Record<string, number> = { low: 0, medium: 1, high: 2, urgent: 3 }

function list(value: string | null): string[] | null {
  const items = (value ?? '')
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean)
  return items.length ? items : null
}

const newestFirst = <T extends { created_at: string }>(items: T[]) =>
  [...items].sort((a, b) => b.created_at.localeCompare(a.created_at))
const oldestFirst = <T extends { created_at: string }>(items: T[]) =>
  [...items].sort((a, b) => a.created_at.localeCompare(b.created_at))

/** The queues admins work through (their actions are with each area). */
export const queueHandlers = [
  endpoint.get('/admin/drivers/pending', ['drivers:approve'], ({ url }) =>
    paginate(
      oldestFirst(getDb().drivers.filter((driver) => driver.status === 'pending')).map(
        driverResponse,
      ),
      url,
    ),
  ),

  endpoint.get('/admin/vehicles/pending', ['vehicles:approve'], ({ url }) =>
    paginate(
      oldestFirst(getDb().vehicles.filter((vehicle) => vehicle.status === 'pending')).map(
        vehicleResponse,
      ),
      url,
    ),
  ),

  endpoint.get('/admin/complaints', ['complaints:manage'], ({ url }) => {
    const statuses = list(url.searchParams.get('complaint_status'))
    const priorities = list(url.searchParams.get('priority'))
    const categories = list(url.searchParams.get('category'))
    const assignee = url.searchParams.get('assigned_to')
    const unassigned = url.searchParams.get('unassigned') === 'true'
    const overdue = url.searchParams.get('overdue')
    const sort = url.searchParams.get('sort') ?? '-created_at'
    const now = Date.now()
    let rows = getDb()
      .complaints.map((complaint) => adminComplaint(complaint, now))
      .filter(
        (row) =>
          (!statuses || statuses.includes(row.status)) &&
          (!priorities || priorities.includes(row.priority)) &&
          (!categories || categories.includes(row.category)) &&
          (!assignee || row.assigned_to === assignee) &&
          (!unassigned || row.assigned_to === null) &&
          (overdue === null || row.is_overdue === (overdue === 'true')),
      )
    const descending = sort.startsWith('-')
    const key = sort.replace(/^-/, '')
    rows = rows.sort((a, b) => {
      const order =
        key === 'priority'
          ? (PRIORITY_RANK[a.priority] ?? 9) - (PRIORITY_RANK[b.priority] ?? 9)
          : key === 'due_at'
            ? a.due_at.localeCompare(b.due_at)
            : a.created_at.localeCompare(b.created_at)
      return descending ? -order : order
    })
    if (url.searchParams.get('format') === 'csv') return csvAnswer(rows, 'complaints')
    return paginate(rows, url)
  }),

  endpoint.get('/admin/refund-requests', ['refunds:approve'], ({ url }) => {
    const status = url.searchParams.get('refund_status')
    return paginate(
      newestFirst(getDb().refunds)
        .filter((refund) => !status || refund.status === status)
        .map(refundRequest),
      url,
    )
  }),

  endpoint.get('/admin/cancellation-requests', ['refunds:approve'], ({ url }) => {
    const status = url.searchParams.get('request_status')
    return paginate(
      newestFirst(getDb().cancellations)
        .filter((request) => !status || request.status === status)
        .map(cancellationRequest),
      url,
    )
  }),

  endpoint.get('/admin/withdrawals', ['withdrawals:review'], ({ url }) => {
    const status = url.searchParams.get('withdrawal_status')
    const rows = newestFirst(getDb().withdrawals)
      .filter((record) => !status || record.status === status)
      .map(withdrawal)
    if (url.searchParams.get('format') === 'csv') return csvAnswer(rows, 'withdrawals')
    return paginate(rows, url)
  }),
]
