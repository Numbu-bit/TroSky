import { CircleCheck, Eye, Siren, ShieldQuestion, type LucideIcon } from 'lucide-react'

import type { Schemas } from '@/api/types'
import type { Tone } from '@/components/status/StatusBadge'

export const SOS_STATUS: Record<
  Schemas['SosAlertStatus'],
  { label: string; tone: Tone; icon: LucideIcon }
> = {
  active: { label: 'Not acknowledged', tone: 'danger', icon: Siren },
  acknowledged: { label: 'Acknowledged', tone: 'warning', icon: Eye },
  resolved: { label: 'Resolved', tone: 'success', icon: CircleCheck },
  false_alarm: { label: 'False alarm', tone: 'neutral', icon: ShieldQuestion },
}

export const INCIDENT_STATUS: Record<Schemas['IncidentStatus'], { label: string; tone: Tone }> = {
  reported: { label: 'Reported', tone: 'warning' },
  in_review: { label: 'In review', tone: 'info' },
  resolved: { label: 'Resolved', tone: 'success' },
  closed: { label: 'Closed', tone: 'neutral' },
}

export const SEVERITY_TONE: Record<Schemas['IncidentSeverity'], Tone> = {
  critical: 'danger',
  high: 'danger',
  medium: 'warning',
  low: 'info',
}

export const ESCALATION_TYPES: { value: Schemas['EscalationContactType']; label: string }[] = [
  { value: 'police', label: 'Police' },
  { value: 'ambulance', label: 'Ambulance' },
  { value: 'fire_service', label: 'Fire service' },
  { value: 'fleet_owner', label: 'Fleet owner' },
  { value: 'emergency_contact', label: 'Rider’s emergency contact' },
  { value: 'other', label: 'Other' },
]
