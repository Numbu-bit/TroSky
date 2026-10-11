import type { Schemas } from '@/api/types'

import { getDb, index, MINUTE, routeStops, tripProgress } from '../db'
import { along, haversineKm } from '../geo'
import { csvAnswer, endpoint, errorResponse, notFound } from '../http'
import { liveLocation, liveTrip, tripDetail } from '../views'

const ON_THE_ROAD = new Set(['boarding', 'in_progress', 'paused'])

/** Average road speeds, for arrival estimates. */
function speedKmh(minutes: number, km: number): number {
  return Math.max(km / (minutes / 60), 12)
}

export const liveHandlers = [
  endpoint.get(
    '/admin/live-trips',
    ['trips:monitor_live', 'trips:manage'],
    (): Schemas['LiveTripResponse'][] =>
      getDb()
        .trips.filter((trip) => ON_THE_ROAD.has(trip.status))
        .map((trip) => liveTrip(trip)),
  ),

  endpoint.get('/trips/:tripId', 'public', ({ params }) => {
    const trip = index().trips.get(params.tripId!)
    return trip ? tripDetail(trip) : notFound('Trip not found.')
  }),

  endpoint.get('/trips/:tripId/location', 'team', ({ params }) => {
    const trip = index().trips.get(params.tripId!)
    if (!trip) return notFound('Trip not found.')
    return liveLocation(trip) ?? notFound('No location has been reported for this trip yet.')
  }),

  endpoint.get(
    '/trips/:tripId/eta',
    'team',
    ({ params, url }): Schemas['EtaResponse'] | Response => {
      const trip = index().trips.get(params.tripId!)
      if (!trip) return notFound('Trip not found.')
      const route = index().routes.get(trip.route_id)!
      const fraction = tripProgress(trip)
      if (fraction === null) {
        return errorResponse(
          409,
          'TRIP_NOT_IN_PROGRESS',
          'Arrival estimates are only available for trips on the road.',
        )
      }
      const wanted = url.searchParams.get('destination_stop_id')
      const stopIndex = wanted ? route.stop_ids.indexOf(wanted) : route.stop_ids.length - 1
      if (stopIndex < 0)
        return errorResponse(422, 'STOP_NOT_ON_ROUTE', 'That stop is not on this trip’s route.')
      const remaining = Math.max(route.offsets_km[stopIndex]! - fraction * route.distance_km, 0)
      const minutes = Math.round((remaining / speedKmh(route.minutes, route.distance_km)) * 60)
      return {
        distance_km: remaining.toFixed(2),
        duration_minutes: minutes,
        eta_at: new Date(Date.now() + minutes * MINUTE).toISOString(),
      }
    },
  ),

  endpoint.get(
    '/admin/trips/:tripId/track',
    ['trips:monitor_live', 'trips:manage'],
    ({ params, url }): Schemas['TripTrackResponse'] | Response => {
      const trip = index().trips.get(params.tripId!)
      if (!trip) return notFound('Trip not found.')
      const route = index().routes.get(trip.route_id)!
      const stops = routeStops(route)
      const departed = trip.actual_departure_at ? Date.parse(trip.actual_departure_at) : null
      const reached =
        trip.status === 'completed'
          ? 1
          : trip.status === 'cancelled'
            ? 0
            : (tripProgress(trip) ?? 0)
      const journey = route.minutes * MINUTE
      const count = departed ? Math.max(2, Math.round(reached * 120)) : 0
      // A looping demo bus has driven its current lap: its points start now - lap.
      const lapStart = departed ? (trip.live ? Date.now() - reached * journey : departed) : 0
      const points: Schemas['TrackPoint'][] = Array.from({ length: count }, (_, step) => {
        const share = (reached * step) / Math.max(count - 1, 1)
        const point = along(stops, share)
        return {
          latitude: Number(point.latitude.toFixed(6)),
          longitude: Number(point.longitude.toFixed(6)),
          speed_kmh: (30 + ((step * 7) % 34)).toFixed(2),
          heading_degrees: point.heading.toFixed(2),
          accuracy_meters: '6.00',
          recorded_at: new Date(lapStart + share * journey).toISOString(),
        }
      })
      const track: Schemas['TripTrackResponse'] = {
        trip_id: trip.id,
        status: trip.status,
        actual_departure_at: trip.actual_departure_at,
        actual_arrival_at: trip.actual_arrival_at,
        point_count: points.length,
        truncated: false,
        // As the backend: measured along the points returned.
        distance_km: points
          .reduce((km, point, step) => (step ? km + haversineKm(points[step - 1]!, point) : 0), 0)
          .toFixed(2),
        max_speed_kmh: points.length ? '63.00' : null,
        first_at: points[0]?.recorded_at ?? null,
        last_at: points.at(-1)?.recorded_at ?? null,
        points,
      }
      if (url.searchParams.get('format') === 'csv') {
        return csvAnswer(points as unknown as Record<string, unknown>[], `trip-${trip.id}-track`)
      }
      return track
    },
  ),
]
