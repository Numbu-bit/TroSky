import { HttpResponse } from 'msw'

import type { Schemas } from '@/api/types'

import { getDb, index, MINUTE, touch } from '../db'
import type { TripRec } from '../db/model'
import { csvAnswer, endpoint, errorResponse, notFound, paginate } from '../http'
import { Random } from '../random'
import { money, tripSummary } from '../views'

const ids = new Random(5151)

export function tripResponse(trip: TripRec): Schemas['TripResponse'] {
  return {
    id: trip.id,
    route_id: trip.route_id,
    route_schedule_id: trip.schedule_id,
    scheduled_departure_at: trip.scheduled_departure_at,
    scheduled_arrival_at: trip.scheduled_arrival_at,
    actual_departure_at: trip.actual_departure_at,
    actual_arrival_at: trip.actual_arrival_at,
    status: trip.status,
    fare_amount: money(trip.fare_amount),
    created_at: trip.created_at,
  }
}

function newTrip(
  routeId: string,
  departure: string,
  fare: number,
  arrival?: string | null,
  scheduleId: string | null = null,
): TripRec {
  const route = index().routes.get(routeId)!
  const leaves = Date.parse(departure)
  return {
    id: ids.uuid(),
    route_id: routeId,
    schedule_id: scheduleId,
    vehicle_id: null,
    driver_id: null,
    driver_response: null,
    scheduled_departure_at: new Date(leaves).toISOString(),
    scheduled_arrival_at: arrival ?? new Date(leaves + route.minutes * MINUTE).toISOString(),
    actual_departure_at: null,
    actual_arrival_at: null,
    status: 'scheduled',
    fare_amount: fare,
    created_at: new Date().toISOString(),
    live: false,
  }
}

const BEFORE_DEPARTURE = new Set(['scheduled', 'boarding'])

