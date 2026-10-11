import { Bus, CircleDashed, CirclePause, DoorOpen, Siren, type LucideIcon } from 'lucide-react'

import type { Schemas } from '@/api/types'
import type { Tone } from '@/components/status/StatusBadge'

export type LiveTrip = Schemas['LiveTripResponse']

export type BusState = 'sos' | 'moving' | 'boarding' | 'paused' | 'stale' | 'no-gps'

export const BUS_STATES: Record<
  BusState,
  { label: string; tone: Tone; icon: LucideIcon; marker: string }
> = {
  sos: {
    label: 'SOS open',
    tone: 'danger',
    icon: Siren,
    marker: 'bg-danger text-danger-foreground',
  },
  moving: { label: 'On the road', tone: 'success', icon: Bus, marker: 'bg-brand text-white' },
  boarding: { label: 'Boarding', tone: 'info', icon: DoorOpen, marker: 'bg-chart-2 text-white' },
  paused: {
    label: 'Paused',
    tone: 'warning',
    icon: CirclePause,
    marker: 'bg-gold text-gold-foreground',
  },
  stale: {
    label: 'No recent GPS',
    tone: 'neutral',
    icon: CircleDashed,
    marker: 'bg-chart-other text-white',
  },
  'no-gps': {
    label: 'No GPS yet',
    tone: 'neutral',
    icon: CircleDashed,
    marker: 'bg-chart-other text-white',
  },
}

/** What a bus is doing, as the map and list show it. SOS wins over all. */
export function busState(trip: LiveTrip, sosTrips: ReadonlySet<string>): BusState {
  if (sosTrips.has(trip.trip_id)) return 'sos'
  if (trip.latitude === null || trip.longitude === null) return 'no-gps'
  if (trip.is_stale) return 'stale'
  if (trip.status === 'paused') return 'paused'
  if (trip.status === 'boarding') return 'boarding'
  return 'moving'
}
