import { Bus, CircleDashed, CircleDot, type LucideIcon } from 'lucide-react'

import type { Schemas } from '@/api/types'
import type { Tone } from '@/components/status/StatusBadge'

export type LiveStatus = 'on_trip' | 'idle' | 'offline'

export const LIVE: Record<LiveStatus, { tone: Tone; label: string; icon: LucideIcon }> = {
  on_trip: { tone: 'success', label: 'On a trip', icon: Bus },
  idle: { tone: 'info', label: 'Free', icon: CircleDot },
  offline: { tone: 'neutral', label: 'Offline', icon: CircleDashed },
}

export const APPROVAL: Record<Schemas['ApprovalStatus'], { tone: Tone; label: string }> = {
  pending: { tone: 'warning', label: 'Waiting for approval' },
  under_review: { tone: 'info', label: 'Being reviewed' },
  approved: { tone: 'success', label: 'Approved' },
  rejected: { tone: 'danger', label: 'Rejected' },
  suspended: { tone: 'danger', label: 'Suspended' },
  expired: { tone: 'warning', label: 'Documents expired' },
}

/** The select value meaning "no filter". */
export const ANY = 'any'
