import { HttpResponse } from 'msw'

import type { Schemas } from '@/api/types'

import { getDb, index, touch } from '../db'
import type { RouteRec, StopRec } from '../db/model'
import { offsets } from '../geo'
import {
  conflict,
  endpoint,
  errorResponse,
  notFound,
  pageParams,
  paginate,
  QueryError,
} from '../http'
import { Random } from '../random'
import { money } from '../views'

const ids = new Random(4242)
const UNFINISHED = new Set(['scheduled', 'boarding', 'in_progress', 'paused'])

export function stopResponse(stop: StopRec): Schemas['StopResponse'] {
  return {
    id: stop.id,
    name: stop.name,
    code: stop.code,
    address: stop.address,
    city: stop.city,
    region: stop.region,
    latitude: stop.latitude,
    longitude: stop.longitude,
  }
}

export function routeResponse(route: RouteRec): Schemas['RouteResponse'] {
  return {
    id: route.id,
    name: route.name,
    origin_stop_id: route.stop_ids[0]!,
    destination_stop_id: route.stop_ids[route.stop_ids.length - 1]!,
    distance_km: route.distance_km.toFixed(2),
    estimated_duration_minutes: route.minutes,
    is_active: route.is_active,
    created_at: route.created_at,
  }
}

function measure(route: RouteRec): void {
  const points = route.stop_ids.map((id) => index().stops.get(id)!)
  const straight = offsets(points)
  const total = straight[straight.length - 1] || 1
  route.offsets_km = straight.map((km) => Math.round((km / total) * route.distance_km * 100) / 100)
}

const created = (body: unknown) =>
  HttpResponse.json(body as Record<string, unknown>, { status: 201 })

