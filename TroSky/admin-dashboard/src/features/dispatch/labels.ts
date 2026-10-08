import {
  BadgeCheck,
  BadgeX,
  CirclePause,
  CirclePlay,
  Flag,
  LogOut,
  PlayCircle,
  ScanLine,
  TimerOff,
  ThumbsDown,
  ThumbsUp,
  type LucideIcon,
} from 'lucide-react'

import type { Tone } from '@/components/status/StatusBadge'

import type { ActedAs, ActionKind } from './api'

export const ACTION_KINDS: Record<ActionKind, { label: string; tone: Tone; icon: LucideIcon }> = {
  trip_accepted: { label: 'Accepted the trip', tone: 'success', icon: ThumbsUp },
  trip_declined: { label: 'Declined the trip', tone: 'danger', icon: ThumbsDown },
  trip_started: { label: 'Started the trip', tone: 'info', icon: PlayCircle },
  trip_paused: { label: 'Paused', tone: 'warning', icon: CirclePause },
  trip_resumed: { label: 'Resumed', tone: 'info', icon: CirclePlay },
  trip_ended: { label: 'Ended the trip', tone: 'neutral', icon: Flag },
  booking_accepted: { label: 'Accepted a booking', tone: 'success', icon: BadgeCheck },
  booking_declined: { label: 'Declined a booking', tone: 'danger', icon: BadgeX },
  booking_unanswered: { label: 'Left a booking unanswered', tone: 'warning', icon: TimerOff },
  ticket_scanned: { label: 'Scanned a ticket', tone: 'neutral', icon: ScanLine },
  passenger_alighted: { label: 'Marked a passenger off', tone: 'neutral', icon: LogOut },
}

export const ACTED_AS: Record<ActedAs, string> = {
  driver: 'The driver',
  admin: 'An admin, for the driver',
  system: 'The system',
}
