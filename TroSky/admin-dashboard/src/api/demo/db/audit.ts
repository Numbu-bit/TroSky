import { teamMembers } from '../accounts'
import { fraudState } from './fraud'
import { getDb, index } from './index'
import { describe, platformState, recordAudit } from './platform'

type Fields = Record<string, unknown>

/** The record a request changes, found as the backend's table and id. */
function locate(table: string, id: string | null): object | undefined {
  if (!id) return undefined
  const db = getDb()
  const lookups: Record<string, () => object | undefined> = {
    drivers: () => index().drivers.get(id),
    vehicles: () => index().vehicles.get(id),
    trips: () => index().trips.get(id),
    routes: () => index().routes.get(id),
    stops: () => index().stops.get(id),
    users: () => index().users.get(id) ?? teamMembers().find((member) => member.id === id),
    bookings: () => index().bookings.get(id),
    refund_requests: () => db.refunds.find((record) => record.id === id),
    cancellation_requests: () => db.cancellations.find((record) => record.id === id),
    withdrawal_requests: () => db.withdrawals.find((record) => record.id === id),
    complaints: () => db.complaints.find((record) => record.id === id),
    sos_alerts: () => db.sosAlerts.find((record) => record.id === id),
    incidents: () => db.incidents.find((record) => record.id === id),
    fraud_flags: () => fraudState().flags.find((record) => record.id === id),
    fraud_rule_configs: () => fraudState().rules.get(id),
    feature_flags: () => platformState().flags.get(id)?.value,
  }
  return lookups[table]?.()
}

/** Its plain fields (the backend records changed columns, not nested rows). */
function snapshot(record: object | undefined): Fields | null {
  if (!record) return null
  const fields: Fields = {}
  for (const [key, value] of Object.entries(record)) {
    if (value === null || ['string', 'number', 'boolean'].includes(typeof value))
      fields[key] = value
  }
  return fields
}

const REASON_FIELDS = ['reason', 'rejection_reason', 'notes', 'decision_notes', 'resolution_notes']
const SECRET = /password|token|code/i

/**
 * Start recording an admin action: what the record looked like before.
 * ``finish`` records it, with only the fields that changed.
 */
export function beginAudit(method: string, pattern: string, params: Record<string, string>) {
  const { action, path, table, param } = describe(method, pattern)
  const id = param ? (params[param] ?? null) : null
  const before = snapshot(locate(table, id))
  return {
    finish(actorId: string, body: unknown) {
      const request = (body ?? {}) as Fields
      const after = snapshot(locate(table, id))
      let changedBefore: Fields | null = null
      let changedAfter: Fields | null = null
      if (before && after) {
        changedBefore = {}
        changedAfter = {}
        for (const key of new Set([...Object.keys(before), ...Object.keys(after)])) {
          if (before[key] !== after[key]) {
            changedBefore[key] = before[key] ?? null
            changedAfter[key] = after[key] ?? null
          }
        }
      } else if (method !== 'DELETE') {
        // A new record, or settings: what was sent (never a secret).
        changedAfter = Object.fromEntries(
          Object.entries(request).filter(
            ([key]) => !SECRET.test(key) && !REASON_FIELDS.includes(key),
          ),
        )
      }
      const reasonField = REASON_FIELDS.find(
        (key) => typeof request[key] === 'string' && request[key],
      )
      recordAudit({
        actor_user_id: actorId,
        action,
        method,
        path,
        entity_type: table,
        entity_id: id,
        before: changedBefore,
        after: changedAfter,
        reason: reasonField ? String(request[reasonField]) : null,
      })
    },
  }
}