export const networkHandlers = [
  // ---------------------------------------------------------------- stops
  endpoint.get('/stops', 'public', ({ url }) => {
    const active = getDb()
      .stops.filter((stop) => stop.is_active)
      .sort((a, b) => a.name.localeCompare(b.name))
    const raw = url.searchParams.get('q')
    if (raw === null) return paginate(active.map(stopResponse), url)
    // As the backend: a name search of 2+ characters, one page, no offset.
    if (raw.length < 2) throw new QueryError('q', 'String should have at least 2 characters')
    const q = raw.trim().toLowerCase()
    const { limit } = pageParams(url)
    const found = active.filter((stop) => stop.name.toLowerCase().includes(q)).slice(0, limit)
    return { items: found.map(stopResponse), total: found.length, limit, offset: 0 }
  }),

  endpoint.post('/admin/stops', ['routes:manage'], ({ body }) => {
    const request = body as Schemas['StopCreateRequest']
    const db = getDb()
    if (
      request.code &&
      db.stops.some((stop) => stop.code.toLowerCase() === request.code!.toLowerCase())
    ) {
      return conflict('STOP_CODE_TAKEN', 'Another stop already uses this code.')
    }
    const stop: StopRec = {
      id: ids.uuid(),
      key: request.name.toLowerCase().replace(/\W+/g, '-'),
      name: request.name,
      code: request.code ?? request.name.slice(0, 4).toUpperCase(),
      address: request.address ?? null,
      city: request.city ?? 'Accra',
      region: request.region ?? 'Greater Accra',
      latitude: request.latitude,
      longitude: request.longitude,
      is_active: true,
    }
    db.stops.push(stop)
    touch()
    return created(stopResponse(stop))
  }),

  endpoint.patch('/admin/stops/:stopId', ['routes:manage'], ({ params, body }) => {
    const stop = index().stops.get(params.stopId!)
    if (!stop || !stop.is_active) return notFound('Stop not found.')
    const changes = body as Schemas['StopUpdateRequest']
    if (
      changes.code &&
      getDb().stops.some(
        (other) => other.id !== stop.id && other.code.toLowerCase() === changes.code!.toLowerCase(),
      )
    ) {
      return conflict('STOP_CODE_TAKEN', 'Another stop already uses this code.')
    }
    for (const key of [
      'name',
      'code',
      'address',
      'city',
      'region',
      'latitude',
      'longitude',
    ] as const) {
      const value = changes[key]
      if (value !== undefined && value !== null)
        (stop as unknown as Record<string, unknown>)[key] = value
    }
    touch()
    return stopResponse(stop)
  }),

  endpoint.delete('/admin/stops/:stopId', ['routes:manage'], ({ params }) => {
    const stop = index().stops.get(params.stopId!)
    if (!stop || !stop.is_active) return notFound('Stop not found.')
    const using = getDb().routes.filter(
      (route) => route.is_active && route.stop_ids.includes(stop.id),
    )
    if (using.length) {
      return conflict(
        'STOP_IN_USE',
        'This stop is on active routes. Deactivate those routes first.',
        {
          routes: using.map((route) => route.name),
        },
      )
    }
    stop.is_active = false
    touch()
  }),

  // --------------------------------------------------------------- routes
  endpoint.get('/routes', 'public', ({ url }) =>
    paginate(
      getDb()
        .routes.filter((route) => route.is_active)
        .sort((a, b) => a.name.localeCompare(b.name))
        .map(routeResponse),
      url,
    ),
  ),

  endpoint.get('/routes/:routeId', 'public', ({ params }) => {
    const route = index().routes.get(params.routeId!)
    if (!route || !route.is_active) return notFound('Route not found.')
    return {
      ...routeResponse(route),
      stops: route.stop_ids.map((id) => stopResponse(index().stops.get(id)!)),
    } satisfies Schemas['RouteDetailResponse']
  }),

  endpoint.post('/admin/routes', ['routes:manage'], ({ body }) => {
    const request = body as Schemas['RouteCreateRequest']
    const db = getDb()
    const stopIds = [
      request.origin_stop_id,
      ...(request.intermediate_stop_ids ?? []),
      request.destination_stop_id,
    ]
    if (new Set(stopIds).size !== stopIds.length) {
      return errorResponse(422, 'VALIDATION_ERROR', 'A route cannot visit the same stop twice.')
    }
    for (const id of stopIds) {
      const stop = index().stops.get(id)
      if (!stop || !stop.is_active) return notFound('Stop not found.')
    }
    if (db.routes.some((route) => route.name.toLowerCase() === request.name.toLowerCase())) {
      return conflict('ROUTE_NAME_TAKEN', 'Another route already has this name.')
    }
    const first = index().stops.get(stopIds[0]!)!
    const points = stopIds.map((id) => index().stops.get(id)!)
    const measured = offsets(points)
    const straight = measured[measured.length - 1] ?? 0
    const distance = request.distance_km
      ? Number(request.distance_km)
      : Math.round(straight * 1.3 * 10) / 10
    const route: RouteRec = {
      id: ids.uuid(),
      name: request.name,
      stop_ids: stopIds,
      offsets_km: [],
      distance_km: distance,
      minutes: request.estimated_duration_minutes ?? Math.max(15, Math.round(distance * 2.4)),
      fare: Math.max(5, Math.round(distance * 0.6)),
      vehicle_type: 'minibus',
      seats: 15,
      city: first.city === 'Kumasi' ? 'Kumasi' : 'Accra',
      is_active: true,
      created_at: new Date().toISOString(),
    }
    measure(route)
    db.routes.push(route)
    touch()
    return created(routeResponse(route))
  }),

  endpoint.patch('/admin/routes/:routeId', ['routes:manage'], ({ params, body }) => {
    const route = index().routes.get(params.routeId!)
    if (!route) return notFound('Route not found.')
    const changes = body as Schemas['RouteUpdateRequest']
    if (
      changes.name &&
      getDb().routes.some(
        (other) =>
          other.id !== route.id && other.name.toLowerCase() === changes.name!.toLowerCase(),
      )
    ) {
      return conflict('ROUTE_NAME_TAKEN', 'Another route already has this name.')
    }
    if (changes.name) route.name = changes.name
    if (changes.estimated_duration_minutes) route.minutes = changes.estimated_duration_minutes
    if (changes.distance_km) {
      route.distance_km = Number(changes.distance_km)
      measure(route)
    }
    touch()
    return routeResponse(route)
  }),

  endpoint.delete('/admin/routes/:routeId', ['routes:manage'], ({ params }) => {
    const db = getDb()
    const route = index().routes.get(params.routeId!)
    if (!route) return notFound('Route not found.')
    const unfinished = db.trips.filter(
      (trip) => trip.route_id === route.id && UNFINISHED.has(trip.status),
    ).length
    if (unfinished) {
      return conflict(
        'ROUTE_HAS_ACTIVE_TRIPS',
        'This route still has trips scheduled or under way. Cancel or finish them first.',
        { unfinished_trips: unfinished },
      )
    }
    route.is_active = false
    for (const schedule of db.schedules)
      if (schedule.route_id === route.id) schedule.is_active = false
    touch()
  }),

  // ----------------------------------------------------------- timetables
  endpoint.get(
    '/admin/routes/:routeId/schedules',
    ['routes:manage', 'trips:manage'],
    ({ params }) => {
      const route = index().routes.get(params.routeId!)
      if (!route) return notFound('Route not found.')
      return getDb()
        .schedules.filter((schedule) => schedule.route_id === route.id && schedule.is_active)
        .sort((a, b) => a.departure_time.localeCompare(b.departure_time))
        .map((schedule): Schemas['RouteScheduleResponse'] => ({
          id: schedule.id,
          route_id: schedule.route_id,
          departure_time: schedule.departure_time,
          days_of_week: schedule.days_of_week,
          fare_amount: money(schedule.fare_amount),
          is_active: schedule.is_active,
        }))
    },
  ),

  endpoint.post('/admin/routes/:routeId/schedules', ['routes:manage'], ({ params, body }) => {
    const route = index().routes.get(params.routeId!)
    if (!route || !route.is_active) return notFound('Route not found.')
    const request = body as Schemas['RouteScheduleCreateRequest']
    const time =
      request.departure_time.length === 5 ? `${request.departure_time}:00` : request.departure_time
    const schedule = {
      id: ids.uuid(),
      route_id: route.id,
      departure_time: time,
      days_of_week: request.days_of_week,
      fare_amount: Number(request.fare_amount),
      is_active: true,
    }
    getDb().schedules.push(schedule)
    touch()
    return created({
      ...schedule,
      fare_amount: money(schedule.fare_amount),
    } satisfies Schemas['RouteScheduleResponse'])
  }),
]
