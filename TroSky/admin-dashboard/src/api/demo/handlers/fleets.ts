import type { Schemas } from '@/api/types'

import { DAY, getDb, index } from '../db'
import { walletFor } from '../db/extras'
import type { DriverRec } from '../db/model'
import { csvAnswer, endpoint, errorResponse, notFound, paginate } from '../http'
import { money } from '../views'
import { activity, adminDriver, adminVehicle } from './fleet'
import { resolvePeriod, tripCity, type Period } from './overview'

// ------------------------------------------------------------------ fleets
function fleetRow(fleetId: string, seen = activity()): Schemas['AdminFleetResponse'] {
  const db = getDb()
  const fleet = index().fleets.get(fleetId)!
  const owner = index().owners.get(fleet.owner_id)!
  const ownerUser = index().users.get(owner.user_id)
  const vehicles = db.vehicles.filter((vehicle) => vehicle.fleet_id === fleet.id)
  const approved = vehicles.filter((vehicle) => vehicle.status === 'approved')
  const vehicleIds = new Set(vehicles.map((vehicle) => vehicle.id))
  const now = Date.now()
  const recent = db.trips.filter(
    (trip) =>
      trip.vehicle_id &&
      vehicleIds.has(trip.vehicle_id) &&
      Date.parse(trip.scheduled_departure_at) > now - 30 * DAY &&
      Date.parse(trip.scheduled_departure_at) <= now,
  )
  const usedThisWeek = new Set(
    recent
      .filter(
        (trip) =>
          trip.status === 'completed' && Date.parse(trip.scheduled_departure_at) > now - 7 * DAY,
      )
      .map((trip) => trip.vehicle_id),
  )
  let revenue = 0
  const ratings: number[] = []
  for (const trip of recent) {
    for (const booking of index().bookingsByTrip.get(trip.id) ?? []) {
      if (booking.status === 'completed') revenue += booking.fare_amount
    }
  }
  for (const driver of db.drivers.filter((candidate) => candidate.fleet_id === fleet.id)) {
    for (const rating of index().ratingsByDriver.get(driver.id) ?? []) ratings.push(rating.overall)
  }
  return {
    id: fleet.id,
    name: fleet.name,
    is_active: owner.status === 'approved',
    owner: {
      id: owner.id,
      business_name: owner.business_name,
      status: owner.status,
      name: ownerUser?.full_name ?? null,
      phone_number: ownerUser?.phone_number ?? '',
    },
    vehicle_count: vehicles.length,
    approved_vehicles: approved.length,
    active_now: vehicles.filter((vehicle) => seen.current.has(vehicle.id)).length,
    driver_count: db.drivers.filter((driver) => driver.fleet_id === fleet.id).length,
    utilization_7d: approved.length ? (usedThisWeek.size / approved.length).toFixed(4) : null,
    revenue_30d: money(revenue),
    average_rating: ratings.length
      ? (ratings.reduce((sum, score) => sum + score, 0) / ratings.length).toFixed(2)
      : null,
    created_at: fleet.created_at,
  }
}

const FLEET_SORTS = [
  'fleet_name',
  'business_name',
  'created_at',
  'vehicle_count',
  'active_now',
  'revenue_30d',
  'average_rating',
]

function badSort(field: string, allowed: string[]) {
  return errorResponse(422, 'VALIDATION_ERROR', `Cannot sort by '${field}'.`, {
    param: 'sort',
    allowed: [...allowed].sort(),
  })
}

// ------------------------------------------------------ driver performance
const SCORE_WEIGHTS = {
  rating: 0.35,
  on_time: 0.25,
  reliability: 0.15,
  complaints: 0.15,
  qr_scanning: 0.1,
}
const AT_RISK: Record<string, string> = {
  low_rating: 'Average rating below 3.5 (5+ ratings).',
  late_starts: 'Fewer than 70% of trips started on time (5+ trips).',
  cancellations: 'More than 10% of finished trips were cancelled (5+ trips).',
  complaints: 'More than 5 complaints per 100 trips (5+ trips).',
  qr_not_scanned: 'Fewer than 80% of tickets scanned at boarding (10+ tickets).',
}
const ON_TIME_MS = 5 * 60_000

