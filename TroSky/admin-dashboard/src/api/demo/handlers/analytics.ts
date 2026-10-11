import type { Schemas } from '@/api/types'

import { DAY, getDb, index, routeStops } from '../db'
import type { BookingRec, PaymentRec, TripRec } from '../db/model'
import { csvAnswer, endpoint, errorResponse } from '../http'
import { money } from '../views'
import { countFigure, Daily, moneyFigure, resolvePeriod, tripCity, type Period } from './overview'

const dayOf = (iso: string) => iso.slice(0, 10) // Accra is UTC+0 all year
const PAID = new Set(['confirmed', 'completed'])
const COLLECTED = new Set(['successful', 'refunded', 'partially_refunded'])
const DAY_NAMES = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'] as const

function change(value: number, previous: number): string | null {
  return previous ? (((value - previous) / previous) * 100).toFixed(1) : null
}

const ratio = (part: number, whole: number, places = 4) =>
  whole ? (part / whole).toFixed(places) : null

/** A small, stable pseudo-random number in [0, 1) for a key (no draws from the seed). */
function noise(key: string): number {
  let hash = 2166136261
  for (const character of key) hash = Math.imul(hash ^ character.charCodeAt(0), 16777619)
  return ((hash >>> 0) % 10_000) / 10_000
}

interface Scope {
  city: string | null
  route: string | null
  fleet: string | null
}

function inScope(trip: TripRec | undefined, scope: Scope): boolean {
  if (!trip) return !scope.city && !scope.route && !scope.fleet
  if (scope.city && tripCity(trip.id) !== scope.city) return false
  if (scope.route && trip.route_id !== scope.route) return false
  if (scope.fleet) {
    const vehicle = trip.vehicle_id ? index().vehicles.get(trip.vehicle_id) : undefined
    if (vehicle?.fleet_id !== scope.fleet) return false
  }
  return true
}

const tripOf = (booking: BookingRec | undefined) =>
  booking ? index().trips.get(booking.trip_id) : undefined
const bookingOf = (payment: PaymentRec) =>
  payment.booking_id ? index().bookings.get(payment.booking_id) : undefined

/** Searches aren't kept by the demo: about 2.2-2.8 per booking made, by day and stop. */
function searchesFor(bookings: number, key: string): number {
  return Math.round(bookings * (2.2 + 0.6 * noise(key)))
}

// ----------------------------------------------------------------- revenue
function revenue(period: Period, scope: Scope): Schemas['RevenueResponse'] {
  const db = getDb()
  const gross = new Daily()
  const fees = new Daily()
  const paid = new Daily()
  const refunds = new Daily()
  const attempts = new Daily()
  const failures = new Daily()
  const byMethod = new Map<string, Daily>()
  const byRoute = new Map<string, { amount: number; payments: number }>()
  const byFleet = new Map<string, { amount: number; payments: number }>()
  const byHour = Array.from({ length: 24 }, () => ({ amount: 0, payments: 0 }))
  const inPeriod = new Set(period.dates)
  for (const payment of db.payments) {
    if (payment.purpose !== 'booking_payment') continue
    const booking = bookingOf(payment)
    const trip = tripOf(booking)
    if (!inScope(trip, scope)) continue
    attempts.add(payment.created_at)
    if (payment.status === 'failed') failures.add(payment.created_at)
    if (!COLLECTED.has(payment.status)) continue
    const when = payment.completed_at ?? payment.created_at
    gross.add(when, payment.amount)
    paid.add(when)
    if (booking) fees.add(when, booking.platform_fee)
    const method = byMethod.get(payment.channel) ?? new Daily()
    method.add(when, payment.amount)
    byMethod.set(payment.channel, method)
    if (!inPeriod.has(dayOf(when))) continue
    const hour = new Date(when).getUTCHours()
    byHour[hour]!.amount += payment.amount
    byHour[hour]!.payments += 1
    if (trip) {
      const route = byRoute.get(trip.route_id) ?? { amount: 0, payments: 0 }
      route.amount += payment.amount
      route.payments += 1
      byRoute.set(trip.route_id, route)
      const fleetId = trip.vehicle_id ? index().vehicles.get(trip.vehicle_id)?.fleet_id : undefined
      if (fleetId) {
        const fleet = byFleet.get(fleetId) ?? { amount: 0, payments: 0 }
        fleet.amount += payment.amount
        fleet.payments += 1
        byFleet.set(fleetId, fleet)
      }
    }
  }
  for (const refund of db.refunds) {
    if (refund.status !== 'completed' || !refund.reviewed_at) continue
    const booking = refund.booking_id ? index().bookings.get(refund.booking_id) : undefined
    if (!inScope(tripOf(booking), scope)) continue
    refunds.add(refund.reviewed_at, refund.amount)
  }
  const net = new Daily()
  for (const date of [...period.previous, ...period.dates]) {
    net.add(`${date}T12:00:00Z`, gross.get(date) - refunds.get(date))
  }
  const grossFigure = moneyFigure(gross, period)
  const paidFigure = countFigure(paid, period)
  const sum = (daily: Daily, dates: string[]) =>
    dates.reduce((total, date) => total + daily.get(date), 0)
  const slices = (
    map: Map<string, { amount: number; payments: number }>,
    label: (key: string) => string | null,
  ) =>
    [...map.entries()]
      .sort((a, b) => b[1].amount - a[1].amount)
      .slice(0, 20)
      .map(([key, value]) => ({
        key,
        label: label(key),
        amount: money(value.amount),
        payments: value.payments,
      }))
  const pending = db.withdrawals.filter((payout) => payout.status === 'pending')
  return {
    period: { ...period.response, city: scope.city },
    gross: grossFigure,
    refunds: moneyFigure(refunds, period),
    net: moneyFigure(net, period),
    platform_fees: moneyFigure(fees, period),
    paid_bookings: paidFigure,
    average_fare: {
      value: paidFigure.value ? (Number(grossFigure.value) / paidFigure.value).toFixed(2) : null,
      previous: paidFigure.previous
        ? (Number(grossFigure.previous) / paidFigure.previous).toFixed(2)
        : null,
    },
    failed_payment_rate: {
      value: ratio(sum(failures, period.dates), sum(attempts, period.dates)),
      previous: ratio(sum(failures, period.previous), sum(attempts, period.previous)),
    },
    by_method: [...byMethod.entries()]
      .sort((a, b) => a[0].localeCompare(b[0]))
      .map(([method, daily]) => ({ ...moneyFigure(daily, period), method })),
    by_route: slices(byRoute, (key) => index().routes.get(key)?.name ?? null),
    by_fleet: slices(byFleet, (key) => index().fleets.get(key)?.name ?? null),
    by_hour: byHour.map((value, hour) => ({
      key: String(hour),
      label: `${String(hour).padStart(2, '0')}:00`,
      amount: money(value.amount),
      payments: value.payments,
    })),
    pending_withdrawals: {
      amount: money(pending.reduce((total, payout) => total + payout.amount, 0)),
      count: pending.length,
    },
  }
}

