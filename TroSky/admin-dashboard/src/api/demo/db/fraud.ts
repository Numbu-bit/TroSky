import type { Schemas } from '@/api/types'

import { teamMembers } from '../accounts'
import { Random } from '../random'
import type { DemoDb } from './build'
import { DAY, getDb, HOUR, index, MINUTE } from './index'

/**
 * Fraud flags, rules and blocked devices for the demo: made on first use,
 * deterministically, around real demo accounts, drivers and trips (so every
 * link on a flag opens something).
 */
export type Severity = Schemas['FraudSeverity']
export type FlagStatus = Schemas['FraudFlagStatus']

export interface RuleDef {
  key: string
  title: string
  threshold_means: string
  threshold: number
  window_minutes: number
  severity: Severity
  below?: boolean
}

/** The backend's rules (app/services/fraud_rules.py). */
export const RULES: RuleDef[] = [
  {
    key: 'ticket_reused',
    title: 'A ticket scanned again after boarding, or on another trip',
    threshold_means: 'refused scans',
    threshold: 1,
    window_minutes: 24 * 60,
    severity: 'high',
  },
  {
    key: 'payment_failures',
    title: 'Repeated payment failures in a short time',
    threshold_means: 'failed payments',
    threshold: 5,
    window_minutes: 60,
    severity: 'medium',
  },
  {
    key: 'shared_device',
    title: 'Several accounts signing in on one device',
    threshold_means: 'accounts',
    threshold: 3,
    window_minutes: 30 * 24 * 60,
    severity: 'high',
  },
  {
    key: 'shared_momo_number',
    title: 'Several accounts paying with one mobile money number',
    threshold_means: 'accounts',
    threshold: 3,
    window_minutes: 30 * 24 * 60,
    severity: 'high',
  },
  {
    key: 'expired_reservations',
    title: 'Seat reservations repeatedly left to expire unpaid',
    threshold_means: 'expired reservations',
    threshold: 5,
    window_minutes: 7 * 24 * 60,
    severity: 'low',
  },
  {
    key: 'refund_share',
    title: 'A high share of a passenger’s bookings refunded',
    threshold_means: 'share of paid bookings refunded (0-1)',
    threshold: 0.5,
    window_minutes: 30 * 24 * 60,
    severity: 'medium',
  },
  {
    key: 'stationary_trip',
    title: 'A completed trip whose vehicle barely moved',
    threshold_means: 'km moved, at most',
    threshold: 0.2,
    window_minutes: 24 * 60,
    severity: 'medium',
    below: true,
  },
  {
    key: 'impossible_speed',
    title: 'A jump between GPS positions faster than a bus can go',
    threshold_means: 'km/h',
    threshold: 150,
    window_minutes: 24 * 60,
    severity: 'high',
  },
  {
    key: 'low_scan_compliance',
    title: 'A driver scanning few of their paid passengers’ tickets',
    threshold_means: 'share of paid passengers scanned (0-1), at most',
    threshold: 0.5,
    window_minutes: 7 * 24 * 60,
    severity: 'medium',
    below: true,
  },
  {
    key: 'unusual_topups',
    title: 'Unusually large wallet top-ups',
    threshold_means: 'GHS topped up',
    threshold: 2000,
    window_minutes: 24 * 60,
    severity: 'medium',
  },
]

const BASE_RISK: Record<Severity, number> = { low: 25, medium: 50, high: 70, critical: 90 }

/** 0-100: the severity's base, plus up to 20 for how far past the threshold. */
export function riskScore(
  rule: RuleDef,
  threshold: number,
  severity: Severity,
  observed: number,
): number {
  const ratio = rule.below
    ? observed > 0
      ? threshold / observed
      : 2
    : threshold > 0
      ? observed / threshold
      : 2
  const beyond = Math.min(1, Math.max(0, ratio - 1))
  return Math.min(100, BASE_RISK[severity] + Math.round(beyond * 20))
}

export interface RuleState {
  enabled: boolean
  threshold: number
  window_minutes: number
  severity: Severity
  updated_by: string | null
  updated_at: string | null
}

export interface FlagEvent {
  id: string
  kind: string
  actor_id: string | null
  details: Record<string, unknown>
  created_at: string
}

