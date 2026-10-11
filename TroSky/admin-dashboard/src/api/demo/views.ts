import type { Schemas } from '@/api/types'

import { teamMembers } from './accounts'
import { index, routeStops, seatsTaken, tripPosition, userName } from './db'
import type {
  BookingRec,
  CancellationRec,
  ComplaintRec,
  DriverRec,
  IncidentRec,
  PaymentRec,
  RefundRec,
  SosRec,
  TripRec,
  VehicleRec,
  WithdrawalRec,
} from './db/model'

/** The API's money: a decimal string with two places. */
export const money = (value: number): string => value.toFixed(2)

/** Mobile numbers as the API masks them for third parties. */
export function maskedPhone(phone: string): string {
  return `${phone.slice(0, 6)}•••${phone.slice(-4)}`
}

export const ESCALATION_CONTACTS: Schemas['EscalationContactResponse'][] = [
  { name: 'Ghana Police Service', phone_number: '191', role: 'police' },
  { name: 'National Ambulance Service', phone_number: '193', role: 'ambulance' },
  { name: 'Ghana National Fire Service', phone_number: '192', role: 'fire_service' },
  { name: 'TroSky duty manager', phone_number: '+233240000099', role: 'operations' },
]

// ------------------------------------------------------------------ trips
function tripSeats(trip: TripRec) {
  const { bookingsByTrip, vehicles, routes } = index()
  const capacity = trip.vehicle_id
    ? (vehicles.get(trip.vehicle_id)?.capacity ?? 0)
    : (routes.get(trip.route_id)?.seats ?? 0)
  let booked = 0
  let taken = 0
  let boarded = 0
  for (const booking of bookingsByTrip.get(trip.id) ?? []) {
    if (booking.status === 'confirmed' || booking.status === 'completed') {
      booked += booking.passenger_count
      boarded += booking.passengers.filter((passenger) => passenger.boarded_at).length
    }
    if (seatsTaken(booking) && booking.status !== 'completed') taken += booking.passenger_count
  }
  return { capacity, booked, taken, boarded }
}

export function tripSummary(trip: TripRec): Schemas['AdminTripSummaryResponse'] {
  const { routes, vehicles, drivers, stops } = index()
  const route = routes.get(trip.route_id)!
  const vehicle = trip.vehicle_id ? vehicles.get(trip.vehicle_id) : undefined
  const driver = trip.driver_id ? drivers.get(trip.driver_id) : undefined
  const seats = tripSeats(trip)
  return {
    trip_id: trip.id,
    route_id: route.id,
    route_name: route.name,
    origin_stop_name: stops.get(route.stop_ids[0]!)!.name,
    destination_stop_name: stops.get(route.stop_ids[route.stop_ids.length - 1]!)!.name,
    scheduled_departure_at: trip.scheduled_departure_at,
    scheduled_arrival_at: trip.scheduled_arrival_at,
    status: trip.status,
    vehicle_id: vehicle?.id ?? null,
    vehicle_registration_number: vehicle?.registration_number ?? null,
    seats_total: seats.capacity,
    seats_booked: seats.booked,
    boarded_count: seats.boarded,
    driver_response: driver ? trip.driver_response : null,
    driver_id: driver?.id ?? null,
    driver_name: driver ? userName(driver.user_id) : null,
    available_seats: Math.max(seats.capacity - seats.taken, 0),
  }
}

/** The stale one: its phone stopped reporting a few minutes ago. */
function isStale(trip: TripRec): boolean {
  return Boolean(trip.stale_gps)
}

export function liveTrip(trip: TripRec, now = Date.now()): Schemas['LiveTripResponse'] {
  const { routes, vehicles, drivers } = index()
  const vehicle = trip.vehicle_id ? vehicles.get(trip.vehicle_id) : undefined
  const driver = trip.driver_id ? drivers.get(trip.driver_id) : undefined
  // Boarding buses have not sent a position yet.
  const position = trip.status === 'boarding' ? null : tripPosition(trip, now)
  const stale = isStale(trip)
  return {
    trip_id: trip.id,
    route_name: routes.get(trip.route_id)!.name,
    vehicle_registration_number: vehicle?.registration_number ?? null,
    driver_name: driver ? userName(driver.user_id) : null,
    status: trip.status,
    latitude: position?.latitude ?? null,
    longitude: position?.longitude ?? null,
    heading: position ? position.heading.toFixed(2) : null,
    updated_at: position ? new Date(now - (stale ? 4 * 60_000 : 2_000)).toISOString() : null,
    is_stale: position ? stale : null,
  }
}

