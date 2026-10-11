import { teamMembers } from '../accounts'
import { Random } from '../random'
import type { DemoDb } from './build'
import { DAY, getDb, HOUR } from './index'

/**
 * Platform settings, feature flags and the audit trail in the demo: kept
 * with the demo platform they belong to (a rebuilt platform starts afresh).
 */

/** The backend's defaults (system_settings_service._defaults). */
export const SETTING_DEFAULTS: Record<string, unknown> = {
  platform_fee_flat_per_seat: '0.50',
  platform_fee_percent: '0',
  driver_earnings_share_percent: '80.00',
  reservation_hold_seconds: 600,
  live_update_interval_seconds: 5,
  complaint_sla_hours: { low: 72, medium: 48, high: 24, urgent: 4 },
  approval_target_hours: 48,
  sos_escalation_contacts: [],
  enabled_cities: [],
}

export interface FlagDef {
  description: string
  default: boolean
  /** It switches a platform-wide setting: on or off for everyone. */
  platformWide: boolean
}

export const FLAG_DEFS: Record<string, FlagDef> = {
  fare_sharing: {
    description: 'Share each trip’s fare between its riders by distance.',
    default: true,
    platformWide: true,
  },
  book_moving_trips: {
    description:
      'Show trips already on the road in search, bookable from stops ahead of the vehicle.',
    default: true,
    platformWide: true,
  },
  trip_share_links: {
    description: 'Let passengers share a live link to their trip with family and friends.',
    default: true,
    platformWide: false,
  },
}

export interface Changed<T> {
  value: T
  updated_by: string
  updated_at: string
}

export interface AuditRec {
  id: string
  created_at: string
  actor_user_id: string | null
  action: string
  method: string
  path: string
  entity_type: string
  entity_id: string | null
  before: Record<string, unknown> | null
  after: Record<string, unknown> | null
  reason: string | null
  ip_address: string | null
  user_agent: string | null
  request_id: string | null
}

interface PlatformState {
  settings: Map<string, Changed<unknown>>
  flags: Map<string, Changed<{ enabled: boolean; rollout_percent: number }>>
  /** Newest first. */
  audit: AuditRec[]
  serial: number
}

const states = new WeakMap<DemoDb, PlatformState>()
const iso = (ms: number) => new Date(ms).toISOString()
const AGENT = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/128.0'

export function platformState(): PlatformState {
  const db = getDb()
  const known = states.get(db)
  if (known) return known
  const state: PlatformState = { settings: new Map(), flags: new Map(), audit: [], serial: 0 }
  states.set(db, state)
  seedAudit(state, db)
  return state
}

/** The audit trail of the last 30 days, from what admins did in the demo data. */
function seedAudit(state: PlatformState, db: DemoDb) {
  const random = new Random(90_210)
  const since = db.builtAt - 30 * DAY
  const entries: AuditRec[] = []
  const add = (entry: Omit<AuditRec, 'id' | 'ip_address' | 'user_agent' | 'request_id'>) =>
    entries.push({
      ...entry,
      id: random.uuid(),
      ip_address: `192.0.2.${random.int(10, 60)}`,
      user_agent: AGENT,
      request_id: `req-${random.int(100_000, 999_999)}`,
    })
  for (const driver of db.drivers) {
    const at = Date.parse(driver.created_at) + random.int(2, 40) * HOUR
    if (driver.status !== 'approved' || at < since || at > db.builtAt) continue
    add({
      created_at: iso(at),
      actor_user_id: random.pick(teamMembers().slice(0, 2)).id,
      action: 'approve_driver',
      method: 'POST',
      path: '/api/v1/admin/drivers/{driver_id}/approve',
      entity_type: 'drivers',
      entity_id: driver.id,
      before: { status: 'pending' },
      after: { status: 'approved' },
      reason: null,
    })
  }
  for (const refund of db.refunds) {
    if (!refund.reviewed_at || Date.parse(refund.reviewed_at) < since) continue
    const approved = refund.status === 'completed'
    add({
      created_at: refund.reviewed_at,
      actor_user_id: refund.reviewed_by,
      action: approved ? 'approve_refund_request' : 'reject_refund_request',
      method: 'POST',
      path: `/api/v1/admin/refund-requests/{refund_id}/${approved ? 'approve' : 'reject'}`,
      entity_type: 'refund_requests',
      entity_id: refund.id,
      before: { status: 'pending' },
      after: { status: refund.status, amount: refund.amount.toFixed(2) },
      reason: refund.decision_notes,
    })
  }
  for (const payout of db.withdrawals) {
    if (!payout.reviewed_at || Date.parse(payout.reviewed_at) < since) continue
    const approved = payout.status !== 'rejected'
    add({
      created_at: payout.reviewed_at,
      actor_user_id: payout.reviewed_by,
      action: approved ? 'approve_withdrawal' : 'reject_withdrawal',
      method: 'POST',
      path: `/api/v1/admin/withdrawals/{withdrawal_id}/${approved ? 'approve' : 'reject'}`,
      entity_type: 'withdrawal_requests',
      entity_id: payout.id,
      before: { status: 'pending' },
      after: { status: approved ? 'approved' : 'rejected' },
      reason: payout.decision_notes,
    })
  }
  for (const complaint of db.complaints) {
    if (
      !complaint.resolved_at ||
      Date.parse(complaint.resolved_at) < since ||
      Date.parse(complaint.resolved_at) > db.builtAt
    )
      continue
    add({
      created_at: complaint.resolved_at,
      actor_user_id: complaint.resolved_by,
      action: complaint.status === 'resolved' ? 'resolve_complaint' : 'dismiss_complaint',
      method: 'POST',
      path: `/api/v1/admin/complaints/{complaint_id}/${complaint.status === 'resolved' ? 'resolve' : 'dismiss'}`,
      entity_type: 'complaints',
      entity_id: complaint.id,
      before: { status: 'in_review' },
      after: { status: complaint.status },
      reason: complaint.resolution_notes,
    })
  }
  for (const trip of db.trips) {
    const at = Date.parse(trip.scheduled_departure_at) - random.int(1, 20) * HOUR
    if (trip.status !== 'cancelled' || at < since || at > db.builtAt) continue
    add({
      created_at: iso(at),
      actor_user_id: random.pick(teamMembers().slice(0, 2)).id,
      action: 'cancel_trip',
      method: 'POST',
      path: '/api/v1/admin/trips/{trip_id}/cancel',
      entity_type: 'trips',
      entity_id: trip.id,
      before: { status: 'scheduled' },
      after: { status: 'cancelled' },
      reason: 'The vehicle broke down.',
    })
  }
  add({
    created_at: iso(db.builtAt - 12 * DAY - 3 * HOUR),
    actor_user_id: teamMembers()[0]!.id,
    action: 'update_settings',
    method: 'PATCH',
    path: '/api/v1/admin/settings',
    entity_type: 'system_settings',
    entity_id: 'approval_target_hours',
    before: { value: 72 },
    after: { value: 48 },
    reason: 'Drivers were waiting too long for approval.',
  })
  entries.sort((a, b) => b.created_at.localeCompare(a.created_at))
  state.audit = entries
}

