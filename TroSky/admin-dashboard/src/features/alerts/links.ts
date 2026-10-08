import type { Schemas } from '@/api/types'
import type { Tone } from '@/components/status/StatusBadge'

export type Alert = Schemas['AlertResponse']

export const SEVERITY_TONE: Record<string, Tone> = {
  critical: 'danger',
  high: 'danger',
  medium: 'warning',
  low: 'info',
}

export const ALERT_TYPES: Record<Alert['type'], string> = {
  sos_active: 'SOS not acknowledged',
  complaint_overdue: 'Complaints overdue',
  document_expiring: 'Documents running out',
  approval_waiting: 'Approvals waiting too long',
  fraud_high_risk: 'High-risk fraud flags',
}

/** Where each alert is dealt with. */
export function alertLink(alert: Alert): string {
  switch (alert.entity_type) {
    case 'sos_alert':
      return `/safety?status=open&alert=${alert.entity_id}`
    case 'complaint':
      return `/complaints/${alert.entity_id}`
    case 'driver':
      return alert.type === 'approval_waiting'
        ? `/approvals?queue=drivers&id=${alert.entity_id}`
        : `/fleet/drivers/${alert.entity_id}`
    case 'vehicle':
      return alert.type === 'approval_waiting'
        ? `/approvals?queue=vehicles&id=${alert.entity_id}`
        : `/fleet/vehicles/${alert.entity_id}`
    case 'fraud_flag':
      return `/fraud/${alert.entity_id}`
    default:
      return '/alerts'
  }
}