// -------------------------------------------------------------- users
/** Who was active on each day: booked, or drove a trip (the demo's stand-in for signing in). */
function activeByDay(): Map<string, Set<string>> {
  const active = new Map<string, Set<string>>()
  const mark = (day: string, user: string) => {
    const set = active.get(day) ?? new Set<string>()
    set.add(user)
    active.set(day, set)
  }
  for (const booking of getDb().bookings) mark(dayOf(booking.created_at), booking.passenger_id)
  for (const trip of getDb().trips) {
    if (trip.status !== 'completed' || !trip.driver_id) continue
    const driver = index().drivers.get(trip.driver_id)
    if (driver) mark(dayOf(trip.scheduled_departure_at), driver.user_id)
  }
  return active
}

function distinctIn(active: Map<string, Set<string>>, dates: string[]): number {
  const users = new Set<string>()
  for (const date of dates) for (const user of active.get(date) ?? []) users.add(user)
  return users.size
}

const daysBefore = (end: string, count: number) =>
  Array.from({ length: count }, (_, offset) =>
    new Date(Date.parse(`${end}T00:00:00Z`) - offset * DAY).toISOString().slice(0, 10),
  )

function users(period: Period): Schemas['UsersResponse'] {
  const db = getDb()
  const created = new Daily()
  const byRole = new Map<string, Daily>()
  for (const user of db.users) {
    created.add(user.created_at)
    for (const role of user.roles) {
      const daily = byRole.get(role) ?? new Daily()
      daily.add(user.created_at)
      byRole.set(role, daily)
    }
  }
  const active = activeByDay()
  const firstDay = period.dates[0]!
  let running = db.users.filter((user) => dayOf(user.created_at) < firstDay).length
  const cumulative = period.dates.map((date) => {
    running += created.get(date)
    return { date, value: running }
  })
  const daily = period.dates.map((date) => ({ date, value: active.get(date)?.size ?? 0 }))
  const averageOf = (dates: string[]) =>
    dates.length
      ? (
          dates.reduce((total, date) => total + (active.get(date)?.size ?? 0), 0) / dates.length
        ).toFixed(1)
      : null
  const end = period.dates.at(-1)!
  const previousEnd = period.previous.at(-1)!
  // Activation: a paid booking within 7 days of signing up.
  const firstPaid = new Map<string, number>()
  for (const booking of db.bookings) {
    if (!PAID.has(booking.status)) continue
    const at = Date.parse(booking.created_at)
    const known = firstPaid.get(booking.passenger_id)
    if (known === undefined || at < known) firstPaid.set(booking.passenger_id, at)
  }
  const activation = (dates: string[]) => {
    const wanted = new Set(dates)
    const joined = db.users.filter(
      (user) => user.roles.includes('passenger') && wanted.has(dayOf(user.created_at)),
    )
    const activated = joined.filter((user) => {
      const paidAt = firstPaid.get(user.id)
      return paidAt !== undefined && paidAt - Date.parse(user.created_at) <= 7 * DAY
    })
    return { signed_up: joined.length, activated: activated.length }
  }
  const now = activation(period.dates)
  const before = activation(period.previous)
  // Weekly cohorts (by the Monday they joined), retained in the weeks after.
  const mondayOf = (date: string) => {
    const at = Date.parse(`${date}T00:00:00Z`)
    return new Date(at - ((new Date(at).getUTCDay() + 6) % 7) * DAY).toISOString().slice(0, 10)
  }
  const cohorts = new Map<string, string[]>()
  for (const user of db.users) {
    const day = dayOf(user.created_at)
    if (day < firstDay || day > end) continue
    const week = mondayOf(day)
    cohorts.set(week, [...(cohorts.get(week) ?? []), user.id])
  }
  const today = new Date().toISOString().slice(0, 10)
  const cohortRows = [...cohorts.entries()]
    .sort((a, b) => a[0].localeCompare(b[0]))
    .map(([week, members]) => {
      const retained: number[] = []
      for (let offset = 1; offset <= 8; offset += 1) {
        const start = Date.parse(`${week}T00:00:00Z`) + offset * 7 * DAY
        if (new Date(start).toISOString().slice(0, 10) > today) break
        const dates = Array.from({ length: 7 }, (_, step) =>
          new Date(start + step * DAY).toISOString().slice(0, 10),
        )
        const seen = new Set<string>()
        for (const date of dates) for (const user of active.get(date) ?? []) seen.add(user)
        retained.push(members.filter((member) => seen.has(member)).length)
      }
      return {
        week,
        size: members.length,
        retained,
        retention_rates: retained.map((count) =>
          members.length ? (count / members.length).toFixed(4) : '0',
        ),
      }
    })
  const travellers = new Map<string, Set<string>>()
  for (const booking of db.bookings) {
    if (!PAID.has(booking.status) || !period.dates.includes(dayOf(booking.created_at))) continue
    const city = tripCity(booking.trip_id) ?? 'Unknown'
    const set = travellers.get(city) ?? new Set<string>()
    set.add(booking.passenger_id)
    travellers.set(city, set)
  }
  return {
    period: period.response,
    new_users: countFigure(created, period),
    signups_by_role: [...byRole.entries()]
      .sort((a, b) => a[0].localeCompare(b[0]))
      .map(([role, figure]) => ({ ...countFigure(figure, period), role })),
    cumulative_users: cumulative,
    daily_active: daily,
    average_daily_active: { value: averageOf(period.dates), previous: averageOf(period.previous) },
    weekly_active: {
      value: String(distinctIn(active, daysBefore(end, 7))),
      previous: String(distinctIn(active, daysBefore(previousEnd, 7))),
    },
    monthly_active: {
      value: String(distinctIn(active, daysBefore(end, 30))),
      previous: String(distinctIn(active, daysBefore(previousEnd, 30))),
    },
    activation: {
      signed_up: now.signed_up,
      activated: now.activated,
      rate: ratio(now.activated, now.signed_up),
      previous_signed_up: before.signed_up,
      previous_activated: before.activated,
      previous_rate: ratio(before.activated, before.signed_up),
    },
    cohorts: cohortRows,
    travellers_by_city: [...travellers.entries()]
      .map(([city, set]) => ({ city, users: set.size }))
      .sort((a, b) => b.users - a.users),
  }
}