export interface FlagRec {
  id: string
  rule: string
  severity: Severity
  risk_score: number
  entity_type: string
  entity_id: string
  subject_user_id: string | null
  summary: string
  amount_at_risk: number | null
  status: FlagStatus
  assigned_to: string | null
  first_detected_at: string
  last_detected_at: string
  occurrences: number
  evidence: Record<string, unknown>
  reviewed_by: string | null
  reviewed_at: string | null
  review_reason: string | null
  users: string[]
  trips: string[]
  bookings: string[]
  payments: string[]
  timeline: FlagEvent[]
}

interface FraudState {
  flags: FlagRec[]
  rules: Map<string, RuleState>
  blockedDevices: Set<string>
  scans: number
}

const states = new WeakMap<DemoDb, FraudState>()
const iso = (ms: number) => new Date(ms).toISOString()

export function fraudState(): FraudState {
  const db = getDb()
  const known = states.get(db)
  if (known) return known
  const state: FraudState = {
    flags: [],
    rules: new Map(
      RULES.map((rule) => [
        rule.key,
        {
          enabled: true,
          threshold: rule.threshold,
          window_minutes: rule.window_minutes,
          severity: rule.severity,
          updated_by: null,
          updated_at: null,
        },
      ]),
    ),
    blockedDevices: new Set(),
    scans: 0,
  }
  states.set(db, state)
  seed(state, db)
  return state
}

export const ruleDef = (key: string) => RULES.find((rule) => rule.key === key)!

/** Who reviews fraud: super admins, and those holding fraud:view or fraud:manage. */
export function reviewsFraud(id: string): boolean {
  const member = teamMembers().find((candidate) => candidate.id === id)
  return Boolean(
    member?.is_active &&
    !member.is_suspended &&
    (member.role === 'super_admin' ||
      member.permissions.some((permission) => permission.startsWith('fraud:'))),
  )
}

