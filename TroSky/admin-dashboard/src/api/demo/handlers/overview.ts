import type { Schemas } from '@/api/types'
import { hasAny } from '@/lib/permissions'

import { DEMO_ACCOUNTS } from '../accounts'
import { DAY, getDb, HOUR, index, userName } from '../db'
import { endpoint, errorResponse } from '../http'
import { adminName } from '../views'
import { fraudAlerts } from './fraud'

const PAID = new Set(['confirmed', 'completed', 'refund_pending', 'refunded'])
const COLLECTED = new Set(['successful', 'partially_refunded', 'refunded'])

export interface Period {
  dates: string[]
  previous: string[]
  response: Schemas['PeriodResponse']
}

const dayKey = (value: string | number) => new Date(value).toISOString().slice(0, 10)

/** The backend's period rules: Ghana dates, default 30 days, at most 366. */
export function resolvePeriod(url: URL): Period | Response {
  const today = dayKey(Date.now())
  const to = url.searchParams.get('to') ?? today
  const end = Date.parse(`${to}T00:00:00Z`)
  const from = url.searchParams.get('from')
  const start = from ? Date.parse(`${from}T00:00:00Z`) : end - 29 * DAY
  if (Number.isNaN(start) || Number.isNaN(end) || start > end) {
    return errorResponse(422, 'VALIDATION_ERROR', '“from” must be on or before “to”.', {
      param: 'from',
    })
  }
  const days = Math.round((end - start) / DAY) + 1
  if (days > 366) {
    return errorResponse(422, 'VALIDATION_ERROR', 'A period can be at most 366 days.', {
      param: 'from',
    })
  }
  const dates = Array.from({ length: days }, (_, offset) => dayKey(start + offset * DAY))
  const previous = Array.from({ length: days }, (_, offset) =>
    dayKey(start - days * DAY + offset * DAY),
  )
  return {
    dates,
    previous,
    response: {
      from_date: dates[0]!,
      to_date: dates[dates.length - 1]!,
      previous_from_date: previous[0]!,
      previous_to_date: previous[previous.length - 1]!,
      days,
      city: url.searchParams.get('city'),
    },
  }
}

class Daily {
  private readonly values = new Map<string, number>()
  add(when: string | null | undefined, amount = 1): void {
    if (!when) return
    const key = dayKey(when)
    this.values.set(key, (this.values.get(key) ?? 0) + amount)
  }
  get(key: string): number {
    return this.values.get(key) ?? 0
  }
}

function change(value: number, previous: number): string | null {
  return previous ? (((value - previous) / previous) * 100).toFixed(1) : null
}

export function countFigure(daily: Daily, period: Period): Schemas['CountFigure'] {
  const value = period.dates.reduce((sum, day) => sum + daily.get(day), 0)
  const previous = period.previous.reduce((sum, day) => sum + daily.get(day), 0)
  return {
    value,
    previous,
    change_percent: change(value, previous),
    series: period.dates.map((day) => ({ date: day, value: daily.get(day) })),
  }
}

export function moneyFigure(daily: Daily, period: Period): Schemas['MoneyFigure'] {
  const value = period.dates.reduce((sum, day) => sum + daily.get(day), 0)
  const previous = period.previous.reduce((sum, day) => sum + daily.get(day), 0)
  return {
    value: value.toFixed(2),
    previous: previous.toFixed(2),
    change_percent: change(value, previous),
    series: period.dates.map((day) => ({ date: day, value: daily.get(day).toFixed(2) })),
  }
}

export { Daily }

/** The city a trip runs in (its route's), for the ``city`` filters. */
export function tripCity(tripId: string | null | undefined): string | null {
  if (!tripId) return null
  const trip = index().trips.get(tripId)
  return trip ? (index().routes.get(trip.route_id)?.city ?? null) : null
}

// As the backend: only SOS (and critical fraud) are critical.
const COMPLAINT_SEVERITY: Record<string, Schemas['AlertResponse']['severity']> = {
  urgent: 'high',
  high: 'high',
  medium: 'medium',
  low: 'low',
}
const SEVERITY_ORDER: Record<string, number> = { critical: 0, high: 1, medium: 2, low: 3 }
const APPROVAL_TARGET_HOURS = 48
const EXPIRY_WARNING_DAYS = 30
const EXPIRY_SOON_DAYS = 7

