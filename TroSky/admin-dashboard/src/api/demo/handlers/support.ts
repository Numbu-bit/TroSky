import type { Schemas } from '@/api/types'
import { hasAny } from '@/lib/permissions'

import { teamMembers } from '../accounts'
import { getDb, index, touch } from '../db'
import { revokeAllSessions, sessionsFor, walletFor } from '../db/extras'
import type { ComplaintRec, UserRec } from '../db/model'
import { csvAnswer, endpoint, errorResponse, noContent, notFound, paginate } from '../http'
import { Random } from '../random'
import { adminComplaint, adminName, money } from '../views'
import { countFigure, Daily, resolvePeriod, tripCity } from './overview'

const ids = new Random(7272)
const SLA_HOURS: Record<Schemas['ComplaintPriority'], number> = {
  urgent: 4,
  high: 24,
  medium: 48,
  low: 72,
}
const PRIORITIES: Schemas['ComplaintPriority'][] = ['urgent', 'high', 'medium', 'low']
const CATEGORIES: Schemas['ComplaintCategory'][] = [
  'driver_conduct',
  'vehicle_condition',
  'safety',
  'payment',
  'other',
]
const OPEN = new Set(['open', 'in_review'])
const HOUR = 3_600_000

const invalid = (message: string) => errorResponse(409, 'INVALID_STATE_TRANSITION', message)

function complaintDetail(record: ComplaintRec): Schemas['AdminComplaintDetailResponse'] {
  return {
    ...adminComplaint(record),
    notes: record.notes.map((note) => ({
      id: note.id,
      kind: note.kind,
      body: note.body,
      author_id: note.author_id,
      author_name: adminName(note.author_id),
      created_at: note.created_at,
    })),
  }
}

const find = (id: string | undefined) => getDb().complaints.find((record) => record.id === id)

/** Average hours, as the backend rounds them ("12.5"), or null with none. */
function averageHours(spans: number[]): string | null {
  if (!spans.length) return null
  return (spans.reduce((sum, value) => sum + value, 0) / spans.length / HOUR).toFixed(1)
}

// -------------------------------------------------------------- accounts
function userStatus(user: UserRec): 'active' | 'suspended' | 'inactive' {
  return user.is_suspended ? 'suspended' : user.is_active ? 'active' : 'inactive'
}

function adminUser(user: UserRec): Schemas['AdminUserResponse'] {
  return {
    id: user.id,
    phone_number: user.phone_number,
    email: user.email,
    full_name: user.full_name,
    roles: user.roles,
    is_active: user.is_active,
    is_suspended: user.is_suspended,
    suspended_reason: user.suspension_reason,
    created_at: user.created_at,
    last_login_at: user.last_login_at,
  }
}

function userSummary(user: UserRec): Schemas['AdminUserSummaryResponse'] {
  return {
    id: user.id,
    phone_number: user.phone_number,
    email: user.email,
    is_active: user.is_active,
    is_suspended: user.is_suspended,
    suspended_reason: user.suspension_reason,
    created_at: user.created_at,
  }
}

const PAID = new Set(['confirmed', 'completed'])

function userDetail(user: UserRec): Schemas['AdminUserDetailResponse'] {
  const db = getDb()
  const { trips, routes } = index()
  const own = db.bookings.filter((booking) => booking.passenger_id === user.id)
  const favourites = new Map<string, number>()
  for (const booking of own) {
    if (!PAID.has(booking.status)) continue
    const routeId = trips.get(booking.trip_id)?.route_id
    if (routeId) favourites.set(routeId, (favourites.get(routeId) ?? 0) + 1)
  }
  const channels = [
    ...new Set(
      db.payments
        .filter((payment) => payment.user_id === user.id && payment.channel !== 'wallet')
        .map((payment) => payment.channel),
    ),
  ]
  const complaints = db.complaints.filter((complaint) => complaint.filed_by === user.id)
  const wallet = walletFor(user.id)
  const driver = index().driverByUser.get(user.id)
  const owner = db.fleetOwners.find((candidate) => candidate.user_id === user.id)
  const digits = user.phone_number.replace(/\D/g, '')
  return {
    ...adminUser(user),
    preferred_language: 'en',
    phone_verified: user.phone_verified,
    email_verified: user.email_verified,
    payment_methods: channels.map((channel, position) => ({
      id: `${user.id.slice(0, 30)}${String(position).padStart(6, '0')}`,
      channel,
      number:
        channel === 'card'
          ? `•••• ${digits.slice(-4)}`
          : `${digits.slice(0, 5)}•••${digits.slice(-2)}`,
      label: channel === 'card' ? 'Visa debit' : null,
      is_default: position === 0,
    })),
    favourite_routes: [...favourites.entries()]
      .sort((a, b) => b[1] - a[1])
      .slice(0, 3)
      .map(([routeId, count]) => ({
        route_id: routeId,
        route_name: routes.get(routeId)?.name ?? 'Retired route',
        paid_bookings: count,
      })),
    bookings: {
      total: own.length,
      paid: own.filter((booking) => PAID.has(booking.status)).length,
      completed: own.filter((booking) => booking.status === 'completed').length,
      cancelled: own.filter((booking) =>
        ['cancelled', 'refund_pending', 'refunded'].includes(booking.status),
      ).length,
    },
    complaints: {
      total: complaints.length,
      open: complaints.filter((complaint) => OPEN.has(complaint.status)).length,
    },
    wallet_balance: money(wallet.balance),
    wallet_frozen_at: wallet.frozen_at,
    active_sessions: sessionsFor(user.id).filter((session) => !session.revoked_at).length,
    driver_id: driver?.id ?? null,
    fleet_owner_id: owner?.id ?? null,
    open_fraud_flags: 0,
  }
}

