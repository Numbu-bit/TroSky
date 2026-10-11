import { HttpResponse } from 'msw'

import type { Schemas } from '@/api/types'
import { hasAny, PERMISSIONS, type AdminRole, type Permission } from '@/lib/permissions'

import { addTeamMember, changeTeamMember, removeTeamMember, teamMembers } from '../accounts'
import { getDb, index, touch } from '../db'
import { postToWallet, revokeAllSessions, walletFor } from '../db/extras'
import { FLAG_DEFS, platformState, SETTING_DEFAULTS, type AuditRec } from '../db/platform'
import {
  csvAnswer,
  endpoint,
  errorResponse,
  notFound,
  pageParams,
  paginate,
  QueryError,
} from '../http'
import { Random } from '../random'
import { adminName, money } from '../views'
import { paymentReference } from './bookings'

const ids = new Random(5050)
const RANK: Record<AdminRole, number> = { staff: 1, admin: 2, super_admin: 3 }

function auditResponse(entry: AuditRec): Schemas['AuditLogResponse'] {
  return { ...entry, actor_name: adminName(entry.actor_user_id) } as Schemas['AuditLogResponse']
}

// ---------------------------------------------------------------- settings
function settingsList(): Schemas['SettingResponse'][] {
  const changed = platformState().settings
  return Object.entries(SETTING_DEFAULTS).map(([key, value]) => {
    const override = changed.get(key)
    return {
      key,
      value: (override ? override.value : value) as Schemas['SettingResponse']['value'],
      overridden: Boolean(override),
      updated_by: override?.updated_by ?? null,
      updated_at: override?.updated_at ?? null,
    }
  })
}

/** The backend's limits (SettingsValues); null for a valid value. */
function settingProblem(key: string, value: unknown): string | null {
  const number = Number(value)
  const decimal = (max: number) =>
    Number.isFinite(number) &&
    number >= 0 &&
    number <= max &&
    /^\d+(\.\d{1,2})?$/.test(String(value))
      ? null
      : `Input should be a number from 0 to ${max} with at most 2 decimals`
  const whole = (min: number, max: number) =>
    Number.isInteger(number) && number >= min && number <= max
      ? null
      : `Input should be a whole number from ${min} to ${max}`
  switch (key) {
    case 'platform_fee_flat_per_seat':
    case 'platform_fee_percent':
    case 'driver_earnings_share_percent':
      return decimal(100)
    case 'reservation_hold_seconds':
      return whole(60, 3600)
    case 'live_update_interval_seconds':
      return whole(2, 60)
    case 'approval_target_hours':
      return whole(1, 720)
    case 'complaint_sla_hours': {
      const hours = value as Record<string, unknown>
      const keys = ['low', 'medium', 'high', 'urgent']
      const ok =
        typeof hours === 'object' &&
        hours !== null &&
        Object.keys(hours).length === 4 &&
        keys.every(
          (priority) =>
            Number.isInteger(hours[priority]) &&
            Number(hours[priority]) >= 1 &&
            Number(hours[priority]) <= 720,
        )
      return ok ? null : 'Value error, needs 1-720 hours for each of low, medium, high, urgent'
    }
    case 'sos_escalation_contacts': {
      const contacts = value as { name?: string; phone_number?: string; role?: string }[]
      if (!Array.isArray(contacts) || contacts.length > 20)
        return 'List should have at most 20 items'
      const bad = contacts.find(
        (contact) =>
          !contact?.name?.trim() ||
          !contact.role?.trim() ||
          !contact.phone_number ||
          contact.phone_number.length < 5 ||
          contact.phone_number.length > 20,
      )
      return bad ? 'Each contact needs a name, a role and a phone number of 5-20 characters' : null
    }
    case 'enabled_cities':
      return Array.isArray(value) &&
        value.length <= 50 &&
        value.every((city) => typeof city === 'string' && city.trim())
        ? null
        : 'List should have at most 50 city names'
    default:
      return 'Unknown setting'
  }
}

function flagResponse(key: string): Schemas['FeatureFlagResponse'] {
  const definition = FLAG_DEFS[key]!
  const changed = platformState().flags.get(key)
  return {
    key,
    description: definition.description,
    enabled: changed?.value.enabled ?? definition.default,
    rollout_percent: changed?.value.rollout_percent ?? 100,
    updated_by: changed?.updated_by ?? null,
    updated_at: changed?.updated_at ?? '2026-09-01T09:00:00Z',
  }
}

