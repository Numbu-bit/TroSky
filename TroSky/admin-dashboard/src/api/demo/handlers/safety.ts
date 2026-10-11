import type { Schemas } from '@/api/types'

import { getDb, touch } from '../db'
import type { SosRec } from '../db/model'
import { Random } from '../random'
import { csvAnswer, endpoint, errorResponse, notFound, paginate } from '../http'
import { incident, sosAlert, sosDetail } from '../views'

const ids = new Random(77)

function findAlert(id: string | undefined): SosRec | undefined {
  return getDb().sosAlerts.find((alert) => alert.id === id)
}

function newestFirst<T extends { created_at: string }>(items: T[]): T[] {
  return [...items].sort((a, b) => b.created_at.localeCompare(a.created_at))
}

export const safetyHandlers = [
  // ----------------------------------------------------------------- SOS
  endpoint.get('/admin/sos-alerts', ['sos:review'], ({ url }) => {
    const status = url.searchParams.get('alert_status')
    const alerts = newestFirst(getDb().sosAlerts).filter(
      (alert) => !status || alert.status === status,
    )
    return paginate(alerts.map(sosAlert), url)
  }),

  endpoint.get('/admin/sos-alerts/:alertId', ['sos:review'], ({ params }) => {
    const alert = findAlert(params.alertId)
    return alert ? sosDetail(alert) : notFound('SOS alert not found.')
  }),

  endpoint.get('/sos/:alertId', 'team', ({ params }) => {
    const alert = findAlert(params.alertId)
    return alert ? sosAlert(alert) : notFound('SOS alert not found.')
  }),

  endpoint.post('/admin/sos-alerts/:alertId/acknowledge', ['sos:review'], ({ params, admin }) => {
    const alert = findAlert(params.alertId)
    if (!alert) return notFound('SOS alert not found.')
    if (alert.status !== 'active') {
      return errorResponse(
        409,
        'INVALID_STATE_TRANSITION',
        `Cannot acknowledge an SOS alert in status '${alert.status}'.`,
      )
    }
    alert.status = 'acknowledged'
    alert.acknowledged_by = admin.id
    alert.acknowledged_at = new Date().toISOString()
    touch()
    return sosAlert(alert)
  }),

  endpoint.post('/admin/sos-alerts/:alertId/resolve', ['sos:review'], ({ params, admin, body }) => {
    const alert = findAlert(params.alertId)
    if (!alert) return notFound('SOS alert not found.')
    if (alert.status !== 'active' && alert.status !== 'acknowledged') {
      return errorResponse(
        409,
        'INVALID_STATE_TRANSITION',
        `Cannot resolve an SOS alert in status '${alert.status}'.`,
      )
    }
    const { notes = null, false_alarm = false } = (body ?? {}) as Schemas['SosDecisionRequest']
    const now = new Date().toISOString()
    alert.status = false_alarm ? 'false_alarm' : 'resolved'
    alert.resolved_by = admin.id
    alert.resolved_at = now
    alert.resolution_notes = notes ?? null
    alert.acknowledged_by ??= admin.id
    alert.acknowledged_at ??= now
    touch()
    return sosAlert(alert)
  }),

  endpoint.post(
    '/admin/sos-alerts/:alertId/escalations',
    ['sos:review'],
    ({ params, admin, body }) => {
      const alert = findAlert(params.alertId)
      if (!alert) return notFound('SOS alert not found.')
      const request = body as Schemas['SosEscalationRequest']
      const now = new Date().toISOString()
      const escalation = {
        id: ids.uuid(),
        contact_type: request.contact_type,
        contact_name: request.contact_name ?? null,
        phone_number: request.phone_number ?? null,
        contacted_at: request.contacted_at ?? now,
        notes: request.notes ?? null,
        logged_by: admin.id,
        created_at: now,
      }
      alert.escalations.push(escalation)
      touch()
      return {
        ...escalation,
        sos_alert_id: alert.id,
        logged_by_name: admin.full_name,
      } satisfies Schemas['SosEscalationResponse']
    },
  ),

  // ------------------------------------------------------------ incidents
  endpoint.get('/admin/incidents', ['incidents:manage'], ({ url }) => {
    const status = url.searchParams.get('incident_status')
    const rows = newestFirst(getDb().incidents)
      .filter((record) => !status || record.status === status)
      .map(incident)
    if (url.searchParams.get('format') === 'csv') return csvAnswer(rows, 'incidents')
    return paginate(rows, url)
  }),

  endpoint.get('/incidents/:incidentId', 'team', ({ params }) => {
    const record = getDb().incidents.find((candidate) => candidate.id === params.incidentId)
    return record ? incident(record) : notFound('Incident not found.')
  }),

  endpoint.post(
    '/admin/incidents/:incidentId/resolve',
    ['incidents:manage'],
    ({ params, admin, body }) => {
      const record = getDb().incidents.find((candidate) => candidate.id === params.incidentId)
      if (!record) return notFound('Incident not found.')
      if (record.status === 'resolved' || record.status === 'closed') {
        return errorResponse(
          409,
          'INVALID_STATE_TRANSITION',
          `Cannot resolve an incident already in status '${record.status}'.`,
        )
      }
      record.status = 'resolved'
      record.resolved_by = admin.id
      record.resolved_at = new Date().toISOString()
      record.resolution_notes =
        (body as Schemas['IncidentDecisionRequest'] | undefined)?.notes ?? null
      touch()
      return incident(record)
    },
  ),
]

/** Demo menu: an SOS from a bus on the road, to see the alarm. */
export function raiseDemoSos(): SosRec {
  const db = getDb()
  const trip = db.trips.find((candidate) => candidate.live && candidate.status === 'in_progress')!
  const rider = db.bookings.find((booking) => booking.trip_id === trip.id)
  const alert: SosRec = {
    id: ids.uuid(),
    trip_id: trip.id,
    triggered_by: rider?.passenger_id ?? db.users[0]!.id,
    status: 'active',
    latitude: null,
    longitude: null,
    acknowledged_by: null,
    acknowledged_at: null,
    resolved_by: null,
    resolved_at: null,
    resolution_notes: null,
    created_at: new Date().toISOString(),
    escalations: [],
  }
  const detail = sosDetail(alert)
  alert.latitude = detail.trip?.last_position?.latitude ?? 5.6
  alert.longitude = detail.trip?.last_position?.longitude ?? -0.2
  db.sosAlerts.push(alert)
  touch()
  return alert
}