// ------------------------------------------------------------- funnel
function funnel(period: Period, city: string | null): Schemas['FunnelResponse'] {
  const reserved = new Daily()
  const paid = new Daily()
  const boarded = new Daily()
  for (const booking of getDb().bookings) {
    if (city && tripCity(booking.trip_id) !== city) continue
    reserved.add(booking.created_at)
    if (['confirmed', 'completed', 'refund_pending', 'refunded'].includes(booking.status))
      paid.add(booking.created_at)
    if (booking.passengers.some((passenger) => passenger.boarded_at))
      boarded.add(booking.created_at)
  }
  const searches = new Daily()
  for (const date of [...period.previous, ...period.dates]) {
    searches.add(`${date}T12:00:00Z`, searchesFor(reserved.get(date), `${date}:${city ?? ''}`))
  }
  const figures = { searches, reserved, paid, boarded }
  const stages = (Object.keys(figures) as (keyof typeof figures)[]).map((stage, position, all) => {
    const figure = countFigure(figures[stage], period)
    const before = position ? countFigure(figures[all[position - 1]!], period) : null
    return {
      stage,
      value: figure.value,
      previous: figure.previous,
      change_percent: figure.change_percent,
      conversion: before ? ratio(figure.value, before.value) : null,
      previous_conversion: before ? ratio(figure.previous, before.previous) : null,
    }
  })
  return { period: { ...period.response, city }, stages }
}