// ----------------------------------------------------------------- search
function searchHits(kind: string, q: string, limit: number): Schemas['SearchHit'][] {
  const lower = q.toLowerCase()
  const digits = q.replace(/[\s-]/g, '')
  const local = digits.startsWith('0') ? `+233${digits.slice(1)}` : digits
  const db = getDb()
  const { users, routes } = index()
  switch (kind) {
    case 'users':
      return db.users
        .filter(
          (user) =>
            user.id === q ||
            user.full_name.toLowerCase().includes(lower) ||
            (user.email ?? '').toLowerCase().startsWith(lower) ||
            (digits.length >= 3 &&
              (user.phone_number.includes(digits) || user.phone_number.startsWith(local))),
        )
        .slice(0, limit)
        .map((user) => ({
          id: user.id,
          title: user.full_name || user.phone_number,
          subtitle: [user.phone_number, user.email].filter(Boolean).join(' · '),
          status: user.is_suspended ? 'suspended' : user.is_active ? 'active' : 'inactive',
        }))
    case 'drivers':
      return db.drivers
        .filter((driver) => {
          const user = users.get(driver.user_id)
          return (
            driver.id === q ||
            driver.license_number.toLowerCase().includes(lower) ||
            (user?.full_name ?? '').toLowerCase().includes(lower)
          )
        })
        .slice(0, limit)
        .map((driver) => ({
          id: driver.id,
          title: users.get(driver.user_id)?.full_name ?? driver.license_number,
          subtitle: `Licence ${driver.license_number}`,
          status: driver.status,
        }))
    case 'vehicles': {
      const plate = q.replace(/[\s-]/g, '').toUpperCase()
      return db.vehicles
        .filter(
          (vehicle) =>
            vehicle.id === q ||
            (plate.length >= 2 &&
              vehicle.registration_number.replace(/[\s-]/g, '').includes(plate)),
        )
        .slice(0, limit)
        .map((vehicle) => ({
          id: vehicle.id,
          title: vehicle.registration_number,
          subtitle: `${vehicle.make} ${vehicle.model}`,
          status: vehicle.status,
        }))
    }
    case 'trips':
      return db.trips
        .filter((trip) => trip.id === q || trip.id.startsWith(lower))
        .slice(0, limit)
        .map((trip) => ({
          id: trip.id,
          title: routes.get(trip.route_id)?.name ?? 'Trip',
          subtitle: `Departs ${trip.scheduled_departure_at.slice(0, 16).replace('T', ' ')} UTC`,
          status: trip.status,
        }))
    case 'bookings':
      return db.bookings
        .filter((booking) => booking.id === q || booking.reference.startsWith(q.toUpperCase()))
        .slice(0, limit)
        .map((booking) => ({
          id: booking.id,
          title: booking.reference,
          subtitle: booking.passengers[0]?.full_name ?? null,
          status: booking.status,
        }))
    case 'payments':
      return db.payments
        .filter(
          (payment) => payment.id === q || paymentReference(payment).startsWith(q.toUpperCase()),
        )
        .slice(0, limit)
        .map((payment) => ({
          id: payment.id,
          title: paymentReference(payment),
          subtitle: `${money(payment.amount)} GHS by ${payment.channel.replace(/_/g, ' ')}`,
          status: payment.status,
        }))
    default:
      return []
  }
}

const SEARCH_PERMISSIONS: Record<string, Permission[]> = {
  users: ['users:manage', 'users:suspend'],
  drivers: ['drivers:approve', 'trips:monitor_live'],
  vehicles: ['vehicles:approve', 'trips:monitor_live'],
  trips: ['trips:manage', 'trips:monitor_live'],
  bookings: ['bookings:view_any'],
  payments: ['payments:review', 'refunds:approve'],
}

function teamResponse(id: string): Schemas['TeamMemberResponse'] | null {
  const member = teamMembers().find((candidate) => candidate.id === id)
  if (!member) return null
  return {
    ...member,
    permissions: member.role === 'staff' ? member.permissions : [...PERMISSIONS],
    granted_permissions: member.role === 'staff' ? member.permissions : [],
  }
}