// ---------------------------------------------------------- recording
/** Where each admin path's records live, as the backend's tables are named. */
const TABLES: Record<string, string> = {
  drivers: 'drivers',
  vehicles: 'vehicles',
  trips: 'trips',
  routes: 'routes',
  stops: 'stops',
  users: 'users',
  bookings: 'bookings',
  'refund-requests': 'refund_requests',
  'cancellation-requests': 'cancellation_requests',
  withdrawals: 'withdrawal_requests',
  complaints: 'complaints',
  'sos-alerts': 'sos_alerts',
  incidents: 'incidents',
  flags: 'fraud_flags',
  rules: 'fraud_rule_configs',
  settings: 'system_settings',
  'feature-flags': 'feature_flags',
  wallets: 'wallet_transactions',
  admins: 'users',
  sessions: 'user_sessions',
}

const singular = (word: string) =>
  word
    .replace(/-requests$/, '_request')
    .replace(/ies$/, 'y')
    .replace(/s$/, '')
    .replace(/-/g, '_')

/**
 * What the backend would call the action and the record: the route's
 * name ("approve_driver"), its path template and the table changed.
 */
export function describe(method: string, pattern: string) {
  const parts = pattern.split('/').filter(Boolean)
  const params = parts.filter((part) => part.startsWith(':'))
  const words = parts.filter((part) => !part.startsWith(':') && part !== 'admin')
  const resource = [...words].reverse().find((word) => word in TABLES) ?? words.at(-1) ?? 'request'
  const verb = words.at(-1) !== resource ? words.at(-1)! : null
  const action =
    verb !== null
      ? `${verb.replace(/-/g, '_')}_${singular(resource)}`
      : `${method === 'POST' ? 'create' : method === 'DELETE' ? 'delete' : 'update'}_${singular(resource)}`
  const path = `/api/v1${pattern.replace(/:([a-zA-Z]+)/g, (_, name: string) => `{${name.replace(/[A-Z]/g, (letter) => `_${letter.toLowerCase()}`)}}`)}`
  return {
    action,
    path,
    table: TABLES[resource] ?? 'request',
    param: params.at(-1)?.slice(1) ?? null,
  }
}

/** A record of a demo admin action, newest first. */
export function recordAudit(
  entry: Omit<AuditRec, 'id' | 'created_at' | 'request_id' | 'ip_address' | 'user_agent'>,
) {
  const state = platformState()
  state.serial += 1
  state.audit.unshift({
    ...entry,
    id: `0a0d1700-0000-4000-8000-${String(state.serial).padStart(12, '0')}`,
    created_at: iso(Date.now()),
    ip_address: '192.0.2.10',
    user_agent: typeof navigator === 'undefined' ? null : navigator.userAgent,
    request_id: `demo-req-${state.serial}`,
  })
}