// ------------------------------------------------------------- demand
const CELL = 0.005 // about 550 m

function demand(url: URL, period: Period): Schemas['DemandResponse'] | Response {
  const type = (url.searchParams.get('type') ?? 'searches') as 'searches' | 'unmet' | 'bookings'
  const city = url.searchParams.get('city')
  const dayFilter = url.searchParams.get('days')
  const days = dayFilter ? dayFilter.split(',').filter(Boolean) : null
  if (days && days.some((day) => !(DAY_NAMES as readonly string[]).includes(day))) {
    return errorResponse(422, 'VALIDATION_ERROR', 'Days are mon, tue, wed, thu, fri, sat or sun.', {
      param: 'days',
    })
  }
  const hourFrom = url.searchParams.get('hour_from')
  const hourTo = url.searchParams.get('hour_to')
  const from = hourFrom === null ? null : Number(hourFrom)
  const to = hourTo === null ? null : Number(hourTo)
  const hourOk = (hour: number) =>
    from === null || to === null
      ? true
      : from <= to
        ? hour >= from && hour <= to
        : hour >= from || hour <= to
  const dayName = (iso: string) => DAY_NAMES[(new Date(iso).getUTCDay() + 6) % 7]!
  const { trips, routes, stops } = index()
  const grid = DAY_NAMES.map(() => Array.from({ length: 24 }, () => 0))
  const byStop = new Map<string, number>()
  const byPair = new Map<string, number>()
  const unmetByStop = new Map<string, { searches: number; unmet: number }>()
  let total = 0
  let previousTotal = 0
  const current = new Set(period.dates)
  const before = new Set(period.previous)
  for (const booking of getDb().bookings) {
    const day = dayOf(booking.created_at)
    const inCurrent = current.has(day)
    if (!inCurrent && !before.has(day)) continue
    const trip = trips.get(booking.trip_id)!
    if (city && tripCity(trip.id) !== city) continue
    const hour = new Date(booking.created_at).getUTCHours()
    const name = dayName(booking.created_at)
    if ((days && !days.includes(name)) || !hourOk(hour)) continue
    const route = routes.get(trip.route_id)!
    const origin = route.stop_ids[booking.origin_index]!
    const destination = route.stop_ids[booking.destination_index]!
    // Searches and unmet ones are derived per booking (the demo keeps no searches).
    const searched = searchesFor(1, booking.id)
    const unmetShare = 0.08 + 0.3 * noise(origin)
    const unmet = Math.round(searched * unmetShare * (hour >= 6 && hour <= 9 ? 1.6 : 1))
    const weight =
      type === 'bookings' ? booking.passenger_count : type === 'searches' ? searched : unmet
    if (!inCurrent) {
      previousTotal += weight
      continue
    }
    total += weight
    grid[DAY_NAMES.indexOf(name)]![hour]! += weight
    byStop.set(origin, (byStop.get(origin) ?? 0) + weight)
    byPair.set(`${origin}|${destination}`, (byPair.get(`${origin}|${destination}`) ?? 0) + weight)
    const gap = unmetByStop.get(origin) ?? { searches: 0, unmet: 0 }
    gap.searches += searched
    gap.unmet += unmet
    unmetByStop.set(origin, gap)
  }
  // Cells around each stop: most at the stop, some spilling to its neighbours.
  const cells = new Map<string, { latitude: number; longitude: number; weight: number }>()
  for (const [stopId, weight] of byStop) {
    const stop = stops.get(stopId)!
    const spread: [number, number, number][] = [
      [0, 0, 0.6],
      [1, 0, 0.1],
      [-1, 0, 0.1],
      [0, 1, 0.1],
      [0, -1, 0.1],
    ]
    for (const [dx, dy, part] of spread) {
      const latitude = Math.round(stop.latitude / CELL + dy) * CELL
      const longitude = Math.round(stop.longitude / CELL + dx) * CELL
      const key = `${latitude.toFixed(4)},${longitude.toFixed(4)}`
      const cell = cells.get(key) ?? { latitude, longitude, weight: 0 }
      cell.weight += Math.round(weight * part)
      cells.set(key, cell)
    }
  }
  // Like the backend, small cells are withheld so no one is singled out.
  const shown = [...cells.values()].filter((cell) => cell.weight >= 3)
  const withheld = [...cells.values()]
    .filter((cell) => cell.weight < 3)
    .reduce((sum, cell) => sum + cell.weight, 0)
  return {
    period: { ...period.response, city },
    type,
    days: (days as Schemas['DemandResponse']['days']) ?? null,
    hour_from: from,
    hour_to: to,
    total,
    previous_total: previousTotal,
    change_percent: change(total, previousTotal),
    cell_degrees: CELL.toFixed(3),
    cells: shown
      .sort((a, b) => b.weight - a.weight)
      .map((cell) => ({
        latitude: cell.latitude.toFixed(4),
        longitude: cell.longitude.toFixed(4),
        weight: cell.weight,
      })),
    withheld: type === 'bookings' ? 0 : withheld,
    top_origins: [...byStop.entries()]
      .sort((a, b) => b[1] - a[1])
      .slice(0, 10)
      .map(([stopId, weight]) => {
        const stop = stops.get(stopId)!
        return { stop_id: stopId, name: stop.name, city: stop.city, weight }
      }),
    top_pairs: [...byPair.entries()]
      .sort((a, b) => b[1] - a[1])
      .slice(0, 10)
      .map(([key, weight]) => {
        const [origin, destination] = key.split('|') as [string, string]
        return {
          origin_stop_id: origin,
          origin_name: stops.get(origin)!.name,
          destination_stop_id: destination,
          destination_name: stops.get(destination)!.name,
          weight,
        }
      }),
    by_day_and_hour: DAY_NAMES.map((day, position) => ({ day, hours: grid[position]! })),
    supply_gaps: [...unmetByStop.entries()]
      .filter(([, gap]) => gap.searches >= 20)
      .sort((a, b) => b[1].unmet / b[1].searches - a[1].unmet / a[1].searches)
      .slice(0, 10)
      .map(([stopId, gap]) => {
        const stop = stops.get(stopId)!
        return {
          stop_id: stopId,
          name: stop.name,
          city: stop.city,
          searches: gap.searches,
          unmet: gap.unmet,
          unmet_share: (gap.unmet / gap.searches).toFixed(4),
        }
      }),
  }
}

