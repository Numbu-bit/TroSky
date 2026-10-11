import type { Schemas } from '@/api/types'

import { getDb, index, MINUTE, touch, userName } from '../db'
import type { BookingRec, DriverActionRec, OfferRec, TripRec } from '../db/model'
import { personName } from '../ghana'
import { conflict, csvAnswer, endpoint, errorResponse, notFound, paginate } from '../http'
import { Random } from '../random'
import { adminName, booking as bookingView, money } from '../views'

const random = new Random(9090)
const ANSWER_SECONDS = 120
const BOOKABLE = new Set(['scheduled', 'boarding', 'in_progress'])

function log(entry: Omit<DriverActionRec, 'id' | 'created_at'>): void {
  getDb().driverActions.unshift({
    ...entry,
    id: random.uuid(),
    created_at: new Date().toISOString(),
  })
}

function offerFor(booking: BookingRec, trip: TripRec): OfferRec {
  const now = Date.now()
  const offer: OfferRec = {
    id: random.uuid(),
    booking_id: booking.id,
    trip_id: trip.id,
    driver_id: trip.driver_id,
    status: 'pending',
    expires_at: new Date(now + ANSWER_SECONDS * 1000).toISOString(),
    decided_at: null,
    decided_by: null,
    reason: null,
    created_at: new Date(now).toISOString(),
  }
  getDb().offers.push(offer)
  booking.expires_at = offer.expires_at
  return offer
}

/** Another trip on the same route, leaving within an hour, with a driver. */
function anotherTrip(booking: BookingRec, tried: Set<string>): TripRec | undefined {
  const current = index().trips.get(booking.trip_id)!
  const departs = Date.parse(current.scheduled_departure_at)
  return getDb().trips.find(
    (trip) =>
      trip.route_id === current.route_id &&
      !tried.has(trip.id) &&
      trip.driver_id !== null &&
      BOOKABLE.has(trip.status) &&
      Math.abs(Date.parse(trip.scheduled_departure_at) - departs) <= 60 * MINUTE,
  )
}

/** Move the booking on, as the backend does when nobody takes it. */
function moveOrEnd(
  booking: BookingRec,
  why: 'declined' | 'unanswered',
  actor: string | null,
): void {
  const tried = new Set(
    getDb()
      .offers.filter((offer) => offer.booking_id === booking.id)
      .map((offer) => offer.trip_id),
  )
  const next = tried.size <= 3 ? anotherTrip(booking, tried) : undefined
  if (next) {
    booking.trip_id = next.id
    booking.status = 'awaiting_acceptance'
    offerFor(booking, next)
  } else {
    booking.status = why === 'declined' ? 'cancelled' : 'expired'
    booking.expires_at = null
  }
  void actor
}

/** Live behaviour: unanswered requests move on, and new ones arrive. */
function tick(): void {
  const db = getDb()
  const now = Date.now()
  let changed = false
  for (const offer of db.offers) {
    if (offer.status !== 'pending' || Date.parse(offer.expires_at) > now) continue
    const booking = index().bookings.get(offer.booking_id)
    offer.status = 'expired'
    offer.decided_at = new Date(now).toISOString()
    offer.reason = 'Not answered in time'
    changed = true
    if (!booking || booking.status !== 'awaiting_acceptance') continue
    log({
      driver_id: offer.driver_id,
      trip_id: offer.trip_id,
      booking_id: booking.id,
      kind: 'booking_unanswered',
      acted_as: 'system',
      actor_id: null,
      reason: null,
      details: null,
    })
    moveOrEnd(booking, 'unanswered', null)
  }
  const waiting = db.offers.filter((offer) => offer.status === 'pending').length
  if (waiting < 3) {
    const soon = db.trips.filter(
      (trip) =>
        trip.driver_id &&
        trip.vehicle_id &&
        ['scheduled', 'boarding'].includes(trip.status) &&
        Date.parse(trip.scheduled_departure_at) > now &&
        Date.parse(trip.scheduled_departure_at) < now + 36 * 60 * MINUTE,
    )
    for (let count = waiting; count < 4 && soon.length; count += 1) {
      const trip = random.pick(soon)
      const route = index().routes.get(trip.route_id)!
      const passenger = random.pick(db.users.filter((user) => user.roles.includes('passenger')))
      const vehicle = index().vehicles.get(trip.vehicle_id!)!
      const taken = new Set(
        (index().bookingsByTrip.get(trip.id) ?? []).flatMap((existing) =>
          existing.passengers.map((p) => p.seat_id),
        ),
      )
      const seatIndex = vehicle.seat_ids.findIndex((seat) => !taken.has(seat))
      if (seatIndex < 0) continue
      const fare = route.fare
      const booking: BookingRec = {
        id: random.uuid(),
        reference: `TRK-${random.int(10_000_000, 99_999_999).toString(36).toUpperCase()}`,
        passenger_id: passenger.id,
        trip_id: trip.id,
        status: 'awaiting_acceptance',
        origin_index: 0,
        destination_index: route.stop_ids.length - 1,
        passenger_count: 1,
        fare_amount: fare,
        platform_fee: Math.max(0.5, Math.round(fare * 3) / 100),
        total_amount: Math.round((fare + Math.max(0.5, fare * 0.03)) * 100) / 100,
        created_at: new Date(now).toISOString(),
        expires_at: null,
        passengers: [
          {
            id: random.uuid(),
            seat_id: vehicle.seat_ids[seatIndex]!,
            seat_label: vehicle.seat_labels[seatIndex]!,
            full_name: passenger.full_name || personName(random),
            phone_number: passenger.phone_number,
            boarded_at: null,
            alighted_at: null,
          },
        ],
      }
      db.bookings.push(booking)
      offerFor(booking, trip)
      changed = true
    }
  }
  if (changed) touch()
}

