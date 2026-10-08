import { AlarmClock } from 'lucide-react'

import { StatusBadge } from '@/components/status/StatusBadge'
import { formatDateTime, formatRelative } from '@/lib/format'

import type { Complaint } from './api'
import { OPEN_STATUSES } from './labels'

/** When a complaint is due, and whether it is late (open ones only). */
export function Due({
  complaint,
  now,
  prefix = '',
}: {
  complaint: Complaint
  now: number
  /** Before the time left, e.g. "Due " where no column says it. */
  prefix?: string
}) {
  if (!OPEN_STATUSES.has(complaint.status)) {
    return <span className="text-muted-foreground">Closed</span>
  }
  if (complaint.is_overdue) {
    return (
      <StatusBadge
        tone="danger"
        icon={AlarmClock}
        label={`Overdue ${formatRelative(complaint.due_at, now).replace(' ago', '')}`}
      />
    )
  }
  return (
    <span className="whitespace-nowrap" title={formatDateTime(complaint.due_at)}>
      {prefix}
      {formatRelative(complaint.due_at, now)}
    </span>
  )
}