interface Counts {
  assigned: number
  completed: number
  cancelled: number
  onTime: number
  ratings: number
  ratingTotal: number
  complaints: number
  issued: number
  scanned: number
}

/** One driver's counts over the days of a period (Ghana dates). */
function countsFor(driver: DriverRec, days: Set<string>): Counts {
  const counts: Counts = {
    assigned: 0,
    completed: 0,
    cancelled: 0,
    onTime: 0,
    ratings: 0,
    ratingTotal: 0,
    complaints: 0,
    issued: 0,
    scanned: 0,
  }
  const tripIds = new Set<string>()
  for (const trip of getDb().trips) {
    if (trip.driver_id !== driver.id || !days.has(trip.scheduled_departure_at.slice(0, 10)))
      continue
    tripIds.add(trip.id)
    counts.assigned += 1
    if (trip.status === 'cancelled') counts.cancelled += 1
    if (trip.status !== 'completed') continue
    counts.completed += 1
    if (
      trip.actual_departure_at &&
      Date.parse(trip.actual_departure_at) - Date.parse(trip.scheduled_departure_at) <= ON_TIME_MS
    ) {
      counts.onTime += 1
    }
    for (const booking of index().bookingsByTrip.get(trip.id) ?? []) {
      if (!['confirmed', 'completed'].includes(booking.status)) continue
      for (const passenger of booking.passengers) {
        counts.issued += 1
        if (passenger.boarded_at) counts.scanned += 1
      }
    }
  }
  for (const rating of index().ratingsByDriver.get(driver.id) ?? []) {
    if (!days.has(rating.created_at.slice(0, 10))) continue
    counts.ratings += 1
    counts.ratingTotal += rating.overall
  }
  for (const complaint of getDb().complaints) {
    if (complaint.trip_id && tripIds.has(complaint.trip_id)) counts.complaints += 1
  }
  return counts
}

const share = (part: number, whole: number) => (whole ? part / whole : null)
const fixed = (value: number | null, places: number) =>
  value === null ? null : value.toFixed(places)

/** The backend's score: weighted parts, missing ones left out; at-risk reasons. */
function score(counts: Counts) {
  const average = counts.ratings
    ? Math.round((counts.ratingTotal / counts.ratings) * 100) / 100
    : null
  const onTime = share(counts.onTime, counts.completed)
  const resolved = counts.completed + counts.cancelled
  const cancellation = share(counts.cancelled, resolved)
  const per100 = counts.completed
    ? Math.round((counts.complaints * 10000) / counts.completed) / 100
    : null
  const scanning = share(counts.scanned, counts.issued)
  const parts: Record<keyof typeof SCORE_WEIGHTS, number | null> = {
    rating: average === null ? null : (average - 1) / 4,
    on_time: onTime,
    reliability: cancellation === null ? null : 1 - cancellation,
    complaints: per100 === null ? null : Math.max(0, 1 - per100 / 10),
    qr_scanning: scanning,
  }
  const present = (Object.keys(parts) as (keyof typeof SCORE_WEIGHTS)[]).filter(
    (key) => parts[key] !== null,
  )
  const weight = present.reduce((sum, key) => sum + SCORE_WEIGHTS[key], 0)
  const total = present.reduce((sum, key) => sum + SCORE_WEIGHTS[key] * parts[key]!, 0)
  const reasons: string[] = []
  if (counts.ratings >= 5 && average !== null && average < 3.5) reasons.push('low_rating')
  if (counts.completed >= 5 && onTime !== null && onTime < 0.7) reasons.push('late_starts')
  if (resolved >= 5 && cancellation !== null && cancellation > 0.1) reasons.push('cancellations')
  if (counts.completed >= 5 && per100 !== null && per100 > 5) reasons.push('complaints')
  if (counts.issued >= 10 && scanning !== null && scanning < 0.8) reasons.push('qr_not_scanned')
  return {
    average_rating: fixed(average, 2),
    on_time_rate: fixed(onTime, 4),
    cancellation_rate: fixed(cancellation, 4),
    complaints_per_100_trips: fixed(per100, 2),
    qr_scan_rate: fixed(scanning, 4),
    score: present.length ? ((total / weight) * 100).toFixed(1) : null,
    score_breakdown: {
      rating: fixed(parts.rating === null ? null : parts.rating * 100, 1),
      on_time: fixed(parts.on_time === null ? null : parts.on_time * 100, 1),
      reliability: fixed(parts.reliability === null ? null : parts.reliability * 100, 1),
      complaints: fixed(parts.complaints === null ? null : parts.complaints * 100, 1),
      qr_scanning: fixed(parts.qr_scanning === null ? null : parts.qr_scanning * 100, 1),
    },
    at_risk: reasons.length > 0,
    at_risk_reasons: reasons.map((code) => ({ code, message: AT_RISK[code]! })),
  }
}