export function liveLocation(
  trip: TripRec,
  now = Date.now(),
): Schemas['LiveLocationResponse'] | null {
  const position = trip.status === 'boarding' ? null : tripPosition(trip, now)
  if (!position) return null
  return {
    trip_id: trip.id,
    latitude: position.latitude,
    longitude: position.longitude,
    speed_kmh: trip.status === 'paused' ? '0.00' : (38 + ((now / 7000) % 17)).toFixed(2),
    heading_degrees: position.heading.toFixed(2),
    recorded_at: new Date(now - (isStale(trip) ? 4 * 60_000 : 2_000)).toISOString(),
    is_stale: isStale(trip),
  }
}

export function tripDetail(trip: TripRec): Schemas['TripDetailResponse'] {
  const { routes, vehicles, drivers, stops } = index()
  const route = routes.get(trip.route_id)!
  const vehicle = trip.vehicle_id ? vehicles.get(trip.vehicle_id) : undefined
  const driver = trip.driver_id ? drivers.get(trip.driver_id) : undefined
  const seats = tripSeats(trip)
  const rating = driver ? driverRating(driver.id) : null
  return {
    id: trip.id,
    route_id: route.id,
    route_schedule_id: trip.schedule_id,
    scheduled_departure_at: trip.scheduled_departure_at,
    scheduled_arrival_at: trip.scheduled_arrival_at,
    actual_departure_at: trip.actual_departure_at,
    actual_arrival_at: trip.actual_arrival_at,
    status: trip.status,
    fare_amount: money(trip.fare_amount),
    created_at: trip.created_at,
    route_name: route.name,
    origin_stop_id: route.stop_ids[0]!,
    origin_stop_name: stops.get(route.stop_ids[0]!)!.name,
    destination_stop_id: route.stop_ids[route.stop_ids.length - 1]!,
    destination_stop_name: stops.get(route.stop_ids[route.stop_ids.length - 1]!)!.name,
    vehicle: vehicle
      ? {
          registration_number: vehicle.registration_number,
          type: vehicle.vehicle_type,
          make_model: `${vehicle.make} ${vehicle.model}`,
          capacity: vehicle.capacity,
        }
      : null,
    driver: driver
      ? {
          id: driver.id,
          full_name: userName(driver.user_id),
          avatar_url: null,
          average_rating: rating?.average ?? null,
          rating_count: rating?.count ?? 0,
        }
      : null,
    riders_count: seats.booked,
    seats_total: seats.capacity,
    available_seats: Math.max(seats.capacity - seats.taken, 0),
  }
}

export function driverRating(driverId: string): { average: string; count: number } | null {
  let sum = 0
  let count = 0
  for (const rating of index().ratingsByDriver.get(driverId) ?? []) {
    sum += rating.overall
    count += 1
  }
  return count ? { average: (sum / count).toFixed(2), count } : null
}

// ----------------------------------------------------------------- safety
export function sosAlert(alert: SosRec): Schemas['SosAlertResponse'] {
  return {
    id: alert.id,
    trip_id: alert.trip_id,
    triggered_by: alert.triggered_by,
    status: alert.status,
    acknowledged_by: alert.acknowledged_by,
    acknowledged_at: alert.acknowledged_at,
    resolved_by: alert.resolved_by,
    resolved_at: alert.resolved_at,
    resolution_notes: alert.resolution_notes,
    created_at: alert.created_at,
  }
}