export const tripHandlers = [
  endpoint.get('/admin/trips', ['trips:manage', 'trips:monitor_live'], ({ url }) => {
    const statuses = (url.searchParams.get('status') ?? '').split(',').filter(Boolean)
    const date = url.searchParams.get('date')
    const routeId = url.searchParams.get('route_id')
    const driverId = url.searchParams.get('driver_id')
    // Filter and page first: the seats on each trip take a moment to count.
    const matching = getDb()
      .trips.filter(
        (trip) =>
          (!statuses.length || statuses.includes(trip.status)) &&
          (!date || trip.scheduled_departure_at.slice(0, 10) === date) &&
          (!routeId || trip.route_id === routeId) &&
          (!driverId || trip.driver_id === driverId),
      )
      .sort((a, b) => a.scheduled_departure_at.localeCompare(b.scheduled_departure_at))
    if (url.searchParams.get('format') === 'csv') {
      return csvAnswer(matching.slice(0, 10_000).map(tripSummary), 'trips')
    }
    const page = paginate(matching, url)
    return { ...page, items: page.items.map(tripSummary) }
  }),

  endpoint.post('/admin/trips', ['trips:manage'], ({ body }) => {
    const request = body as Schemas['TripCreateRequest']
    const route = index().routes.get(request.route_id)
    if (!route || !route.is_active) return notFound('Route not found.')
    if (Date.parse(request.scheduled_departure_at) < Date.now() - 5 * MINUTE) {
      return errorResponse(422, 'VALIDATION_ERROR', 'The departure must be in the future.', {
        errors: [
          { loc: ['body', 'scheduled_departure_at'], msg: 'The departure must be in the future.' },
        ],
      })
    }
    const trip = newTrip(
      route.id,
      request.scheduled_departure_at,
      Number(request.fare_amount),
      request.scheduled_arrival_at,
    )
    getDb().trips.push(trip)
    touch()
    return HttpResponse.json(tripResponse(trip), { status: 201 })
  }),

  endpoint.post('/admin/trips/from-schedule', ['trips:manage'], ({ body }) => {
    const request = body as Schemas['ScheduleTripRequest']
    const schedule = getDb().schedules.find((candidate) => candidate.id === request.schedule_id)
    if (!schedule || !schedule.is_active) return notFound('Schedule not found.')
    const trip = newTrip(
      schedule.route_id,
      `${request.travel_date}T${schedule.departure_time}Z`,
      schedule.fare_amount,
      null,
      schedule.id,
    )
    getDb().trips.push(trip)
    touch()
    return HttpResponse.json(tripResponse(trip), { status: 201 })
  }),

  endpoint.post('/admin/trips/:tripId/assign-driver', ['trips:manage'], ({ params, body }) => {
    const trip = index().trips.get(params.tripId!)
    if (!trip) return notFound('Trip not found.')
    if (!BEFORE_DEPARTURE.has(trip.status)) {
      return errorResponse(
        409,
        'INVALID_STATE_TRANSITION',
        'Drivers can only be (re)assigned before a trip is in progress.',
      )
    }
    const driver = index().drivers.get((body as Schemas['AssignTripDriverRequest']).driver_id)
    if (!driver) return notFound('Driver not found.')
    if (driver.status !== 'approved') {
      return errorResponse(403, 'FORBIDDEN', 'Only an approved driver may be assigned to a trip.')
    }
    trip.driver_id = driver.id
    trip.driver_response = 'pending'
    touch()
    return { message: 'Driver assigned.' } satisfies Schemas['MessageResponse']
  }),

  endpoint.post('/admin/trips/:tripId/assign-vehicle', ['trips:manage'], ({ params, body }) => {
    const trip = index().trips.get(params.tripId!)
    if (!trip) return notFound('Trip not found.')
    if (!BEFORE_DEPARTURE.has(trip.status)) {
      return errorResponse(
        409,
        'INVALID_STATE_TRANSITION',
        'A vehicle can only be (re)assigned before a trip is in progress.',
      )
    }
    const vehicle = index().vehicles.get((body as Schemas['AssignTripVehicleRequest']).vehicle_id)
    if (!vehicle) return notFound('Vehicle not found.')
    if (vehicle.status !== 'approved') {
      return errorResponse(403, 'FORBIDDEN', 'Only an approved vehicle may be assigned to a trip.')
    }
    trip.vehicle_id = vehicle.id
    touch()
    return { message: 'Vehicle assigned.' } satisfies Schemas['MessageResponse']
  }),

  endpoint.post('/admin/trips/:tripId/cancel', ['trips:manage'], ({ params, body, admin }) => {
    const db = getDb()
    const trip = index().trips.get(params.tripId!)
    if (!trip) return notFound('Trip not found.')
    if (trip.status === 'completed' || trip.status === 'cancelled') {
      return errorResponse(
        409,
        'INVALID_STATE_TRANSITION',
        `A ${trip.status} trip cannot be cancelled.`,
      )
    }
    const reason =
      (body as Schemas['CancelTripRequest'] | undefined)?.reason ??
      'The trip was cancelled by the operator.'
    const now = new Date().toISOString()
    let cancelled = 0
    let refunds = 0
    let refundAmount = 0
    for (const booking of index().bookingsByTrip.get(trip.id) ?? []) {
      if (
        !['awaiting_acceptance', 'pending', 'payment_pending', 'confirmed'].includes(booking.status)
      )
        continue
      cancelled += 1
      const paid = booking.status === 'confirmed'
      booking.status = paid ? 'refund_pending' : 'cancelled'
      for (const offer of db.offers) {
        if (offer.booking_id === booking.id && offer.status === 'pending') {
          offer.status = 'withdrawn'
          offer.decided_at = now
          offer.reason = 'Trip cancelled'
        }
      }
      if (paid) {
        const payment = (index().paymentsByBooking.get(booking.id) ?? []).find(
          (p) => p.status === 'successful',
        )
        if (payment) {
          refunds += 1
          refundAmount += payment.amount
          db.refunds.push({
            id: ids.uuid(),
            payment_id: payment.id,
            booking_id: booking.id,
            amount: payment.amount,
            reason,
            status: 'pending',
            reviewed_by: null,
            reviewed_at: null,
            decision_notes: null,
            provider_refund_reference: null,
            failure_reason: null,
            created_at: now,
          })
        }
      }
      db.cancellations.push({
        id: ids.uuid(),
        booking_id: booking.id,
        requested_by: admin.id,
        reason,
        status: 'approved',
        refund_eligible: paid,
        decided_by: admin.id,
        decided_at: now,
        decision_notes: null,
        created_at: now,
      })
    }
    trip.status = 'cancelled'
    trip.live = false
    touch()
    return {
      ...tripResponse(trip),
      bookings_cancelled: cancelled,
      refunds_queued: refunds,
      refund_amount: money(refundAmount),
    } satisfies Schemas['TripCancellationResponse']
  }),
]