export const platformHandlers = [
  // --------------------------------------------------------- audit log
  endpoint.get('/admin/audit-logs', ['audit_logs:view'], ({ url }) => {
    const actor = url.searchParams.get('actor_id')
    const action = url.searchParams.get('action')
    const entityType = url.searchParams.get('entity_type')
    const entityId = url.searchParams.get('entity_id')
    const from = url.searchParams.get('from')
    const to = url.searchParams.get('to')
    const rows = platformState().audit.filter((entry) => {
      const day = entry.created_at.slice(0, 10)
      return (
        (!actor || entry.actor_user_id === actor) &&
        (!action || entry.action === action) &&
        (!entityType || entry.entity_type === entityType) &&
        (!entityId || entry.entity_id === entityId) &&
        (!from || day >= from) &&
        (!to || day <= to)
      )
    })
    if (url.searchParams.get('format') === 'csv') {
      return csvAnswer(
        rows.slice(0, 10_000).map(auditResponse) as unknown as Record<string, unknown>[],
        'audit-log',
      )
    }
    const page = paginate(rows, url)
    return { ...page, items: page.items.map(auditResponse) }
  }),

  endpoint.get('/admin/audit-logs/:entryId', ['audit_logs:view'], ({ params }) => {
    const entry = platformState().audit.find((candidate) => candidate.id === params.entryId)
    return entry ? auditResponse(entry) : notFound('Audit entry not found.')
  }),

  // --------------------------------------------------- settings & flags
  endpoint.get('/admin/settings', ['system_settings:manage'], () => settingsList()),

  endpoint.patch('/admin/settings', ['system_settings:manage'], ({ admin, body }) => {
    const changes = { ...((body ?? {}) as Record<string, unknown>) }
    delete changes.reason
    const unknown = Object.keys(changes).filter((key) => !(key in SETTING_DEFAULTS))
    if (unknown.length)
      return errorResponse(422, 'VALIDATION_ERROR', 'Unknown settings.', {
        unknown: unknown.sort(),
      })
    const errors = Object.entries(changes)
      .filter(([, value]) => value !== null)
      .map(([key, value]) => [key, settingProblem(key, value)] as const)
      .filter(([, problem]) => problem)
      .map(([key, problem]) => ({ loc: [key], msg: problem }))
    if (errors.length) return errorResponse(422, 'VALIDATION_ERROR', 'Invalid setting.', { errors })
    const state = platformState()
    const now = new Date().toISOString()
    for (const [key, value] of Object.entries(changes)) {
      if (value === null) state.settings.delete(key)
      else state.settings.set(key, { value, updated_by: admin.id, updated_at: now })
    }
    touch()
    return settingsList()
  }),

  endpoint.get('/admin/feature-flags', ['feature_flags:manage'], () =>
    Object.keys(FLAG_DEFS).map(flagResponse),
  ),

  endpoint.patch(
    '/admin/feature-flags/:key',
    ['feature_flags:manage'],
    ({ params, admin, body }) => {
      const key = params.key!
      const definition = FLAG_DEFS[key]
      if (!definition) return notFound('No such feature flag.')
      const changes = (body ?? {}) as Schemas['FeatureFlagUpdateRequest']
      if (changes.rollout_percent !== undefined && changes.rollout_percent !== null) {
        if (
          !Number.isInteger(changes.rollout_percent) ||
          changes.rollout_percent < 0 ||
          changes.rollout_percent > 100
        ) {
          return errorResponse(422, 'VALIDATION_ERROR', 'The submitted data is invalid.', {
            errors: [{ loc: ['body', 'rollout_percent'], msg: 'Input should be from 0 to 100' }],
          })
        }
        if (definition.platformWide && changes.rollout_percent !== 100) {
          return errorResponse(
            422,
            'VALIDATION_ERROR',
            'This flag switches a platform-wide setting: it is on or off for everyone.',
            { flag: key },
          )
        }
      }
      const current = flagResponse(key)
      platformState().flags.set(key, {
        value: {
          enabled: typeof changes.enabled === 'boolean' ? changes.enabled : current.enabled,
          rollout_percent: changes.rollout_percent ?? current.rollout_percent,
        },
        updated_by: admin.id,
        updated_at: new Date().toISOString(),
      })
      touch()
      return flagResponse(key)
    },
  ),

  // ----------------------------------------------------------- wallets
  endpoint.get('/admin/wallets/:userId', ['wallet:adjust'], ({ params, url }) => {
    const user = index().users.get(params.userId!)
    if (!user) return notFound('User not found.')
    const wallet = walletFor(user.id)
    const { limit, offset } = pageParams(url)
    const held = getDb()
      .withdrawals.filter((payout) => payout.user_id === user.id && payout.status === 'pending')
      .reduce((sum, payout) => sum + payout.amount, 0)
    return {
      user: { id: user.id, full_name: user.full_name, phone_number: user.phone_number },
      balance: money(wallet.balance),
      currency: 'GHS',
      held_for_withdrawals: money(held),
      frozen_at: wallet.frozen_at,
      frozen_reason: wallet.frozen_reason,
      transactions: wallet.transactions.slice(offset, offset + limit).map((tx) => ({
        ...tx,
        amount: money(tx.amount),
        balance_after: money(tx.balance_after),
      })),
      transactions_total: wallet.transactions.length,
      limit,
      offset,
    } satisfies Schemas['AdminWalletResponse']
  }),

  endpoint.post('/admin/wallets/:userId/adjustments', ['wallet:adjust'], ({ params, body }) => {
    const user = index().users.get(params.userId!)
    if (!user) return notFound('User not found.')
    const request = body as Schemas['WalletAdjustmentRequest']
    const amount = Number(request.amount)
    const problems = []
    if (
      !Number.isFinite(amount) ||
      amount <= 0 ||
      !/^\d+(\.\d{1,2})?$/.test(String(request.amount))
    ) {
      problems.push({
        loc: ['body', 'amount'],
        msg: 'Input should be greater than 0, with at most 2 decimals',
      })
    }
    if ((request.reason ?? '').trim().length < 5) {
      problems.push({ loc: ['body', 'reason'], msg: 'String should have at least 5 characters' })
    }
    if (problems.length)
      return errorResponse(422, 'VALIDATION_ERROR', 'The submitted data is invalid.', {
        errors: problems,
      })
    const wallet = walletFor(user.id)
    if (request.direction === 'debit' && wallet.balance < amount) {
      return errorResponse(
        402,
        'INSUFFICIENT_WALLET_BALANCE',
        'The wallet balance is insufficient for this transaction.',
      )
    }
    const transaction = postToWallet(user.id, {
      entry_type: request.direction,
      amount,
      reference_type: 'admin_adjustment',
      reference_id: null,
      description: request.reference ? `${request.reason} (${request.reference})` : request.reason,
    })
    return HttpResponse.json(
      {
        transaction: {
          ...transaction,
          amount: money(transaction.amount),
          balance_after: money(transaction.balance_after),
        },
        balance: money(wallet.balance),
      } satisfies Schemas['WalletAdjustmentResponse'],
      { status: 201 },
    )
  }),

  // ------------------------------------------------------------ search
  endpoint.get(
    '/admin/search',
    [
      'bookings:view_any',
      'drivers:approve',
      'payments:review',
      'refunds:approve',
      'trips:manage',
      'trips:monitor_live',
      'users:manage',
      'users:suspend',
      'vehicles:approve',
    ],
    ({ url, admin }) => {
      const q = (url.searchParams.get('q') ?? '').trim()
      if (q.length < 2) throw new QueryError('q', 'String should have at least 2 characters')
      const limit = Number(url.searchParams.get('limit') ?? 5)
      if (!Number.isInteger(limit) || limit < 1 || limit > 20) {
        throw new QueryError('limit', 'Input should be less than or equal to 20')
      }
      const granted = new Set<string>(admin.permissions)
      const searched = Object.keys(SEARCH_PERMISSIONS).filter((kind) =>
        hasAny(granted, SEARCH_PERMISSIONS[kind]),
      )
      const result: Record<string, Schemas['SearchHit'][]> = {}
      for (const kind of Object.keys(SEARCH_PERMISSIONS)) {
        result[kind] = searched.includes(kind) ? searchHits(kind, q, limit) : []
      }
      return {
        query: q,
        searched: searched as Schemas['SearchResponse']['searched'],
        users: result.users!,
        drivers: result.drivers!,
        vehicles: result.vehicles!,
        trips: result.trips!,
        bookings: result.bookings!,
        payments: result.payments!,
      } satisfies Schemas['SearchResponse']
    },
  ),

  // -------------------------------------------------------------- team
  endpoint.post('/admin/admins', ['admins:manage'], ({ admin, body }) => {
    const request = body as Schemas['TeamInviteRequest']
    const role = request.role as AdminRole
    const permissions = (request.permissions ?? []) as Permission[]
    if (RANK[role] > RANK[admin.role])
      return errorResponse(403, 'FORBIDDEN', 'You cannot give someone a role above your own.')
    if (role !== 'staff' && permissions.length) {
      return errorResponse(
        422,
        'VALIDATION_ERROR',
        'Only staff are given permissions one by one; an admin holds them all.',
        { param: 'permissions' },
      )
    }
    if (admin.role !== 'super_admin') {
      const beyond = permissions.filter((permission) => !admin.permissions.includes(permission))
      if (beyond.length) {
        return errorResponse(403, 'FORBIDDEN', 'You cannot grant a permission you do not hold.', {
          permissions: beyond.sort(),
        })
      }
    }
    const digits = request.phone_number.replace(/[\s-]/g, '')
    const phone = digits.startsWith('0') ? `+233${digits.slice(1)}` : digits
    if (!/^\+233\d{9}$/.test(phone)) {
      return errorResponse(422, 'VALIDATION_ERROR', 'Enter a valid Ghana phone number.', {
        param: 'phone_number',
      })
    }
    if (
      teamMembers().some(
        (member) =>
          member.phone_number === phone || (request.email && member.email === request.email),
      )
    ) {
      return errorResponse(409, 'ALREADY_ON_TEAM', 'This person is already on the admin team.')
    }
    const existing = getDb().users.find(
      (user) => user.phone_number === phone || (request.email && user.email === request.email),
    )
    const id = existing?.id ?? ids.uuid()
    addTeamMember({
      id,
      full_name: existing?.full_name ?? request.full_name,
      phone_number: phone,
      email: existing?.email ?? request.email ?? '',
      role,
      permissions: role === 'staff' ? permissions : [...PERMISSIONS],
      is_active: true,
      is_suspended: false,
      last_login_at: null,
      created_at: new Date().toISOString(),
    })
    touch()
    return HttpResponse.json(
      {
        member: teamResponse(id)!,
        new_account: !existing,
        invitation_sent: !existing,
      } satisfies Schemas['TeamInviteResponse'],
      { status: 201 },
    )
  }),

  endpoint.patch('/admin/admins/:adminId', ['admins:manage'], ({ params, admin, body }) => {
    const id = params.adminId!
    if (id === admin.id)
      return errorResponse(403, 'FORBIDDEN', 'You cannot change your own access.')
    const member = teamMembers().find((candidate) => candidate.id === id)
    if (!member) return notFound('Not on the admin team.')
    if (RANK[member.role] > RANK[admin.role]) {
      return errorResponse(
        403,
        'FORBIDDEN',
        'You cannot change someone whose role is above your own.',
      )
    }
    const request = (body ?? {}) as Schemas['TeamUpdateRequest']
    if (request.active === false) {
      removeTeamMember(id)
      revokeAllSessions(id)
      touch()
      return { on_team: false, member: null } satisfies Schemas['TeamUpdateResponse']
    }
    const role = (request.role ?? member.role) as AdminRole
    const permissions = (request.permissions ??
      (role === 'staff' ? member.permissions : [])) as Permission[]
    if (RANK[role] > RANK[admin.role])
      return errorResponse(403, 'FORBIDDEN', 'You cannot give someone a role above your own.')
    if (role !== 'staff' && request.permissions?.length) {
      return errorResponse(
        422,
        'VALIDATION_ERROR',
        'Only staff are given permissions one by one; an admin holds them all.',
        { param: 'permissions' },
      )
    }
    if (admin.role !== 'super_admin') {
      const beyond = permissions.filter((permission) => !admin.permissions.includes(permission))
      if (beyond.length) {
        return errorResponse(403, 'FORBIDDEN', 'You cannot grant a permission you do not hold.', {
          permissions: beyond.sort(),
        })
      }
    }
    changeTeamMember(id, role, permissions)
    touch()
    return { on_team: true, member: teamResponse(id) } satisfies Schemas['TeamUpdateResponse']
  }),
]