function bookingRequest(offer: OfferRec): Schemas['BookingRequestResponse'] {
  const booking = index().bookings.get(offer.booking_id)!
  const trip = index().trips.get(offer.trip_id)!
  const route = index().routes.get(trip.route_id)!
  const stop = (position: number) => index().stops.get(route.stop_ids[position]!)
  const fullRoute =
    booking.origin_index === 0 && booking.destination_index === route.stop_ids.length - 1
  const attempt = getDb().offers.filter(
    (other) => other.booking_id === booking.id && other.created_at <= offer.created_at,
  ).length
  return {
    offer_id: offer.id,
    booking_id: booking.id,
    booking_reference: booking.reference,
    trip_id: trip.id,
    trip_departure_at: trip.scheduled_departure_at,
    driver_id: trip.driver_id,
    expires_at: offer.expires_at,
    seconds_left: Math.max(0, Math.round((Date.parse(offer.expires_at) - Date.now()) / 1000)),
    passenger_count: booking.passenger_count,
    passenger_name: booking.passengers[0]?.full_name ?? null,
    seat_numbers: booking.passengers.map((passenger) => passenger.seat_label),
    origin_stop_id: fullRoute ? null : route.stop_ids[booking.origin_index]!,
    origin_stop_name: fullRoute ? null : (stop(booking.origin_index)?.name ?? null),
    destination_stop_id: fullRoute ? null : route.stop_ids[booking.destination_index]!,
    destination_stop_name: fullRoute ? null : (stop(booking.destination_index)?.name ?? null),
    fare_amount: money(booking.fare_amount),
    attempt,
  }
}

function pendingOffer(bookingId: string): OfferRec | undefined {
  return getDb().offers.find(
    (offer) => offer.booking_id === bookingId && offer.status === 'pending',
  )
}

function notWaiting(booking: BookingRec): Response {
  return errorResponse(
    409,
    'BOOKING_NOT_AWAITING_ACCEPTANCE',
    'This booking is not waiting to be accepted.',
    {
      status: booking.status,
    },
  )
}

function tripAnswer(
  trip: TripRec,
  driverId: string,
  active: boolean,
  reason: string | null,
): Schemas['TripAnswerResponse'] {
  return {
    trip_id: trip.id,
    driver_id: driverId,
    response: active ? (trip.driver_response ?? 'pending') : 'declined',
    responded_at: new Date().toISOString(),
    response_reason: reason,
    is_active: active,
  }
}