export const overviewHandlers = [
  endpoint.get('/admin/reports/overview', ['reports:view'], ({ url }) => {
    const period = resolvePeriod(url)
    if (period instanceof Response) return period
    const db = getDb()
    const city = url.searchParams.get('city')
    const inCity = (tripId: string | null | undefined) => !city || tripCity(tripId) === city

    const newUsers = new Daily()
    const newPassengers = new Daily()
    const newDrivers = new Daily()
    for (const user of db.users) {
      newUsers.add(user.created_at)
      if (user.roles.includes('passenger')) newPassengers.add(user.created_at)
      if (user.roles.includes('driver')) newDrivers.add(user.created_at)
    }
    const paidBookings = new Daily()
    for (const booking of db.bookings) {
      if (PAID.has(booking.status) && inCity(booking.trip_id)) paidBookings.add(booking.created_at)
    }
    const completedTrips = new Daily()
    for (const trip of db.trips) {
      if (trip.status === 'completed' && inCity(trip.id))
        completedTrips.add(trip.scheduled_departure_at)
    }
    const takings = new Daily()
    const { bookings } = index()
    let revenue = 0
    for (const payment of db.payments) {
      if (payment.purpose !== 'booking_payment') continue
      if (payment.status === 'successful' || payment.status === 'partially_refunded')
        revenue += payment.amount
      const trip = payment.booking_id ? bookings.get(payment.booking_id)?.trip_id : null
      if (COLLECTED.has(payment.status) && inCity(trip))
        takings.add(payment.completed_at, payment.amount)
    }
    const complaints = new Daily()
    for (const complaint of db.complaints)
      if (inCity(complaint.trip_id)) complaints.add(complaint.created_at)
    const sos = new Daily()
    for (const alert of db.sosAlerts) if (inCity(alert.trip_id)) sos.add(alert.created_at)

    const roles = (role: 'passenger' | 'driver' | 'fleet_owner') =>
      db.users.filter((user) => user.roles.includes(role)).length
    return {
      total_users: db.users.length + DEMO_ACCOUNTS.length,
      total_passengers: roles('passenger'),
      total_drivers: roles('driver'),
      total_fleet_owners: roles('fleet_owner'),
      total_bookings: db.bookings.length,
      completed_bookings: db.bookings.filter((booking) => booking.status === 'completed').length,
      total_revenue: revenue.toFixed(2),
      active_trips: db.trips.filter((trip) =>
        ['boarding', 'in_progress', 'paused'].includes(trip.status),
      ).length,
      open_complaints: db.complaints.filter((complaint) =>
        ['open', 'in_review'].includes(complaint.status),
      ).length,
      active_sos_alerts: db.sosAlerts.filter((alert) =>
        ['active', 'acknowledged'].includes(alert.status),
      ).length,
      period: period.response,
      figures: {
        // Figures that cannot be tied to a city are left out of a city's.
        new_users: city ? null : countFigure(newUsers, period),
        new_passengers: city ? null : countFigure(newPassengers, period),
        new_drivers: city ? null : countFigure(newDrivers, period),
        paid_bookings: countFigure(paidBookings, period),
        completed_trips: countFigure(completedTrips, period),
        booking_payments: moneyFigure(takings, period),
        complaints: countFigure(complaints, period),
        sos_alerts: countFigure(sos, period),
      },
    } satisfies Schemas['PlatformOverviewResponse']
  }),

  endpoint.get(
    '/admin/alerts',
    [
      'sos:review',
      'complaints:manage',
      'drivers:approve',
      'vehicles:approve',
      'fraud:view',
      'fraud:manage',
    ],
    ({ url, admin }): Schemas['AlertsResponse'] => {
      const limit = Math.min(Number(url.searchParams.get('limit') ?? 50), 200)
      const granted = new Set<string>(admin.permissions)
      const db = getDb()
      const now = Date.now()
      const items: Schemas['AlertResponse'][] = []
      const counts: Record<string, number> = {}

      if (hasAny(granted, ['sos:review'])) {
        const active = db.sosAlerts.filter((alert) => alert.status === 'active')
        counts.sos_active = active.length
        for (const alert of active) {
          const person = index().users.get(alert.triggered_by)
          items.push({
            type: 'sos_active',
            severity: 'critical',
            title: `SOS from ${person?.full_name ?? person?.phone_number ?? 'a rider'}`,
            entity_type: 'sos_alert',
            entity_id: alert.id,
            since: alert.created_at,
            details: {
              trip_id: alert.trip_id,
              triggered_by: alert.triggered_by,
              phone_number: person?.phone_number ?? null,
            },
          })
        }
      }
      if (hasAny(granted, ['complaints:manage'])) {
        const late = db.complaints.filter(
          (complaint) =>
            ['open', 'in_review'].includes(complaint.status) && Date.parse(complaint.due_at) < now,
        )
        counts.complaint_overdue = late.length
        for (const complaint of late) {
          items.push({
            type: 'complaint_overdue',
            severity: COMPLAINT_SEVERITY[complaint.priority] ?? 'medium',
            title: `Complaint overdue: ${complaint.subject}`,
            entity_type: 'complaint',
            entity_id: complaint.id,
            since: complaint.due_at,
            details: {
              priority: complaint.priority,
              category: complaint.category,
              status: complaint.status,
              assigned_to: complaint.assigned_to,
              assignee_name: adminName(complaint.assigned_to),
            },
          })
        }
      }
      const drivers = hasAny(granted, ['drivers:approve'])
      const vehicles = hasAny(granted, ['vehicles:approve'])
      if (drivers || vehicles) {
        const until = now + EXPIRY_WARNING_DAYS * DAY
        const expiring: {
          type: string
          label: string
          ownerType: string
          ownerId: string
          on: string
        }[] = []
        if (drivers) {
          for (const driver of db.drivers) {
            if (driver.status !== 'approved') continue
            if (Date.parse(driver.license_expiry) <= until) {
              expiring.push({
                type: 'driver_license',
                label: userName(driver.user_id) ?? 'a driver',
                ownerType: 'driver',
                ownerId: driver.id,
                on: driver.license_expiry,
              })
            }
          }
        }
        if (vehicles) {
          for (const vehicle of db.vehicles) {
            if (vehicle.status !== 'approved') continue
            if (Date.parse(vehicle.insurance_expiry) <= until) {
              expiring.push({
                type: 'vehicle_insurance',
                label: vehicle.registration_number,
                ownerType: 'vehicle',
                ownerId: vehicle.id,
                on: vehicle.insurance_expiry,
              })
            }
          }
        }
        counts.document_expiring = expiring.length
        for (const document of expiring) {
          const expired = Date.parse(document.on) < Date.parse(dayKey(now))
          const soon = Date.parse(document.on) <= now + EXPIRY_SOON_DAYS * DAY
          const name =
            document.type === 'driver_license' ? 'Driver’s licence' : 'Insurance certificate'
          const date = new Date(document.on).toLocaleDateString('en-GB', {
            day: '2-digit',
            month: 'short',
            year: 'numeric',
          })
          items.push({
            type: 'document_expiring',
            severity: expired ? 'high' : soon ? 'medium' : 'low',
            title: `${name} for ${document.label} ${expired ? 'expired on' : 'expires on'} ${date}`,
            entity_type: document.ownerType,
            entity_id: document.ownerId,
            since: `${document.on}T00:00:00Z`,
            details: { document_type: document.type, expires_on: document.on, expired },
          })
        }
        const waitingSince = now - APPROVAL_TARGET_HOURS * HOUR
        const waiting = [
          ...(drivers
            ? db.drivers
                .filter(
                  (driver) =>
                    driver.status === 'pending' && Date.parse(driver.created_at) < waitingSince,
                )
                .map((driver) => ({
                  kind: 'driver',
                  id: driver.id,
                  label: userName(driver.user_id) ?? 'driver',
                  since: driver.created_at,
                }))
            : []),
          ...(vehicles
            ? db.vehicles
                .filter(
                  (vehicle) =>
                    vehicle.status === 'pending' && Date.parse(vehicle.created_at) < waitingSince,
                )
                .map((vehicle) => ({
                  kind: 'vehicle',
                  id: vehicle.id,
                  label: vehicle.registration_number,
                  since: vehicle.created_at,
                }))
            : []),
        ]
        counts.approval_waiting = waiting.length
        for (const item of waiting) {
          items.push({
            type: 'approval_waiting',
            severity: 'medium',
            title: `${item.kind === 'driver' ? 'Driver' : 'Vehicle'} ${item.label} waiting for approval`,
            entity_type: item.kind,
            entity_id: item.id,
            since: item.since,
            details: {
              kind: item.kind,
              waiting_hours: Math.floor((now - Date.parse(item.since)) / HOUR),
            },
          })
        }
      }
      if (hasAny(granted, ['fraud:view', 'fraud:manage'])) {
        const risky = fraudAlerts()
        counts.fraud_high_risk = risky.length
        items.push(...risky)
      }
      items.sort(
        (a, b) =>
          (SEVERITY_ORDER[a.severity] ?? 9) - (SEVERITY_ORDER[b.severity] ?? 9) ||
          a.since.localeCompare(b.since),
      )
      return {
        items: items.slice(0, limit),
        counts,
        total: Object.values(counts).reduce((sum, count) => sum + count, 0),
      }
    },
  ),
]
