import type { Schemas } from '@/api/types'
import type { Tone } from '@/components/status/StatusBadge'

export type TripStatus = Schemas['TripStatus']

const TONES: Record<TripStatus, Tone> = {
  scheduled: 'info',
  boarding: 'info',
  in_progress: 'success',
  paused: 'warning',
  completed: 'neutral',
  cancelled: 'danger',
}

export function tripStatusTone(status: TripStatus): Tone {
  return TONES[status] ?? 'neutral'
}

export const TRIP_STATUSES: TripStatus[] = [
  'scheduled',
  'boarding',
  'in_progress',
  'paused',
  'completed',
  'cancelled',
]
