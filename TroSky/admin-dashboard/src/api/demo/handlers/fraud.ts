import { HttpResponse } from 'msw'

import type { Schemas } from '@/api/types'

import { getDb, index, touch } from '../db'
import { revokeAllSessions, walletFor } from '../db/extras'
import {
  CLOSED_FLAGS,
  fraudState,
  OPEN_FLAGS,
  reviewsFraud,
  riskScore,
  ruleDef,
  RULES,
  type FlagRec,
  type FlagStatus,
} from '../db/fraud'
import { csvAnswer, endpoint, errorResponse, notFound, paginate } from '../http'
import { Random } from '../random'
import { adminName, money } from '../views'
import { paymentReference } from './bookings'
import { countFigure, Daily, resolvePeriod } from './overview'

const ids = new Random(4040)
const SORTS = ['risk_score', 'first_detected_at', 'last_detected_at', 'amount_at_risk']

function list(value: string | null): string[] {
  return (value ?? '')
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean)
}

const invalid = (message: string, param: string) =>
  errorResponse(422, 'VALIDATION_ERROR', message, { param })

export function flagResponse(flag: FlagRec): Schemas['FraudFlagResponse'] {
  const subject = flag.subject_user_id ? index().users.get(flag.subject_user_id) : undefined
  return {
    id: flag.id,
    rule: flag.rule,
    rule_title: ruleDef(flag.rule).title,
    severity: flag.severity,
    risk_score: flag.risk_score,
    entity_type: flag.entity_type,
    entity_id: flag.entity_id,
    subject_user_id: flag.subject_user_id,
    subject_name: subject?.full_name ?? null,
    summary: flag.summary,
    amount_at_risk: flag.amount_at_risk === null ? null : money(flag.amount_at_risk),
    status: flag.status,
    assigned_to: flag.assigned_to,
    assignee_name: adminName(flag.assigned_to),
    first_detected_at: flag.first_detected_at,
    last_detected_at: flag.last_detected_at,
    occurrences: flag.occurrences,
  }
}

function eventResponse(event: FlagRec['timeline'][number]): Schemas['FraudFlagEventResponse'] {
  return { ...event, actor_name: adminName(event.actor_id) }
}

function detail(flag: FlagRec): Schemas['FraudFlagDetailResponse'] {
  const { users, trips, bookings, routes } = index()
  const state = fraudState()
  return {
    ...flagResponse(flag),
    evidence: flag.evidence,
    reviewed_by: flag.reviewed_by,
    reviewed_at: flag.reviewed_at,
    review_reason: flag.review_reason,
    device_blocked: flag.entity_type === 'device' ? state.blockedDevices.has(flag.entity_id) : null,
    users: flag.users.map((id) => {
      const user = users.get(id)
      return {
        id,
        full_name: user?.full_name ?? null,
        phone_number: user?.phone_number ?? null,
        is_suspended: user?.is_suspended ?? null,
        wallet_frozen: Boolean(walletFor(id).frozen_at),
      }
    }),
    trips: flag.trips.map((id) => {
      const trip = trips.get(id)
      return {
        id,
        route_name: trip ? (routes.get(trip.route_id)?.name ?? null) : null,
        scheduled_departure_at: trip?.scheduled_departure_at ?? null,
        status: trip?.status ?? null,
      }
    }),
    bookings: flag.bookings.map((id) => {
      const booking = bookings.get(id)
      return {
        id,
        booking_reference: booking?.reference ?? null,
        status: booking?.status ?? null,
        fare_amount: booking ? money(booking.fare_amount) : null,
      }
    }),
    payments: flag.payments.map((id) => {
      const payment = getDb().payments.find((candidate) => candidate.id === id)
      return {
        id,
        internal_reference: payment ? paymentReference(payment) : null,
        amount: payment ? money(payment.amount) : null,
        status: payment?.status ?? null,
        channel: payment?.channel ?? null,
      }
    }),
    timeline: flag.timeline.map(eventResponse),
  }
}

const findFlag = (id: string | undefined) => fraudState().flags.find((flag) => flag.id === id)