export function sosDetail(alert: SosRec, now = Date.now()): Schemas['AdminSosAlertDetailResponse'] {
  const { trips, users, routes, vehicles, drivers, fleets, owners } = index()
  const trip = alert.trip_id ? trips.get(alert.trip_id) : undefined
  const person = users.get(alert.triggered_by)
  let tripView: Schemas['SosTripResponse'] | null = null
  if (trip) {
    const vehicle = trip.vehicle_id ? vehicles.get(trip.vehicle_id) : undefined
    const driver = trip.driver_id ? drivers.get(trip.driver_id) : undefined
    const driverUser = driver ? users.get(driver.user_id) : undefined
    const fleet = vehicle ? fleets.get(vehicle.fleet_id) : undefined
    const owner = fleet ? owners.get(fleet.owner_id) : undefined
    const ownerUser = owner ? users.get(owner.user_id) : undefined
    const position = tripPosition(trip, now)
    tripView = {
      trip_id: trip.id,
      status: trip.status,
      route_name: routes.get(trip.route_id)!.name,
      scheduled_departure_at: trip.scheduled_departure_at,
      vehicle_registration_number: vehicle?.registration_number ?? null,
      driver_name: driverUser?.full_name ?? null,
      driver_phone: driverUser?.phone_number ?? null,
      fleet_owner_name: owner?.business_name ?? null,
      fleet_owner_phone: ownerUser?.phone_number ?? null,
      last_position: position
        ? {
            latitude: position.latitude,
            longitude: position.longitude,
            speed_kmh: '32.00',
            heading_degrees: position.heading.toFixed(2),
            accuracy_meters: '8.00',
            recorded_at: new Date(now - 3_000).toISOString(),
          }
        : null,
    }
  }
  return {
    ...sosAlert(alert),
    latitude: alert.latitude,
    longitude: alert.longitude,
    triggered_by_name: person?.full_name ?? null,
    triggered_by_phone: person?.phone_number ?? '',
    trip: tripView,
    escalations: alert.escalations.map((escalation) => ({
      id: escalation.id,
      sos_alert_id: alert.id,
      contact_type: escalation.contact_type,
      contact_name: escalation.contact_name,
      phone_number: escalation.phone_number,
      contacted_at: escalation.contacted_at,
      notes: escalation.notes,
      logged_by: escalation.logged_by,
      logged_by_name: userName(escalation.logged_by) ?? adminName(escalation.logged_by),
      created_at: escalation.created_at,
    })),
    escalation_contacts: ESCALATION_CONTACTS,
  }
}

export function incident(record: IncidentRec): Schemas['IncidentResponse'] {
  return {
    id: record.id,
    trip_id: record.trip_id,
    reported_by: record.reported_by,
    incident_type: record.incident_type,
    severity: record.severity,
    description: record.description,
    photo_url: null,
    status: record.status,
    resolved_by: record.resolved_by,
    resolved_at: record.resolved_at,
    resolution_notes: record.resolution_notes,
    created_at: record.created_at,
  }
}

// ---------------------------------------------------- people and vehicles
export function driverResponse(driver: DriverRec): Schemas['DriverResponse'] {
  const user = index().users.get(driver.user_id)
  return {
    id: driver.id,
    user_id: driver.user_id,
    full_name: user?.full_name ?? null,
    phone_number: user?.phone_number ?? null,
    license_number: driver.license_number,
    license_expiry: driver.license_expiry,
    license_class: driver.license_class,
    years_of_experience: driver.years_of_experience,
    status: driver.status,
    created_at: driver.created_at,
  }
}

export function vehicleResponse(vehicle: VehicleRec): Schemas['VehicleResponse'] {
  return {
    id: vehicle.id,
    fleet_id: vehicle.fleet_id,
    registration_number: vehicle.registration_number,
    vehicle_type: vehicle.vehicle_type,
    make: vehicle.make,
    model: vehicle.model,
    year: vehicle.year,
    capacity: vehicle.capacity,
    status: vehicle.status,
    created_at: vehicle.created_at,
  }
}

/** The admin team are not platform users in the demo: name them here. */
export function adminName(id: string | null | undefined): string | null {
  if (!id) return null
  return teamMembers().find((member) => member.id === id)?.full_name ?? null
}