export const supportHandlers = [
  // -------------------------------------------------------- complaints
  // "stats" first: "/admin/complaints/:id" would take it otherwise.
  endpoint.get('/admin/complaints/stats', ['complaints:manage'], ({ url }) => {
    const period = resolvePeriod(url)
    if (period instanceof Response) return period
    const city = url.searchParams.get('city')
    const inCity = (record: ComplaintRec) => !city || tripCity(record.trip_id) === city
    const db = getDb()
    const now = Date.now()
    const complaints = db.complaints.filter(inCity)
    const open = complaints.filter((record) => OPEN.has(record.status))
    const overdue = (record: ComplaintRec) => Date.parse(record.due_at) < now

    const filed = new Daily()
    const byCategory = new Map(CATEGORIES.map((category) => [category, new Daily()]))
    for (const record of complaints) {
      filed.add(record.created_at)
      byCategory.get(record.category)!.add(record.created_at)
    }
    const trips = new Daily()
    for (const trip of db.trips) {
      if (trip.status === 'completed' && (!city || tripCity(trip.id) === city)) {
        trips.add(trip.actual_arrival_at ?? trip.scheduled_departure_at)
      }
    }
    const within = (when: string | null, days: string[]) =>
      Boolean(when && days.includes(when.slice(0, 10)))
    const responseHours = (days: string[]) =>
      averageHours(
        complaints
          .filter((record) => record.first_response_at && within(record.created_at, days))
          .map((record) => Date.parse(record.first_response_at!) - Date.parse(record.created_at)),
      )
    const resolutionHours = (days: string[]) =>
      averageHours(
        complaints
          .filter((record) => within(record.resolved_at, days))
          .map((record) => Date.parse(record.resolved_at!) - Date.parse(record.created_at)),
      )
    const filedFigure = countFigure(filed, period)
    const tripFigure = countFigure(trips, period)
    const perThousand = (count: number, total: number) =>
      total ? ((count * 1000) / total).toFixed(2) : null
    return {
      period: period.response,
      open: open.length,
      overdue: open.filter(overdue).length,
      unassigned: open.filter((record) => !record.assigned_to).length,
      by_priority: PRIORITIES.map((priority) => {
        const ofPriority = open.filter((record) => record.priority === priority)
        return {
          priority,
          resolution_hours: SLA_HOURS[priority],
          open: ofPriority.length,
          overdue: ofPriority.filter(overdue).length,
          unassigned: ofPriority.filter((record) => !record.assigned_to).length,
        }
      }),
      filed: filedFigure,
      per_1000_trips: {
        value: perThousand(filedFigure.value, tripFigure.value),
        previous: perThousand(filedFigure.previous, tripFigure.previous),
      },
      avg_first_response_hours: {
        value: responseHours(period.dates),
        previous: responseHours(period.previous),
      },
      avg_resolution_hours: {
        value: resolutionHours(period.dates),
        previous: resolutionHours(period.previous),
      },
      by_category: CATEGORIES.map((category) => {
        const figure = countFigure(byCategory.get(category)!, period)
        return { category, filed: figure.value, previous: figure.previous }
      }),
    } satisfies Schemas['ComplaintStatsResponse']
  }),

  endpoint.get('/admin/complaints/:complaintId', ['complaints:manage'], ({ params }) => {
    const record = find(params.complaintId)
    return record ? complaintDetail(record) : notFound('Complaint not found.')
  }),

  endpoint.get('/complaints/:complaintId', 'team', ({ params, admin }) => {
    const record = find(params.complaintId)
    if (!record || !hasAny(new Set(admin.permissions), ['complaints:manage'])) {
      return notFound('Complaint not found.')
    }
    return {
      id: record.id,
      filed_by: record.filed_by,
      booking_id: record.booking_id,
      trip_id: record.trip_id,
      category: record.category,
      subject: record.subject,
      description: record.description,
      status: record.status,
      resolved_by: record.resolved_by,
      resolved_at: record.resolved_at,
      resolution_notes: record.resolution_notes,
      created_at: record.created_at,
    } satisfies Schemas['ComplaintResponse']
  }),

  endpoint.patch('/admin/complaints/:complaintId', ['complaints:manage'], ({ params, body }) => {
    const record = find(params.complaintId)
    if (!record) return notFound('Complaint not found.')
    if (!OPEN.has(record.status)) {
      return invalid(`This complaint is already ${record.status}; it can no longer be changed.`)
    }
    const changes = (body ?? {}) as Schemas['ComplaintUpdateRequest']
    const now = new Date().toISOString()
    if ('assigned_to' in changes && changes.assigned_to !== record.assigned_to) {
      if (changes.assigned_to) {
        const assignee = teamMembers().find((member) => member.id === changes.assigned_to)
        const handles =
          assignee?.is_active &&
          !assignee.is_suspended &&
          (assignee.role === 'super_admin' || assignee.permissions.includes('complaints:manage'))
        if (!handles) {
          return errorResponse(
            422,
            'VALIDATION_ERROR',
            'Complaints can only be assigned to an active admin who handles complaints.',
            { param: 'assigned_to' },
          )
        }
      }
      record.assigned_to = changes.assigned_to ?? null
      record.assigned_at = changes.assigned_to ? now : null
    }
    if (changes.priority) record.priority = changes.priority
    if (changes.status === 'in_review' && record.status === 'open') {
      record.status = 'in_review'
      record.first_response_at ??= now
    }
    record.due_at = new Date(
      Date.parse(record.created_at) + SLA_HOURS[record.priority] * HOUR,
    ).toISOString()
    touch()
    return adminComplaint(record)
  }),

  endpoint.post(
    '/admin/complaints/:complaintId/notes',
    ['complaints:manage'],
    ({ params, admin, body }) => {
      const record = find(params.complaintId)
      if (!record) return notFound('Complaint not found.')
      const request = body as Schemas['ComplaintNoteRequest']
      const note = {
        id: ids.uuid(),
        kind: request.kind,
        body: request.body,
        author_id: admin.id,
        created_at: new Date().toISOString(),
      }
      record.notes.push(note)
      if (request.kind === 'message') record.first_response_at ??= note.created_at
      touch()
      return new Response(
        JSON.stringify({
          ...note,
          author_name: admin.full_name,
        } satisfies Schemas['ComplaintNoteResponse']),
        { status: 201, headers: { 'Content-Type': 'application/json' } },
      )
    },
  ),

  ...(['resolve', 'dismiss'] as const).map((action) =>
    endpoint.post(
      `/admin/complaints/:complaintId/${action}`,
      ['complaints:manage'],
      ({ params, admin, body }) => {
        const record = find(params.complaintId)
        if (!record) return notFound('Complaint not found.')
        if (!OPEN.has(record.status)) {
          return invalid(`Cannot decide a complaint already in status '${record.status}'.`)
        }
        const now = new Date().toISOString()
        record.status = action === 'resolve' ? 'resolved' : 'dismissed'
        record.resolved_by = admin.id
        record.resolved_at = now
        record.resolution_notes =
          (body as Schemas['ComplaintDecisionRequest'] | undefined)?.notes ?? null
        record.first_response_at ??= now
        touch()
        return adminComplaint(record)
      },
    ),
  ),

  // ---------------------------------------------------------- accounts
  endpoint.get('/admin/users', ['users:manage', 'users:suspend'], ({ url }) => {
    const search = (url.searchParams.get('search') ?? '').trim().toLowerCase()
    const roles = (url.searchParams.get('role') ?? '').split(',').filter(Boolean)
    const status = url.searchParams.get('status')
    const city = url.searchParams.get('city')
    const from = url.searchParams.get('signed_up_from')
    const to = url.searchParams.get('signed_up_to')
    const sort = url.searchParams.get('sort') ?? '-created_at'
    const digits = search.replace(/[\s-]/g, '')
    const local = digits.startsWith('0') ? `+233${digits.slice(1)}` : digits
    const rows = getDb().users.filter((user) => {
      if (roles.length && !roles.some((role) => (user.roles as string[]).includes(role)))
        return false
      if (status && userStatus(user) !== status) return false
      if (city && user.city !== city) return false
      const day = user.created_at.slice(0, 10)
      if (from && day < from) return false
      if (to && day > to) return false
      if (!search) return true
      return (
        user.full_name.toLowerCase().includes(search) ||
        (user.email ?? '').toLowerCase().includes(search) ||
        (digits.length >= 3 &&
          (user.phone_number.includes(digits) || user.phone_number.includes(local)))
      )
    })
    const key = sort.replace(/^-/, '') as 'created_at' | 'last_login_at' | 'full_name'
    rows.sort((a, b) => String(a[key] ?? '').localeCompare(String(b[key] ?? '')))
    if (sort.startsWith('-')) rows.reverse()
    if (url.searchParams.get('format') === 'csv') {
      return csvAnswer(rows.slice(0, 10_000).map(adminUser), 'users')
    }
    const page = paginate(rows, url)
    return { ...page, items: page.items.map(adminUser) }
  }),

  endpoint.get('/admin/users/:userId', ['users:manage', 'users:suspend'], ({ params }) => {
    const user = index().users.get(params.userId!)
    return user ? userDetail(user) : notFound('User not found.')
  }),

  endpoint.post('/admin/users/:userId/suspend', ['users:suspend'], ({ params, body }) => {
    const user = index().users.get(params.userId!)
    if (!user) return notFound('User not found.')
    user.is_suspended = true
    user.suspended_at = new Date().toISOString()
    user.suspension_reason = (body as Schemas['SuspendUserRequest']).reason
    revokeAllSessions(user.id)
    touch()
    return userSummary(user)
  }),

  endpoint.post('/admin/users/:userId/reactivate', ['users:suspend'], ({ params }) => {
    const user = index().users.get(params.userId!)
    if (!user) return notFound('User not found.')
    user.is_suspended = false
    user.suspended_at = null
    user.suspension_reason = null
    touch()
    return userSummary(user)
  }),

  endpoint.get('/admin/users/:userId/sessions', ['users:manage'], ({ params }) => {
    const user = index().users.get(params.userId!)
    if (!user) return notFound('User not found.')
    return sessionsFor(user.id)
      .filter((session) => !session.revoked_at)
      .map(({ revoked_at: _revoked, ...session }) => {
        void _revoked
        return session
      }) satisfies Schemas['AdminSessionResponse'][]
  }),

  endpoint.delete('/admin/users/:userId/sessions/:sessionId', ['users:manage'], ({ params }) => {
    const session = sessionsFor(params.userId!).find(
      (candidate) => candidate.id === params.sessionId && !candidate.revoked_at,
    )
    if (!session) return notFound('Session not found.')
    session.revoked_at = new Date().toISOString()
    touch()
    return noContent()
  }),

  // ---------------------------------------------------------------- team
  endpoint.get('/admin/admins', ['admins:manage'], () =>
    teamMembers().map((member): Schemas['TeamMemberResponse'] => ({
      ...member,
      granted_permissions: member.role === 'super_admin' ? [] : member.permissions,
    })),
  ),

  // ------------------------------------------------------------ ratings
  endpoint.get('/admin/drivers/:driverId/rating-summary', ['drivers:approve'], ({ params }) => {
    const driver = index().drivers.get(params.driverId!)
    if (!driver) return notFound('Driver not found.')
    const ratings = index().ratingsByDriver.get(driver.id) ?? []
    const average = (pick: (rating: (typeof ratings)[number]) => number) =>
      ratings.length
        ? (ratings.reduce((sum, rating) => sum + pick(rating), 0) / ratings.length).toFixed(2)
        : null
    return {
      driver_id: driver.id,
      average_score: average((rating) => rating.overall),
      rating_count: ratings.length,
      safety_average: average((rating) => rating.safety),
      cleanliness_average: average((rating) => rating.cleanliness),
      professionalism_average: average((rating) => rating.professionalism),
      timeliness_average: average((rating) => rating.timeliness),
    } satisfies Schemas['DriverRatingSummaryResponse']
  }),
]