export const fraudHandlers = [
  endpoint.get('/admin/fraud/flags', ['fraud:view', 'fraud:manage'], ({ url }) => {
    const sort = url.searchParams.get('sort') ?? '-risk_score'
    const field = sort.replace(/^[-+]/, '') as
      'risk_score' | 'first_detected_at' | 'last_detected_at' | 'amount_at_risk'
    if (!SORTS.includes(field)) {
      return errorResponse(422, 'VALIDATION_ERROR', `Cannot sort by '${field}'.`, {
        param: 'sort',
        allowed: [...SORTS].sort(),
      })
    }
    const statuses = list(url.searchParams.get('status'))
    const rules = list(url.searchParams.get('rule'))
    const severities = list(url.searchParams.get('severity'))
    const minRisk = url.searchParams.get('min_risk')
    const assignee = url.searchParams.get('assigned_to')
    const unassigned = url.searchParams.get('unassigned') === 'true'
    const subject = url.searchParams.get('subject_user_id')
    const from = url.searchParams.get('from')
    const to = url.searchParams.get('to')
    const rows = fraudState().flags.filter((flag) => {
      const day = flag.first_detected_at.slice(0, 10)
      return (
        (!statuses.length || statuses.includes(flag.status)) &&
        (!rules.length || rules.includes(flag.rule)) &&
        (!severities.length || severities.includes(flag.severity)) &&
        (minRisk === null || flag.risk_score >= Number(minRisk)) &&
        (!assignee || flag.assigned_to === assignee) &&
        (!unassigned || flag.assigned_to === null) &&
        (!subject || flag.subject_user_id === subject) &&
        (!from || day >= from) &&
        (!to || day <= to)
      )
    })
    rows.sort((a, b) => {
      const [x, y] = [a[field], b[field]]
      if (x === null) return 1
      if (y === null) return -1
      return typeof x === 'number' && typeof y === 'number'
        ? x - y
        : String(x).localeCompare(String(y))
    })
    if (sort.startsWith('-')) {
      const present = rows.filter((row) => row[field] !== null).reverse()
      rows.splice(0, rows.length, ...present, ...rows.filter((row) => row[field] === null))
    }
    const items = rows.map(flagResponse)
    if (url.searchParams.get('format') === 'csv') return csvAnswer(items, 'fraud-flags')
    return paginate(items, url)
  }),

  endpoint.get('/admin/fraud/flags/:flagId', ['fraud:view', 'fraud:manage'], ({ params }) => {
    const flag = findFlag(params.flagId)
    return flag ? detail(flag) : notFound('Flag not found.')
  }),

  endpoint.patch('/admin/fraud/flags/:flagId', ['fraud:manage'], ({ params, admin, body }) => {
    const flag = findFlag(params.flagId)
    if (!flag) return notFound('Flag not found.')
    const changes = (body ?? {}) as Schemas['FraudFlagUpdateRequest']
    const now = new Date().toISOString()
    if ('assigned_to' in changes && changes.assigned_to !== flag.assigned_to) {
      if (changes.assigned_to && !reviewsFraud(changes.assigned_to)) {
        return invalid(
          'Flags can only be assigned to an active admin who reviews fraud.',
          'assigned_to',
        )
      }
      flag.assigned_to = changes.assigned_to ?? null
      flag.timeline.push({
        id: ids.uuid(),
        kind: 'assigned',
        actor_id: admin.id,
        details: { assigned_to: String(changes.assigned_to ?? null) },
        created_at: now,
      })
    }
    const status = changes.status as FlagStatus | null | undefined
    if (status && status !== flag.status) {
      const reason = changes.reason?.trim()
      if (CLOSED_FLAGS.has(status) && !reason) {
        return invalid('Say why the flag is confirmed or a false positive.', 'reason')
      }
      flag.timeline.push({
        id: ids.uuid(),
        kind: 'status_changed',
        actor_id: admin.id,
        details: { from: flag.status, to: status, reason: reason ?? null },
        created_at: now,
      })
      flag.status = status
      if (CLOSED_FLAGS.has(status)) {
        flag.reviewed_by = admin.id
        flag.reviewed_at = now
        flag.review_reason = reason ?? null
      } else {
        flag.reviewed_by = flag.reviewed_at = flag.review_reason = null
      }
    }
    touch()
    return flagResponse(flag)
  }),

  endpoint.post(
    '/admin/fraud/flags/:flagId/actions',
    ['fraud:manage'],
    ({ params, admin, body }) => {
      const flag = findFlag(params.flagId)
      if (!flag) return notFound('Flag not found.')
      const request = body as Schemas['FraudActionRequest']
      const state = fraudState()
      let target: string
      if (request.action === 'block_device' || request.action === 'unblock_device') {
        const device = request.device_id ?? (flag.entity_type === 'device' ? flag.entity_id : null)
        if (!device) return invalid('Name the device to act on.', 'device_id')
        target = device
        if (request.action === 'block_device') state.blockedDevices.add(device)
        else state.blockedDevices.delete(device)
      } else {
        const account = request.user_id ?? flag.subject_user_id
        if (!account) return invalid('Name the account to act on.', 'user_id')
        const user = index().users.get(account)
        if (!user) return notFound('User not found.')
        target = account
        if (request.action === 'suspend_account') {
          user.is_suspended = true
          user.suspended_at = new Date().toISOString()
          user.suspension_reason = request.reason
          revokeAllSessions(account)
        } else {
          const wallet = walletFor(account)
          const freeze = request.action === 'freeze_wallet'
          wallet.frozen_at = freeze ? new Date().toISOString() : null
          wallet.frozen_reason = freeze ? request.reason : null
        }
      }
      if (flag.status === 'open') flag.status = 'investigating'
      const event = {
        id: ids.uuid(),
        kind: 'action',
        actor_id: admin.id,
        details: { action: request.action, target, reason: request.reason },
        created_at: new Date().toISOString(),
      }
      flag.timeline.push(event)
      touch()
      return HttpResponse.json(
        {
          flag: flagResponse(flag),
          event: eventResponse(event),
        } satisfies Schemas['FraudActionResponse'],
        { status: 201 },
      )
    },
  ),

  endpoint.get('/admin/fraud/stats', ['fraud:view', 'fraud:manage'], ({ url }) => {
    const period = resolvePeriod(url)
    if (period instanceof Response) return period
    const flags = fraudState().flags
    const open = flags.filter((flag) => OPEN_FLAGS.has(flag.status))
    const detected = new Daily()
    for (const flag of flags) detected.add(flag.first_detected_at)
    const reviewedIn = (dates: string[], status: FlagStatus) =>
      flags.filter(
        (flag) =>
          flag.status === status &&
          flag.reviewed_at &&
          dates.includes(flag.reviewed_at.slice(0, 10)),
      ).length
    const precision = (dates: string[]) => {
      const confirmed = reviewedIn(dates, 'confirmed')
      const wrong = reviewedIn(dates, 'false_positive')
      return confirmed + wrong ? (confirmed / (confirmed + wrong)).toFixed(4) : null
    }
    const inPeriod = (flag: FlagRec) => period.dates.includes(flag.first_detected_at.slice(0, 10))
    return {
      period: period.response,
      open: open.length,
      high_risk: open.filter((flag) => flag.risk_score >= 70).length,
      amount_at_risk: money(open.reduce((sum, flag) => sum + (flag.amount_at_risk ?? 0), 0)),
      detected: countFigure(detected, period),
      confirmed: reviewedIn(period.dates, 'confirmed'),
      false_positive: reviewedIn(period.dates, 'false_positive'),
      precision: { value: precision(period.dates), previous: precision(period.previous) },
      by_rule: RULES.map((rule) => {
        const of = flags.filter((flag) => flag.rule === rule.key && inPeriod(flag))
        return {
          rule: rule.key,
          rule_title: rule.title,
          detected: of.length,
          confirmed: of.filter((flag) => flag.status === 'confirmed').length,
          false_positive: of.filter((flag) => flag.status === 'false_positive').length,
        }
      }).filter((row) => row.detected > 0),
    } satisfies Schemas['FraudStatsResponse']
  }),

  endpoint.get('/admin/fraud/rules', ['fraud:manage'], () =>
    RULES.map((rule): Schemas['FraudRuleResponse'] => {
      const config = fraudState().rules.get(rule.key)!
      return {
        key: rule.key,
        title: rule.title,
        threshold_means: rule.threshold_means,
        enabled: config.enabled,
        threshold: String(config.threshold),
        window_minutes: config.window_minutes,
        severity: config.severity,
        changed:
          !config.enabled ||
          config.threshold !== rule.threshold ||
          config.window_minutes !== rule.window_minutes ||
          config.severity !== rule.severity,
        updated_by: config.updated_by,
        updated_at: config.updated_at,
      }
    }),
  ),

  endpoint.patch('/admin/fraud/rules/:rule', ['fraud:manage'], ({ params, admin, body }) => {
    const rule = RULES.find((candidate) => candidate.key === params.rule)
    if (!rule) return notFound('Rule not found.')
    const config = fraudState().rules.get(rule.key)!
    const changes = (body ?? {}) as Schemas['FraudRuleUpdateRequest']
    if (changes.threshold !== undefined && changes.threshold !== null) {
      const threshold = Number(changes.threshold)
      if (!Number.isFinite(threshold) || threshold <= 0)
        return invalid('The threshold must be above 0.', 'threshold')
      config.threshold = threshold
    }
    if (changes.window_minutes) {
      if (changes.window_minutes < 1)
        return invalid('The window must be at least a minute.', 'window_minutes')
      config.window_minutes = changes.window_minutes
    }
    if (typeof changes.enabled === 'boolean') config.enabled = changes.enabled
    if (changes.severity) config.severity = changes.severity
    config.updated_by = admin.id
    config.updated_at = new Date().toISOString()
    touch()
    return {
      key: rule.key,
      title: rule.title,
      threshold_means: rule.threshold_means,
      enabled: config.enabled,
      threshold: String(config.threshold),
      window_minutes: config.window_minutes,
      severity: config.severity,
      changed: true,
      updated_by: config.updated_by,
      updated_at: config.updated_at,
    } satisfies Schemas['FraudRuleResponse']
  }),

  // A detection run: open flags seen again, and the odd new one.
  endpoint.post('/admin/fraud/scan', ['fraud:manage'], () => {
    const state = fraudState()
    state.scans += 1
    const now = new Date().toISOString()
    const byRule: Record<string, number> = {}
    let updated = 0
    for (const flag of state.flags
      .filter((candidate) => OPEN_FLAGS.has(candidate.status))
      .slice(0, 2)) {
      if (!state.rules.get(flag.rule)!.enabled) continue
      flag.occurrences += 1
      flag.last_detected_at = now
      flag.timeline.push({
        id: ids.uuid(),
        kind: 'detected_again',
        actor_id: null,
        details: {},
        created_at: now,
      })
      byRule[flag.rule] = (byRule[flag.rule] ?? 0) + 1
      updated += 1
    }
    let raised = 0
    const config = state.rules.get('payment_failures')!
    if (config.enabled) {
      const passengers = getDb().users.filter((user) => user.roles.includes('passenger'))
      const user = passengers[(state.scans * 37) % passengers.length]!
      const failures = 6 + (state.scans % 5)
      state.flags.unshift({
        id: ids.uuid(),
        rule: 'payment_failures',
        severity: config.severity,
        risk_score: riskScore(
          ruleDef('payment_failures'),
          config.threshold,
          config.severity,
          failures,
        ),
        entity_type: 'user',
        entity_id: user.id,
        subject_user_id: user.id,
        summary: `${failures} failed payments within an hour`,
        amount_at_risk: null,
        status: 'open',
        assigned_to: null,
        first_detected_at: now,
        last_detected_at: now,
        occurrences: 1,
        evidence: { failed_payments: failures, window_minutes: config.window_minutes },
        reviewed_by: null,
        reviewed_at: null,
        review_reason: null,
        users: [user.id],
        trips: [],
        bookings: [],
        payments: [],
        timeline: [
          {
            id: ids.uuid(),
            kind: 'detected',
            actor_id: null,
            details: { observed: String(failures) },
            created_at: now,
          },
        ],
      })
      raised = 1
      byRule.payment_failures = (byRule.payment_failures ?? 0) + 1
    }
    touch()
    return { raised, updated, by_rule: byRule } satisfies Schemas['DetectionRunResponse']
  }),
]

/** High-risk open flags, for the alerts feed. */
export function fraudAlerts(): Schemas['AlertResponse'][] {
  return fraudState()
    .flags.filter((flag) => OPEN_FLAGS.has(flag.status) && flag.risk_score >= 70)
    .sort((a, b) => b.risk_score - a.risk_score)
    .slice(0, 200)
    .map((flag) => ({
      type: 'fraud_high_risk',
      severity: flag.severity === 'critical' ? 'critical' : 'high',
      title: `Possible fraud: ${flag.summary}`.slice(0, 200),
      entity_type: 'fraud_flag',
      entity_id: flag.id,
      since: flag.first_detected_at,
      details: {
        rule: flag.rule,
        risk_score: flag.risk_score,
        amount_at_risk: flag.amount_at_risk === null ? null : flag.amount_at_risk.toFixed(2),
        subject_user_id: flag.subject_user_id,
        status: flag.status,
      },
    }))
}
