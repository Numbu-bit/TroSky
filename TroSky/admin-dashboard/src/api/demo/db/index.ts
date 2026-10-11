import { along, type LatLng } from '../geo'
import { buildDemoDb, MINUTE, type DemoDb } from './build'
import type {
  BookingRec,
  DriverRec,
  FleetOwnerRec,
  FleetRec,
  PaymentRec,
  RatingRec,
  RouteRec,
  StopRec,
  TripRec,
  UserRec,
  VehicleRec,
} from './model'

export { DAY, HISTORY_DAYS, HOUR, MINUTE } from './build'
export type { DemoDb } from './build'

let db: DemoDb | null = null
let version = 0
/** Changed since it was built: tests then need a fresh copy. */
let dirty = false

/** The demo platform, built on first use. */
export function getDb(): DemoDb {
  db ??= buildDemoDb()
  return db
}

/**
 * Tests: start the next one from the platform as built. Rebuilt only if a
 * test changed it (building takes a moment).
 */
export function resetDemoDb(): void {
  if (!dirty) return
  db = null
  dirty = false
  version += 1
  cached = null
}

/** Call after any change, so indexes are rebuilt and tests get a fresh copy. */
export function touch(): void {
  version += 1
  dirty = true
}

interface Index {
  version: number
  users: Map<string, UserRec>
  stops: Map<string, StopRec>
  routes: Map<string, RouteRec>
  vehicles: Map<string, VehicleRec>
  drivers: Map<string, DriverRec>
  driverByUser: Map<string, DriverRec>
  fleets: Map<string, FleetRec>
  owners: Map<string, FleetOwnerRec>
  trips: Map<string, TripRec>
  bookings: Map<string, BookingRec>
  bookingsByTrip: Map<string, BookingRec[]>
  paymentsByBooking: Map<string, PaymentRec[]>
  ratingsByDriver: Map<string, RatingRec[]>
}

let cached: Index | null = null

/** Lookups by id, rebuilt whenever records were added. */
export function index(): Index {
  const data = getDb()
  if (cached && cached.version === version) return cached
  const byTrip = new Map<string, BookingRec[]>()
  for (const booking of data.bookings) {
    const list = byTrip.get(booking.trip_id)
    if (list) list.push(booking)
    else byTrip.set(booking.trip_id, [booking])
  }
  const byBooking = new Map<string, PaymentRec[]>()
  for (const payment of data.payments) {
    if (!payment.booking_id) continue
    const list = byBooking.get(payment.booking_id)
    if (list) list.push(payment)
    else byBooking.set(payment.booking_id, [payment])
  }
  const byDriver = new Map<string, RatingRec[]>()
  for (const rating of data.ratings) {
    const list = byDriver.get(rating.driver_id)
    if (list) list.push(rating)
    else byDriver.set(rating.driver_id, [rating])
  }
  cached = {
    version,
    users: new Map(data.users.map((user) => [user.id, user])),
    stops: new Map(data.stops.map((stop) => [stop.id, stop])),
    routes: new Map(data.routes.map((route) => [route.id, route])),
    vehicles: new Map(data.vehicles.map((vehicle) => [vehicle.id, vehicle])),
    drivers: new Map(data.drivers.map((driver) => [driver.id, driver])),
    driverByUser: new Map(data.drivers.map((driver) => [driver.user_id, driver])),
    fleets: new Map(data.fleets.map((fleet) => [fleet.id, fleet])),
    owners: new Map(data.fleetOwners.map((owner) => [owner.id, owner])),
    trips: new Map(data.trips.map((trip) => [trip.id, trip])),
    bookings: new Map(data.bookings.map((booking) => [booking.id, booking])),
    bookingsByTrip: byTrip,
    paymentsByBooking: byBooking,
    ratingsByDriver: byDriver,
  }
  return cached
}

// -------------------------------------------------------------- helpers
export function routeStops(route: RouteRec): StopRec[] {
  const { stops } = index()
  return route.stop_ids.map((id) => stops.get(id)!)
}

export function userName(id: string | null | undefined): string | null {
  return id ? (index().users.get(id)?.full_name ?? null) : null
}

export function driverName(driverId: string | null | undefined): string | null {
  if (!driverId) return null
  const driver = index().drivers.get(driverId)
  return driver ? userName(driver.user_id) : null
}

/** Paid bookings still holding (or having used) their seats. */
export function seatsTaken(booking: BookingRec): boolean {
  return ['awaiting_acceptance', 'pending', 'payment_pending', 'confirmed', 'completed'].includes(
    booking.status,
  )
}

/**
 * How far along its route a bus is now (0-1). Demo buses loop along their
 * route, so the live map always has traffic; others stop at the end.
 */
export function tripProgress(trip: TripRec, now = Date.now()): number | null {
  if (!['in_progress', 'paused', 'boarding'].includes(trip.status)) return null
  const route = index().routes.get(trip.route_id)
  if (!route) return null
  if (trip.status === 'boarding' || !trip.actual_departure_at) return 0
  const departed = Date.parse(trip.actual_departure_at)
  const journey = route.minutes * MINUTE
  if (trip.status === 'paused') return trip.live ? 0.4 : Math.min((now - departed) / journey, 1)
  const elapsed = now - departed
  return trip.live ? (elapsed % journey) / journey : Math.min(elapsed / journey, 1)
}

/** Where a bus is now, and which way it faces. */
export function tripPosition(
  trip: TripRec,
  now = Date.now(),
): (LatLng & { heading: number }) | null {
  const fraction = tripProgress(trip, now)
  if (fraction === null) return null
  return along(routeStops(index().routes.get(trip.route_id)!), fraction)
}