// ------------------------------------------------------------- reports
type Granularity = 'day' | 'week' | 'month'
type Row = Record<string, string | number | null>

function bucketOf(date: string, granularity: Granularity): string {
  if (granularity === 'day') return date
  if (granularity === 'month') return `${date.slice(0, 8)}01`
  const at = Date.parse(`${date}T00:00:00Z`)
  return new Date(at - ((new Date(at).getUTCDay() + 6) % 7) * DAY).toISOString().slice(0, 10)
}

function bucketsOf(period: Period, granularity: Granularity): string[] {
  return [...new Set(period.dates.map((date) => bucketOf(date, granularity)))]
}

function tally(rows: Map<string, Row>, bucket: string, key: string, amount = 1) {
  const row = rows.get(bucket)
  if (row) row[key] = Number(row[key] ?? 0) + amount
}

const COLUMNS: Record<
  string,
  {
    title: string
    columns: [string, string, Schemas['ReportColumnResponse']['kind']][]
    note: string
  }
> = {
  daily_rides: {
    title: 'Daily rides',
    columns: [
      ['period', 'Period', 'period'],
      ['trips_completed', 'Trips completed', 'count'],
      ['trips_cancelled', 'Trips cancelled', 'count'],
      ['seats_offered', 'Seats offered', 'count'],
      ['seats_booked', 'Seats booked', 'count'],
      ['occupancy', 'Occupancy', 'ratio'],
      ['passengers_boarded', 'Passengers boarded', 'count'],
    ],
    note: 'Trips by their scheduled departure; seats on completed trips.',
  },
  revenue: {
    title: 'Revenue',
    columns: [
      ['period', 'Period', 'period'],
      ['paid_bookings', 'Paid bookings', 'count'],
      ['gross', 'Gross (GHS)', 'money'],
      ['refunds', 'Refunds (GHS)', 'money'],
      ['net', 'Net (GHS)', 'money'],
      ['platform_fees', 'Platform fees (GHS)', 'money'],
      ['average_fare', 'Average fare (GHS)', 'money'],
    ],
    note: 'Payments by when they were collected; refunds by when they were paid out.',
  },
  passenger_growth: {
    title: 'Passenger growth',
    columns: [
      ['period', 'Period', 'period'],
      ['new_passengers', 'New passengers', 'count'],
      ['total_passengers', 'Total passengers', 'count'],
      ['active_passengers', 'Active passengers', 'count'],
      ['first_time_bookers', 'First-time bookers', 'count'],
    ],
    note: 'Active: booked at least once in the period.',
  },
  cancellation_rates: {
    title: 'Cancellation rates',
    columns: [
      ['period', 'Period', 'period'],
      ['bookings_made', 'Bookings made', 'count'],
      ['cancelled_by_passengers', 'Cancelled by passengers', 'count'],
      ['cancelled_with_trip', 'Cancelled with their trip', 'count'],
      ['expired_unpaid', 'Expired unpaid', 'count'],
      ['passenger_cancellation_rate', 'Passenger cancellation rate', 'ratio'],
      ['trips_scheduled', 'Trips scheduled', 'count'],
      ['trips_cancelled', 'Trips cancelled', 'count'],
      ['trip_cancellation_rate', 'Trip cancellation rate', 'ratio'],
    ],
    note: 'Bookings by when they were made; trips by their scheduled departure.',
  },
  peak_hours: {
    title: 'Peak hours',
    columns: [
      ['hour', 'Hour', 'hour'],
      ['trips', 'Trips departing', 'count'],
      ['seats_booked', 'Seats booked', 'count'],
      ['passengers_boarded', 'Passengers boarded', 'count'],
      ['bookings_made', 'Bookings made', 'count'],
      ['searches', 'Searches', 'count'],
    ],
    note: 'By hour of the day, Ghana time.',
  },
  route_popularity: {
    title: 'Route popularity',
    columns: [
      ['route_id', 'Route ID', 'text'],
      ['route_name', 'Route', 'text'],
      ['origin', 'From', 'text'],
      ['destination', 'To', 'text'],
      ['trips_completed', 'Trips completed', 'count'],
      ['trips_cancelled', 'Trips cancelled', 'count'],
      ['seats_offered', 'Seats offered', 'count'],
      ['seats_booked', 'Seats booked', 'count'],
      ['occupancy', 'Occupancy', 'ratio'],
      ['passengers_boarded', 'Passengers boarded', 'count'],
      ['fares', 'Fares (GHS)', 'money'],
      ['bookings_cancelled', 'Bookings cancelled', 'count'],
    ],
    note: 'Trips departing in the period, busiest route first.',
  },
}