export const dispatchHandlers = [
  endpoint.get('/admin/booking-requests', ['trips:manage', 'trips:monitor_live'], ({ url }) => {
    tick()
    const driverId = url.searchParams.get('driver_id')
    const tripId = url.searchParams.get('trip_id')
    const offers = getDb()
      .offers.filter(
        (offer) =>
          offer.status === 'pending' &&
          (!tripId || offer.trip_id === tripId) &&
          (!driverId || index().trips.get(offer.trip_id)?.driver_id === driverId),
      )
      .sort((a, b) => a.expires_at.localeCompare(b.expires_at))
    return paginate(offers.map(bookingRequest), url, 100)
  }),

  endpoint.post('/admin/bookings/:bookingId/accept', ['trips:manage'], ({ params, admin }) => {
    const booking = index().bookings.get(params.bookingId!)
    if (!booking) return notFound('Booking not found.')
    const offer = pendingOffer(booking.id)
    if (booking.status !== 'awaiting_acceptance' || !offer) return notWaiting(booking)
    const now = new Date().toISOString()
    offer.status = 'accepted'
    offer.decided_at = now
    offer.decided_by = admin.id
    booking.status = 'pending'
    booking.expires_at = new Date(Date.now() + 10 * MINUTE).toISOString()
    const trip = index().trips.get(booking.trip_id)!
    log({
      driver_id: trip.driver_id,
      trip_id: trip.id,
      booking_id: booking.id,
      kind: 'booking_accepted',
      acted_as: 'admin',
      actor_id: admin.id,
      reason: null,
      details: null,
    })
    touch()
    return bookingView(booking)
  }),

  endpoint.post(
    '/admin/bookings/:bookingId/decline',
    ['trips:manage'],
    ({ params, admin, body }) => {
      const booking = index().bookings.get(params.bookingId!)
      if (!booking) return notFound('Booking not found.')
      const request = body as Schemas['AdminDeclineBookingRequest']
      const offer = pendingOffer(booking.id)
      if (booking.status === 'awaiting_acceptance' && offer) {
        offer.status = 'declined'
        offer.decided_at = new Date().toISOString()
        offer.decided_by = admin.id
        offer.reason = request.reason
      } else if (booking.status !== 'pending') {
        return notWaiting(booking)
      }
      const trip = index().trips.get(booking.trip_id)!
      log({
        driver_id: trip.driver_id,
        trip_id: trip.id,
        booking_id: booking.id,
        kind: 'booking_declined',
        acted_as: 'admin',
        actor_id: admin.id,
        reason: request.reason,
        details: { move: request.move_to_another_trip ?? true },
      })
      if (request.move_to_another_trip ?? true) moveOrEnd(booking, 'declined', admin.id)
      else {
        booking.status = 'cancelled'
        booking.expires_at = null
      }
      touch()
      return bookingView(booking)
    },
  ),

  endpoint.post('/admin/bookings/:bookingId/move', ['trips:manage'], ({ params, admin, body }) => {
    const booking = index().bookings.get(params.bookingId!)
    if (!booking) return notFound('Booking not found.')
    if (booking.status !== 'awaiting_acceptance' && booking.status !== 'pending')
      return notWaiting(booking)
    const target = index().trips.get((body as Schemas['MoveBookingRequest']).trip_id)
    if (!target) return notFound('Trip not found.')
    if (target.id === booking.trip_id)
      return conflict('SAME_TRIP', 'The booking is already on this trip.')
    if (!BOOKABLE.has(target.status))
      return conflict('TRIP_NOT_BOOKABLE', 'This trip is not currently open for booking.')
    const current = index().trips.get(booking.trip_id)!
    const from = index().routes.get(current.route_id)!
    const to = index().routes.get(target.route_id)!
    const boards = from.stop_ids[booking.origin_index]!
    const alights = from.stop_ids[booking.destination_index]!
    const origin = to.stop_ids.indexOf(boards)
    const destination = to.stop_ids.indexOf(alights)
    if (origin < 0 || destination < 0 || origin >= destination) {
      return conflict(
        'TRIP_DOES_NOT_SERVE_SEGMENT',
        'This trip does not go from the booking’s pickup to its destination.',
      )
    }
    if (!target.driver_id) {
      return conflict(
        'TRIP_CANNOT_TAKE_BOOKING',
        'That trip has no driver, or not enough seats free, for this booking.',
      )
    }
    const offer = pendingOffer(booking.id)
    if (offer) {
      offer.status = 'withdrawn'
      offer.decided_at = new Date().toISOString()
      offer.decided_by = admin.id
      offer.reason = 'Moved by an admin'
    }
    booking.trip_id = target.id
    booking.origin_index = origin
    booking.destination_index = destination
    booking.status = 'awaiting_acceptance'
    offerFor(booking, target)
    touch()
    return bookingView(booking)
  }),

  endpoint.post('/admin/trips/:tripId/accept-for-driver', ['trips:manage'], ({ params, admin }) => {
    const trip = index().trips.get(params.tripId!)
    if (!trip) return notFound('Trip not found.')
    if (trip.status === 'completed' || trip.status === 'cancelled') {
      return errorResponse(409, 'INVALID_STATE_TRANSITION', `This trip is ${trip.status}.`)
    }
    if (!trip.driver_id) return conflict('TRIP_HAS_NO_DRIVER', 'This trip has no driver assigned.')
    trip.driver_response = 'accepted'
    log({
      driver_id: trip.driver_id,
      trip_id: trip.id,
      booking_id: null,
      kind: 'trip_accepted',
      acted_as: 'admin',
      actor_id: admin.id,
      reason: null,
      details: null,
    })
    touch()
    return tripAnswer(trip, trip.driver_id, true, null)
  }),

  endpoint.post(
    '/admin/trips/:tripId/decline-for-driver',
    ['trips:manage'],
    ({ params, admin, body }) => {
      const trip = index().trips.get(params.tripId!)
      if (!trip) return notFound('Trip not found.')
      if (trip.status === 'completed' || trip.status === 'cancelled') {
        return errorResponse(409, 'INVALID_STATE_TRANSITION', `This trip is ${trip.status}.`)
      }
      if (!trip.driver_id)
        return conflict('TRIP_HAS_NO_DRIVER', 'This trip has no driver assigned.')
      if (!['scheduled', 'boarding'].includes(trip.status)) {
        return errorResponse(
          409,
          'TRIP_ALREADY_STARTED',
          'A trip already on the road cannot be declined.',
        )
      }
      const reason = (body as Schemas['DeclineRequest']).reason
      const driverId = trip.driver_id
      log({
        driver_id: driverId,
        trip_id: trip.id,
        booking_id: null,
        kind: 'trip_declined',
        acted_as: 'admin',
        actor_id: admin.id,
        reason,
        details: null,
      })
      trip.driver_id = null
      trip.driver_response = null
      touch()
      return tripAnswer(trip, driverId, false, reason)
    },
  ),

  endpoint.post(
    '/admin/trips/:tripId/passengers/:passengerId/alight',
    ['trips:manage'],
    ({ params, admin, body }) => {
      const trip = index().trips.get(params.tripId!)
      const booking = getDb().bookings.find(
        (candidate) =>
          candidate.trip_id === params.tripId &&
          candidate.passengers.some((p) => p.id === params.passengerId),
      )
      const passenger = booking?.passengers.find((p) => p.id === params.passengerId)
      if (!trip || !booking || !passenger) return notFound('Passenger not found on this trip.')
      const respond = (): Schemas['AlightResponse'] => ({
        booking_passenger_id: passenger.id,
        booking_id: booking.id,
        alighted_at: passenger.alighted_at,
        alighted_stop_id: passenger.alighted_at
          ? (index().routes.get(trip.route_id)!.stop_ids[booking.destination_index] ?? null)
          : null,
        alighted_how: passenger.alighted_at ? 'admin' : null,
        booking_status: booking.status,
      })
      if (passenger.alighted_at) return respond()
      if (!['in_progress', 'paused'].includes(trip.status)) {
        return conflict(
          'TRIP_NOT_ON_THE_ROAD',
          'Passengers can only be marked off while the trip is on the road.',
        )
      }
      if (booking.status !== 'confirmed') {
        return conflict('BOOKING_NOT_PAID', 'Only a passenger who has paid can be marked off.')
      }
      void (body as Schemas['AlightRequest'] | undefined)
      passenger.alighted_at = new Date().toISOString()
      if (booking.passengers.every((p) => p.alighted_at)) booking.status = 'completed'
      log({
        driver_id: trip.driver_id,
        trip_id: trip.id,
        booking_id: booking.id,
        kind: 'passenger_alighted',
        acted_as: 'admin',
        actor_id: admin.id,
        reason: null,
        details: { passenger_ids: [passenger.id] },
      })
      touch()
      return respond()
    },
  ),

  endpoint.get('/admin/driver-actions', ['trips:manage', 'trips:monitor_live'], ({ url }) => {
    const driverId = url.searchParams.get('driver_id')
    const tripId = url.searchParams.get('trip_id')
    const bookingId = url.searchParams.get('booking_id')
    const kinds = (url.searchParams.get('kind') ?? '').split(',').filter(Boolean)
    const actedAs = url.searchParams.get('acted_as')
    const since = url.searchParams.get('since')
    const until = url.searchParams.get('until')
    const rows = getDb()
      .driverActions.filter(
        (action) =>
          (!driverId || action.driver_id === driverId) &&
          (!tripId || action.trip_id === tripId) &&
          (!bookingId || action.booking_id === bookingId) &&
          (!kinds.length || kinds.includes(action.kind)) &&
          (!actedAs || action.acted_as === actedAs) &&
          (!since || action.created_at >= new Date(since).toISOString()) &&
          (!until || action.created_at < new Date(until).toISOString()),
      )
      .map((action): Schemas['DriverActionResponse'] => ({
        id: action.id,
        created_at: action.created_at,
        kind: action.kind,
        acted_as: action.acted_as,
        driver_id: action.driver_id,
        driver_name: action.driver_id
          ? userName(index().drivers.get(action.driver_id)?.user_id)
          : null,
        actor_id: action.actor_id,
        actor_name: adminName(action.actor_id) ?? userName(action.actor_id),
        trip_id: action.trip_id,
        booking_id: action.booking_id,
        reason: action.reason,
        details: action.details,
      }))
    if (url.searchParams.get('format') === 'csv') return csvAnswer(rows, 'driver-actions')
    return paginate(rows, url, 50)
  }),
]