function performance(driver: DriverRec, period: Period): Schemas['DriverPerformanceResponse'] {
  const counts = countsFor(driver, new Set(period.dates))
  return {
    driver_id: driver.id,
    full_name: index().users.get(driver.user_id)?.full_name ?? null,
    trips_assigned: counts.assigned,
    trips_completed: counts.completed,
    trips_cancelled: counts.cancelled,
    rating_count: counts.ratings,
    complaints: counts.complaints,
    tickets_issued: counts.issued,
    tickets_scanned: counts.scanned,
    ...score(counts),
  }
}

const PERFORMANCE_SORTS = [
  'score',
  'average_rating',
  'trips_completed',
  'on_time_rate',
  'cancellation_rate',
  'complaints_per_100_trips',
]

export const fleetsHandlers = [
  endpoint.get('/admin/fleets', ['vehicles:approve', 'reports:view'], ({ url }) => {
    const ownerStatus = url.searchParams.get('owner_status')
    const q = (url.searchParams.get('q') ?? '').trim().toLowerCase()
    const sort = url.searchParams.get('sort') ?? 'fleet_name'
    const field = sort.replace(/^-/, '')
    if (!FLEET_SORTS.includes(field)) return badSort(field, FLEET_SORTS)
    const seen = activity()
    const rows = getDb()
      .fleets.map((fleet) => fleetRow(fleet.id, seen))
      .filter(
        (row) =>
          (!ownerStatus || row.owner.status === ownerStatus) &&
          (!q ||
            row.name.toLowerCase().includes(q) ||
            row.owner.business_name.toLowerCase().includes(q)),
      )
    const value = (row: Schemas['AdminFleetResponse']): string | number =>
      field === 'fleet_name'
        ? row.name
        : field === 'business_name'
          ? row.owner.business_name
          : field === 'revenue_30d' || field === 'average_rating'
            ? Number(row[field] ?? -1)
            : (row[field as 'created_at' | 'vehicle_count' | 'active_now'] as string | number)
    rows.sort((a, b) => {
      const [x, y] = [value(a), value(b)]
      return typeof x === 'number' && typeof y === 'number'
        ? x - y
        : String(x).localeCompare(String(y))
    })
    if (sort.startsWith('-')) rows.reverse()
    if (url.searchParams.get('format') === 'csv') return csvAnswer(rows, 'fleets')
    return paginate(rows, url)
  }),

  endpoint.get('/admin/fleets/:fleetId', ['vehicles:approve', 'reports:view'], ({ params }) => {
    const fleet = index().fleets.get(params.fleetId!)
    if (!fleet) return notFound('Fleet not found.')
    const seen = activity()
    const db = getDb()
    return {
      ...fleetRow(fleet.id, seen),
      vehicles: db.vehicles
        .filter((vehicle) => vehicle.fleet_id === fleet.id)
        .map((vehicle) => adminVehicle(vehicle, seen)),
      drivers: db.drivers
        .filter((driver) => driver.fleet_id === fleet.id)
        .map((driver) => adminDriver(driver, seen)),
    } satisfies Schemas['AdminFleetDetailResponse']
  }),

  // "performance" before the fleet handlers' "/admin/drivers/:driverId".
  endpoint.get('/admin/drivers/performance', ['reports:view', 'drivers:approve'], ({ url }) => {
    const period = resolvePeriod(url)
    if (period instanceof Response) return period
    const sort = url.searchParams.get('sort') ?? 'score'
    const field = sort.replace(/^[-+]/, '') as keyof Schemas['DriverPerformanceResponse']
    if (!PERFORMANCE_SORTS.includes(field)) return badSort(field, PERFORMANCE_SORTS)
    const city = url.searchParams.get('city')
    const fleetId = url.searchParams.get('fleet_id')
    const atRisk = url.searchParams.get('at_risk')
    const minTrips = Number(url.searchParams.get('min_trips') ?? 0)
    const days = new Set(period.dates)
    const working = getDb().drivers.filter(
      (driver) =>
        (!fleetId || driver.fleet_id === fleetId) &&
        getDb().trips.some(
          (trip) =>
            trip.driver_id === driver.id &&
            days.has(trip.scheduled_departure_at.slice(0, 10)) &&
            (!city || tripCity(trip.id) === city),
        ),
    )
    const items = working
      .map((driver) => performance(driver, period))
      .filter(
        (row) =>
          row.trips_completed >= minTrips &&
          (atRisk === null || row.at_risk === (atRisk === 'true')),
      )
    const present = items.filter((row) => row[field] !== null)
    const missing = items.filter((row) => row[field] === null)
    present.sort((a, b) => Number(a[field]) - Number(b[field]))
    if (sort.startsWith('-')) present.reverse()
    const ordered = [...present, ...missing]
    if (url.searchParams.get('format') === 'csv') {
      return csvAnswer(ordered as unknown as Record<string, unknown>[], 'driver-performance')
    }
    return paginate(ordered, url)
  }),

  endpoint.get(
    '/admin/drivers/:driverId/performance',
    ['reports:view', 'drivers:approve'],
    ({ params, url }) => {
      const driver = index().drivers.get(params.driverId!)
      if (!driver) return notFound('Driver not found.')
      const period = resolvePeriod(url)
      if (period instanceof Response) return period
      const db = getDb()
      const ratings = (index().ratingsByDriver.get(driver.id) ?? []).filter((rating) =>
        period.dates.includes(rating.created_at.slice(0, 10)),
      )
      const wallet = walletFor(driver.user_id)
      const now = Date.now()
      const today = new Date(now).toISOString().slice(0, 10)
      const weekday = (new Date(now).getUTCDay() + 6) % 7
      const monday = new Date(now - weekday * DAY).toISOString().slice(0, 10)
      const monthStart = today.slice(0, 8) + '01'
      const earned = (from: string) =>
        wallet.transactions
          .filter(
            (tx) => tx.reference_type === 'trip_earning' && tx.created_at.slice(0, 10) >= from,
          )
          .reduce((sum, tx) => sum + tx.amount, 0)
      return {
        ...performance(driver, period),
        period: period.response,
        daily: period.dates.map((date) => {
          const counts = countsFor(driver, new Set([date]))
          return {
            date,
            trips_completed: counts.completed,
            on_time_rate: fixed(share(counts.onTime, counts.completed), 4),
            average_rating: counts.ratings
              ? (counts.ratingTotal / counts.ratings).toFixed(2)
              : null,
          }
        }),
        rating_distribution: [1, 2, 3, 4, 5].map((stars) => ({
          score: stars,
          count: ratings.filter((rating) => rating.overall === stars).length,
        })),
        recent_reviews: [...ratings]
          .sort((a, b) => b.created_at.localeCompare(a.created_at))
          .slice(0, 10)
          .map((rating) => ({
            rating_id: rating.id,
            trip_id: rating.trip_id,
            score: rating.overall,
            comment: rating.comment,
            created_at: rating.created_at,
          })),
        earnings: {
          today: money(earned(today)),
          this_week: money(earned(monday)),
          this_month: money(earned(monthStart)),
          currency: 'GHS',
          pending_withdrawals: money(
            db.withdrawals
              .filter((payout) => payout.user_id === driver.user_id && payout.status === 'pending')
              .reduce((sum, payout) => sum + payout.amount, 0),
          ),
        },
      } satisfies Schemas['DriverPerformanceDetailResponse']
    },
  ),
]