function report(
  name: string,
  period: Period,
  granularity: Granularity,
  scope: Scope,
): Schemas['ReportResponse'] {
  const definition = COLUMNS[name]!
  const keys = definition.columns.map(([key]) => key)
  const db = getDb()
  const blank = (first: [string, string | number]) =>
    Object.fromEntries([first, ...keys.slice(1).map((key) => [key, 0])]) as Row
  const current = new Set(period.dates)
  const notes = [definition.note]
  let rows: Row[]

  if (name === 'peak_hours' || name === 'route_popularity') {
    const map = new Map<string, Row>()
    if (name === 'peak_hours') {
      for (let hour = 0; hour < 24; hour += 1) map.set(String(hour), blank(['hour', hour]))
    }
    for (const trip of db.trips) {
      if (!current.has(dayOf(trip.scheduled_departure_at)) || !inScope(trip, scope)) continue
      const route = index().routes.get(trip.route_id)!
      const key =
        name === 'peak_hours'
          ? String(new Date(trip.scheduled_departure_at).getUTCHours())
          : trip.route_id
      if (!map.has(key)) {
        const stops = routeStops(route)
        map.set(key, {
          ...blank(['route_id', route.id]),
          route_name: route.name,
          origin: stops[0]!.name,
          destination: stops.at(-1)!.name,
        })
      }
      const capacity = trip.vehicle_id
        ? (index().vehicles.get(trip.vehicle_id)?.capacity ?? route.seats)
        : route.seats
      if (name === 'peak_hours') tally(map, key, 'trips')
      if (trip.status === 'completed') {
        tally(map, key, 'trips_completed')
        tally(map, key, 'seats_offered', capacity)
      }
      if (trip.status === 'cancelled') tally(map, key, 'trips_cancelled')
      for (const booking of index().bookingsByTrip.get(trip.id) ?? []) {
        if (PAID.has(booking.status)) {
          tally(map, key, 'seats_booked', booking.passenger_count)
          tally(map, key, 'fares', booking.fare_amount)
        }
        if (booking.status === 'cancelled' || booking.status === 'refunded')
          tally(map, key, 'bookings_cancelled')
        tally(map, key, 'passengers_boarded', booking.passengers.filter((p) => p.boarded_at).length)
      }
    }
    if (name === 'peak_hours') {
      for (const booking of db.bookings) {
        if (!current.has(dayOf(booking.created_at)) || !inScope(tripOf(booking), scope)) continue
        const hour = String(new Date(booking.created_at).getUTCHours())
        tally(map, hour, 'bookings_made')
        tally(map, hour, 'searches', searchesFor(1, booking.id))
      }
      if (scope.route || scope.fleet) {
        for (const row of map.values()) row.searches = null
        notes.push('Searches have no route or fleet, so they are left out here.')
      }
    }
    rows = [...map.values()]
    if (name === 'route_popularity') {
      for (const row of rows) {
        row.occupancy = ratio(Number(row.seats_booked), Number(row.seats_offered))
        row.fares = money(Number(row.fares))
        delete row.trips
        delete row.bookings_made
        delete row.searches
        delete row.hour
      }
      rows.sort((a, b) => Number(b.trips_completed) - Number(a.trips_completed))
    } else {
      for (const row of rows) {
        for (const key of Object.keys(row)) if (!keys.includes(key)) delete row[key]
      }
    }
  } else {
    const map = new Map<string, Row>()
    for (const bucket of bucketsOf(period, granularity)) map.set(bucket, blank(['period', bucket]))
    const at = (iso: string) => (current.has(dayOf(iso)) ? bucketOf(dayOf(iso), granularity) : null)
    if (name === 'daily_rides') {
      for (const trip of db.trips) {
        const bucket = at(trip.scheduled_departure_at)
        if (!bucket || !inScope(trip, scope)) continue
        if (trip.status === 'cancelled') tally(map, bucket, 'trips_cancelled')
        if (trip.status !== 'completed') continue
        const route = index().routes.get(trip.route_id)!
        tally(map, bucket, 'trips_completed')
        tally(
          map,
          bucket,
          'seats_offered',
          trip.vehicle_id
            ? (index().vehicles.get(trip.vehicle_id)?.capacity ?? route.seats)
            : route.seats,
        )
        for (const booking of index().bookingsByTrip.get(trip.id) ?? []) {
          if (PAID.has(booking.status)) tally(map, bucket, 'seats_booked', booking.passenger_count)
          tally(
            map,
            bucket,
            'passengers_boarded',
            booking.passengers.filter((p) => p.boarded_at).length,
          )
        }
      }
      for (const row of map.values())
        row.occupancy = ratio(Number(row.seats_booked), Number(row.seats_offered))
    } else if (name === 'revenue') {
      for (const payment of db.payments) {
        if (payment.purpose !== 'booking_payment' || !COLLECTED.has(payment.status)) continue
        const bucket = at(payment.completed_at ?? payment.created_at)
        const booking = bookingOf(payment)
        if (!bucket || !inScope(tripOf(booking), scope)) continue
        tally(map, bucket, 'paid_bookings')
        tally(map, bucket, 'gross', payment.amount)
        tally(map, bucket, 'platform_fees', booking?.platform_fee ?? 0)
      }
      for (const refund of db.refunds) {
        if (refund.status !== 'completed' || !refund.reviewed_at) continue
        const bucket = at(refund.reviewed_at)
        const booking = refund.booking_id ? index().bookings.get(refund.booking_id) : undefined
        if (bucket && inScope(tripOf(booking), scope)) tally(map, bucket, 'refunds', refund.amount)
      }
      for (const row of map.values()) {
        const gross = Number(row.gross)
        const refunds = Number(row.refunds)
        row.net = money(gross - refunds)
        row.average_fare = Number(row.paid_bookings)
          ? money(gross / Number(row.paid_bookings))
          : null
        row.gross = money(gross)
        row.refunds = money(refunds)
        row.platform_fees = money(Number(row.platform_fees))
      }
    } else if (name === 'passenger_growth') {
      const passengers = db.users.filter((user) => user.roles.includes('passenger'))
      const firstBooking = new Map<string, string>()
      for (const booking of [...db.bookings].sort((a, b) =>
        a.created_at.localeCompare(b.created_at),
      )) {
        if (!firstBooking.has(booking.passenger_id))
          firstBooking.set(booking.passenger_id, booking.created_at)
      }
      const active = new Map<string, Set<string>>()
      for (const booking of db.bookings) {
        const bucket = at(booking.created_at)
        if (!bucket || !inScope(tripOf(booking), scope)) continue
        active.set(bucket, (active.get(bucket) ?? new Set()).add(booking.passenger_id))
        if (firstBooking.get(booking.passenger_id) === booking.created_at)
          tally(map, bucket, 'first_time_bookers')
      }
      for (const user of passengers) {
        const bucket = at(user.created_at)
        if (bucket) tally(map, bucket, 'new_passengers')
      }
      for (const [bucket, row] of map) {
        row.active_passengers = active.get(bucket)?.size ?? 0
        const end = Math.max(
          ...period.dates
            .filter((date) => bucketOf(date, granularity) === bucket)
            .map((date) => Date.parse(`${date}T23:59:59Z`)),
        )
        row.total_passengers = passengers.filter(
          (user) => Date.parse(user.created_at) <= end,
        ).length
      }
      if (scope.city || scope.route || scope.fleet) {
        for (const row of map.values()) {
          row.new_passengers = null
          row.total_passengers = null
        }
        notes.push('Sign-ups have no city, route or fleet, so they are left out here.')
      }
    } else {
      for (const booking of db.bookings) {
        const bucket = at(booking.created_at)
        if (!bucket || !inScope(tripOf(booking), scope)) continue
        tally(map, bucket, 'bookings_made')
        if (booking.status === 'expired') tally(map, bucket, 'expired_unpaid')
        if (
          booking.status === 'cancelled' ||
          booking.status === 'refunded' ||
          booking.status === 'refund_pending'
        ) {
          const trip = tripOf(booking)
          tally(
            map,
            bucket,
            trip?.status === 'cancelled' ? 'cancelled_with_trip' : 'cancelled_by_passengers',
          )
        }
      }
      for (const trip of db.trips) {
        const bucket = at(trip.scheduled_departure_at)
        if (!bucket || !inScope(trip, scope)) continue
        tally(map, bucket, 'trips_scheduled')
        if (trip.status === 'cancelled') tally(map, bucket, 'trips_cancelled')
      }
      for (const row of map.values()) {
        row.passenger_cancellation_rate = ratio(
          Number(row.cancelled_by_passengers),
          Number(row.bookings_made),
        )
        row.trip_cancellation_rate = ratio(Number(row.trips_cancelled), Number(row.trips_scheduled))
      }
    }
    rows = [...map.values()]
  }

  // Totals: sums of the counts and money; ratios worked out again.
  const totals: Row = {}
  for (const [key, , kind] of definition.columns) {
    if (kind === 'count' || kind === 'money') {
      const present = rows
        .map((row) => row[key])
        .filter((value) => value !== null && value !== undefined)
      const sum = present.reduce<number>((total, value) => total + Number(value), 0)
      totals[key] = present.length || !rows.length ? (kind === 'money' ? money(sum) : sum) : null
    }
  }
  if ('occupancy' in totals || keys.includes('occupancy'))
    totals.occupancy = ratio(Number(totals.seats_booked), Number(totals.seats_offered))
  if (keys.includes('average_fare'))
    totals.average_fare = Number(totals.paid_bookings)
      ? money(Number(totals.gross) / Number(totals.paid_bookings))
      : null
  if (keys.includes('passenger_cancellation_rate')) {
    totals.passenger_cancellation_rate = ratio(
      Number(totals.cancelled_by_passengers),
      Number(totals.bookings_made),
    )
    totals.trip_cancellation_rate = ratio(
      Number(totals.trips_cancelled),
      Number(totals.trips_scheduled),
    )
  }
  if (keys.includes('total_passengers'))
    totals.total_passengers = rows.at(-1)?.total_passengers ?? null

  return {
    report: name as Schemas['ReportResponse']['report'],
    title: definition.title,
    period: { ...period.response, city: scope.city },
    granularity: name === 'peak_hours' || name === 'route_popularity' ? null : granularity,
    route_id: scope.route,
    fleet_id: scope.fleet,
    columns: definition.columns.map(([key, label, kind]) => ({ key, label, kind })),
    rows: rows as Schemas['ReportResponse']['rows'],
    totals,
    notes,
  }
}