// --------------------------------------------------------- support & money
export function adminComplaint(
  record: ComplaintRec,
  now = Date.now(),
): Schemas['AdminComplaintResponse'] {
  const filer = index().users.get(record.filed_by)
  const open = record.status === 'open' || record.status === 'in_review'
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
    priority: record.priority,
    filed_by_name: filer?.full_name ?? null,
    filed_by_phone: filer?.phone_number ?? null,
    assigned_to: record.assigned_to,
    assignee_name: adminName(record.assigned_to),
    assigned_at: record.assigned_at,
    first_response_at: record.first_response_at,
    due_at: record.due_at,
    is_overdue: open && Date.parse(record.due_at) < now,
  }
}

export function refundRequest(record: RefundRec): Schemas['RefundRequestResponse'] {
  return {
    id: record.id,
    payment_id: record.payment_id,
    booking_id: record.booking_id,
    amount: money(record.amount),
    reason: record.reason,
    status: record.status,
    reviewed_by: record.reviewed_by,
    reviewed_at: record.reviewed_at,
    decision_notes: record.decision_notes,
    provider_refund_reference: record.provider_refund_reference,
    failure_reason: record.failure_reason,
    created_at: record.created_at,
  }
}

export function cancellationRequest(
  record: CancellationRec,
): Schemas['CancellationRequestResponse'] {
  return {
    id: record.id,
    booking_id: record.booking_id,
    requested_by: record.requested_by,
    reason: record.reason,
    status: record.status,
    refund_eligible: record.refund_eligible,
    decided_by: record.decided_by,
    decided_at: record.decided_at,
    decision_notes: record.decision_notes,
    created_at: record.created_at,
  }
}

export function withdrawal(record: WithdrawalRec): Schemas['WithdrawalResponse'] {
  return {
    id: record.id,
    user_id: record.user_id,
    amount: money(record.amount),
    channel: record.channel,
    destination_phone_number: record.destination_phone_number,
    status: record.status,
    reviewed_by: record.reviewed_by,
    reviewed_at: record.reviewed_at,
    decision_notes: record.decision_notes,
    provider_reference: record.provider_reference,
    failure_reason: record.failure_reason,
    created_at: record.created_at,
  }
}

export function payment(record: PaymentRec): Schemas['PaymentResponse'] {
  return {
    id: record.id,
    booking_id: record.booking_id,
    purpose: record.purpose,
    channel: record.channel,
    status: record.status,
    amount: money(record.amount),
    currency: 'GHS',
    refunded_amount: money(record.refunded_amount),
    provider_reference: record.provider_reference,
    failure_reason: record.failure_reason,
    initiated_at: record.created_at,
    completed_at: record.completed_at,
    created_at: record.created_at,
  }
}

export function booking(record: BookingRec): Schemas['BookingResponse'] {
  const { trips, routes, stops, vehicles } = index()
  const trip = trips.get(record.trip_id)!
  const route = routes.get(trip.route_id)!
  const routeStopList = routeStops(route)
  const vehicle = trip.vehicle_id ? vehicles.get(trip.vehicle_id) : undefined
  return {
    id: record.id,
    booking_reference: record.reference,
    trip_id: record.trip_id,
    status: record.status,
    passenger_count: record.passenger_count,
    origin_stop_id: route.stop_ids[record.origin_index] ?? null,
    destination_stop_id: route.stop_ids[record.destination_index] ?? null,
    fare_amount: money(record.fare_amount),
    platform_fee: money(record.platform_fee),
    total_amount: money(record.total_amount),
    expires_at: record.expires_at,
    created_at: record.created_at,
    passengers: record.passengers.map((passenger) => ({
      id: passenger.id,
      seat_id: passenger.seat_id,
      full_name: passenger.full_name,
      phone_number: passenger.phone_number,
    })),
    trip: {
      scheduled_departure_at: trip.scheduled_departure_at,
      route_name: route.name,
      origin_stop_name: stops.get(route.stop_ids[0]!)!.name,
      destination_stop_name: stops.get(route.stop_ids[route.stop_ids.length - 1]!)!.name,
      status: trip.status,
      vehicle_registration_number: vehicle?.registration_number ?? null,
    },
    boarding_stop_name: routeStopList[record.origin_index]?.name ?? null,
    alighting_stop_name: routeStopList[record.destination_index]?.name ?? null,
  }
}
