import { CircleAlert, CircleCheck, CircleSlash, Eye, type LucideIcon } from 'lucide-react'

import type { Tone } from '@/components/status/StatusBadge'

import type { ComplaintCategory, ComplaintPriority, ComplaintStatus } from './api'

export const COMPLAINT_STATUS: Record<
  ComplaintStatus,
  { tone: Tone; label: string; icon: LucideIcon }
> = {
  open: { tone: 'warning', label: 'Open', icon: CircleAlert },
  in_review: { tone: 'info', label: 'In review', icon: Eye },
  resolved: { tone: 'success', label: 'Resolved', icon: CircleCheck },
  dismissed: { tone: 'neutral', label: 'Dismissed', icon: CircleSlash },
}

export const PRIORITY: Record<ComplaintPriority, { tone: Tone; label: string }> = {
  urgent: { tone: 'danger', label: 'Urgent' },
  high: { tone: 'warning', label: 'High' },
  medium: { tone: 'info', label: 'Medium' },
  low: { tone: 'neutral', label: 'Low' },
}

export const PRIORITIES: ComplaintPriority[] = ['urgent', 'high', 'medium', 'low']

export const CATEGORY: Record<ComplaintCategory, string> = {
  driver_conduct: 'Driver conduct',
  vehicle_condition: 'Vehicle condition',
  safety: 'Safety',
  payment: 'Payment',
  other: 'Other',
}

export const NOT_CLOSED = 'open,in_review'
export const OPEN_STATUSES = new Set<ComplaintStatus>(['open', 'in_review'])