export const analyticsHandlers = [
  endpoint.get(
    '/admin/analytics/revenue',
    ['payments:review', 'refunds:approve', 'reports:view'],
    ({ url }) => {
      const period = resolvePeriod(url)
      if (period instanceof Response) return period
      return revenue(period, { city: url.searchParams.get('city'), route: null, fleet: null })
    },
  ),

  endpoint.get('/admin/analytics/users', ['reports:view'], ({ url }) => {
    const period = resolvePeriod(url)
    return period instanceof Response ? period : users(period)
  }),

  endpoint.get('/admin/analytics/funnel', ['reports:view'], ({ url }) => {
    const period = resolvePeriod(url)
    return period instanceof Response ? period : funnel(period, url.searchParams.get('city'))
  }),

  endpoint.get('/admin/analytics/demand', ['reports:view'], ({ url }) => {
    const period = resolvePeriod(url)
    return period instanceof Response ? period : demand(url, period)
  }),

  // Registered after the overview handler's "/admin/reports/overview".
  endpoint.get('/admin/reports/:report', ['reports:view'], ({ params, url }) => {
    const name = params.report!
    if (!(name in COLUMNS)) {
      return errorResponse(422, 'VALIDATION_ERROR', 'The submitted data is invalid.', {
        errors: [
          {
            loc: ['path', 'report'],
            msg: `Input should be ${Object.keys(COLUMNS)
              .map((key) => `'${key}'`)
              .join(', ')}`,
            type: 'enum',
          },
        ],
      })
    }
    const period = resolvePeriod(url)
    if (period instanceof Response) return period
    const granularity = (url.searchParams.get('granularity') ?? 'day') as Granularity
    const result = report(name, period, granularity, {
      city: url.searchParams.get('city'),
      route: url.searchParams.get('route'),
      fleet: url.searchParams.get('fleet'),
    })
    if (url.searchParams.get('format') === 'csv') {
      return csvAnswer(result.rows as Record<string, unknown>[], name.replace(/_/g, '-'))
    }
    return result
  }),
]