function seed(state: FraudState, db: DemoDb) {
  const random = new Random(31_337)
  const now = db.builtAt
  const admins = teamMembers()
    .filter((member) => reviewsFraud(member.id))
    .map((member) => member.id)
  const passengers = db.users.filter(
    (user) => user.roles.includes('passenger') && !user.is_suspended,
  )
  const completed = db.trips.filter(
    (trip) => trip.status === 'completed' && trip.driver_id && trip.vehicle_id,
  )
  const approvedDrivers = db.drivers.filter((driver) => driver.status === 'approved')

  type Draft = Omit<
    FlagRec,
    | 'id'
    | 'severity'
    | 'risk_score'
    | 'status'
    | 'assigned_to'
    | 'first_detected_at'
    | 'last_detected_at'
    | 'occurrences'
    | 'reviewed_by'
    | 'reviewed_at'
    | 'review_reason'
    | 'timeline'
  > & { observed: number }
  const drafts: Draft[] = []

  for (let n = 0; n < 3; n += 1) {
    const device = `dev-${random.int(100_000, 999_999)}`
    const accounts = random.sample(passengers, random.int(3, 5))
    drafts.push({
      rule: 'shared_device',
      entity_type: 'device',
      entity_id: device,
      subject_user_id: accounts[0]!.id,
      summary: `${accounts.length} accounts signed in on one device`,
      amount_at_risk: null,
      evidence: {
        device_id: device,
        device_name: random.pick(['TECNO Spark 10', 'itel A70', 'Infinix Hot 30']),
        accounts: accounts.length,
        first_seen: iso(now - random.int(5, 25) * DAY),
      },
      users: accounts.map((user) => user.id),
      trips: [],
      bookings: [],
      payments: [],
      observed: accounts.length,
    })
  }
  for (let n = 0; n < 2; n += 1) {
    const accounts = random.sample(passengers, random.int(3, 4))
    const number = `+23324${random.int(1_000_000, 9_999_999)}`
    drafts.push({
      rule: 'shared_momo_number',
      entity_type: 'phone_number',
      entity_id: number,
      subject_user_id: accounts[0]!.id,
      summary: `${accounts.length} accounts paid with one MTN MoMo number`,
      amount_at_risk: random.int(120, 900),
      evidence: {
        number: `${number.slice(0, 6)}•••${number.slice(-3)}`,
        channel: 'mtn_momo',
        accounts: accounts.length,
      },
      users: accounts.map((user) => user.id),
      trips: [],
      bookings: [],
      payments: [],
      observed: accounts.length,
    })
  }
  for (let n = 0; n < 3; n += 1) {
    const user = random.pick(passengers)
    const failures = random.int(6, 14)
    drafts.push({
      rule: 'payment_failures',
      entity_type: 'user',
      entity_id: user.id,
      subject_user_id: user.id,
      summary: `${failures} failed payments within an hour`,
      amount_at_risk: null,
      evidence: { failed_payments: failures, window_minutes: 60, channels: ['card', 'mtn_momo'] },
      users: [user.id],
      trips: [],
      bookings: [],
      payments: [],
      observed: failures,
    })
  }
  for (let n = 0; n < 2; n += 1) {
    const user = random.pick(passengers)
    const own = db.bookings.filter((booking) => booking.passenger_id === user.id).slice(0, 6)
    const share = random.pick([0.6, 0.67, 0.75, 0.8])
    drafts.push({
      rule: 'refund_share',
      entity_type: 'user',
      entity_id: user.id,
      subject_user_id: user.id,
      summary: `${Math.round(share * 100)}% of paid bookings refunded in 30 days`,
      amount_at_risk: random.int(80, 400),
      evidence: {
        paid_bookings: Math.max(4, own.length),
        refunded: Math.round(Math.max(4, own.length) * share),
        share,
      },
      users: [user.id],
      trips: [],
      bookings: own.map((booking) => booking.id),
      payments: [],
      observed: share,
    })
  }
  for (let n = 0; n < 2; n += 1) {
    const user = random.pick(passengers)
    const expired = random.int(6, 11)
    drafts.push({
      rule: 'expired_reservations',
      entity_type: 'user',
      entity_id: user.id,
      subject_user_id: user.id,
      summary: `${expired} seats held and left to expire in a week`,
      amount_at_risk: null,
      evidence: { expired_reservations: expired, window_days: 7 },
      users: [user.id],
      trips: [],
      bookings: [],
      payments: [],
      observed: expired,
    })
  }
  for (let n = 0; n < 2; n += 1) {
    const trip = random.pick(completed)
    const driver = index().drivers.get(trip.driver_id!)!
    drafts.push({
      rule: 'stationary_trip',
      entity_type: 'trip',
      entity_id: trip.id,
      subject_user_id: driver.user_id,
      summary: 'Marked completed, but the bus moved 0.1 km',
      amount_at_risk: random.int(150, 600),
      evidence: {
        km_moved: 0.1,
        gps_points: random.int(8, 40),
        passengers_boarded: random.int(0, 3),
      },
      users: [driver.user_id],
      trips: [trip.id],
      bookings: (index().bookingsByTrip.get(trip.id) ?? [])
        .slice(0, 5)
        .map((booking) => booking.id),
      payments: [],
      observed: 0.1,
    })
  }
  {
    const trip = random.pick(completed)
    const driver = index().drivers.get(trip.driver_id!)!
    const speed = random.int(190, 320)
    drafts.push({
      rule: 'impossible_speed',
      entity_type: 'trip',
      entity_id: trip.id,
      subject_user_id: driver.user_id,
      summary: `A jump of ${speed} km/h between two GPS positions`,
      amount_at_risk: null,
      evidence: { km_per_hour: speed, between: [iso(now - 3 * DAY), iso(now - 3 * DAY + MINUTE)] },
      users: [driver.user_id],
      trips: [trip.id],
      bookings: [],
      payments: [],
      observed: speed,
    })
  }
  for (let n = 0; n < 2; n += 1) {
    const driver = random.pick(approvedDrivers)
    const share = random.pick([0.31, 0.38, 0.42])
    drafts.push({
      rule: 'low_scan_compliance',
      entity_type: 'driver',
      entity_id: driver.id,
      subject_user_id: driver.user_id,
      summary: `Scanned ${Math.round(share * 100)}% of paid passengers’ tickets this week`,
      amount_at_risk: null,
      evidence: { paid_passengers: random.int(40, 90), scanned_share: share },
      users: [driver.user_id],
      trips: [],
      bookings: [],
      payments: [],
      observed: share,
    })
  }
  {
    const booking = random.pick(db.bookings.filter((candidate) => candidate.status === 'completed'))
    drafts.push({
      rule: 'ticket_reused',
      entity_type: 'ticket',
      entity_id: `TKT-${booking.reference.slice(4)}-1`,
      subject_user_id: booking.passenger_id,
      summary: 'A ticket scanned again on another trip',
      amount_at_risk: booking.fare_amount,
      evidence: { refused_scans: 2, ticket_reference: `TKT-${booking.reference.slice(4)}-1` },
      users: [booking.passenger_id],
      trips: [booking.trip_id],
      bookings: [booking.id],
      payments: [],
      observed: 2,
    })
  }
  {
    const user = random.pick(passengers)
    const amount = random.int(2400, 5200)
    drafts.push({
      rule: 'unusual_topups',
      entity_type: 'user',
      entity_id: user.id,
      subject_user_id: user.id,
      summary: `GH₵${amount.toLocaleString('en-GH')} topped up in one day`,
      amount_at_risk: amount,
      evidence: { topped_up: amount, topups: random.int(3, 6) },
      users: [user.id],
      trips: [],
      bookings: [],
      payments: [],
      observed: amount,
    })
  }

  drafts.forEach((draft, position) => {
    const rule = ruleDef(draft.rule)
    const first = now - random.float(0.2, 28) * DAY
    const last = Math.min(now - HOUR, first + random.float(0, 3) * DAY)
    const status: FlagStatus =
      position % 6 === 0
        ? 'confirmed'
        : position % 6 === 3
          ? 'false_positive'
          : position % 4 === 1
            ? 'investigating'
            : 'open'
    const reviewer = status === 'open' && position % 3 ? null : random.pick(admins)
    const flag: FlagRec = {
      ...draft,
      id: random.uuid(),
      severity: rule.severity,
      risk_score: riskScore(rule, rule.threshold, rule.severity, draft.observed),
      status,
      assigned_to: reviewer,
      first_detected_at: iso(first),
      last_detected_at: iso(last),
      occurrences: 1 + random.int(0, 3),
      reviewed_by: status === 'confirmed' || status === 'false_positive' ? reviewer : null,
      reviewed_at:
        status === 'confirmed' || status === 'false_positive'
          ? iso(Math.min(now - MINUTE, last + random.float(1, 30) * HOUR))
          : null,
      review_reason:
        status === 'confirmed'
          ? 'Matched against payments and trip logs: the pattern is real.'
          : status === 'false_positive'
            ? 'A family sharing one phone; nothing wrong.'
            : null,
      timeline: [],
    }
    delete (flag as Partial<Draft>).observed
    flag.timeline.push({
      id: random.uuid(),
      kind: 'detected',
      actor_id: null,
      details: { observed: String(draft.observed) },
      created_at: flag.first_detected_at,
    })
    if (flag.occurrences > 1) {
      flag.timeline.push({
        id: random.uuid(),
        kind: 'detected_again',
        actor_id: null,
        details: { observed: String(draft.observed) },
        created_at: flag.last_detected_at,
      })
    }
    if (reviewer) {
      flag.timeline.push({
        id: random.uuid(),
        kind: 'assigned',
        actor_id: reviewer,
        details: { assigned_to: reviewer },
        created_at: iso(Math.min(now - MINUTE, last + HOUR)),
      })
    }
    if (flag.reviewed_at) {
      flag.timeline.push({
        id: random.uuid(),
        kind: 'status_changed',
        actor_id: reviewer,
        details: { from: 'investigating', to: status, reason: flag.review_reason },
        created_at: flag.reviewed_at,
      })
    }
    state.flags.push(flag)
  })
  state.flags.sort((a, b) => b.first_detected_at.localeCompare(a.first_detected_at))
}

export const OPEN_FLAGS = new Set<FlagStatus>(['open', 'investigating'])
export const CLOSED_FLAGS = new Set<FlagStatus>(['confirmed', 'false_positive'])
