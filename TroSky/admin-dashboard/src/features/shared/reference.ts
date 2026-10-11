import { keepPreviousData, useQuery } from '@tanstack/react-query'

import { api, unwrap } from '@/api/client'
import type { Schemas } from '@/api/types'

/**
 * Reference data many screens pick from: routes, stops, timetables, and
 * the drivers and vehicles that may be put on trips.
 */
export const referenceKeys = {
  routes: ['network', 'routes'] as const,
  route: (id: string) => ['network', 'route', id] as const,
  stops: (q: string) => ['network', 'stops', q] as const,
  schedules: (routeId: string) => ['network', 'schedules', routeId] as const,
  drivers: (q: string, status: string) => ['fleet', 'drivers', 'pick', q, status] as const,
  vehicles: (q: string, status: string) => ['fleet', 'vehicles', 'pick', q, status] as const,
}

/** Every active route, A to Z (fetched 100 at a time, the API's page cap). */
export function useRoutes() {
  return useQuery({
    queryKey: referenceKeys.routes,
    queryFn: async () => {
      const items: Schemas['RouteResponse'][] = []
      for (;;) {
        const page = await unwrap(
          api.GET('/api/v1/routes', { params: { query: { limit: 100, offset: items.length } } }),
        )
        items.push(...page.items)
        if (!page.items.length || items.length >= page.total || items.length >= 2000) break
      }
      return { items, total: items.length }
    },
    staleTime: 5 * 60_000,
  })
}

export function useRoute(id: string | null) {
  return useQuery({
    queryKey: referenceKeys.route(id ?? ''),
    queryFn: () =>
      unwrap(api.GET('/api/v1/routes/{route_id}', { params: { path: { route_id: id! } } })),
    enabled: Boolean(id),
  })
}

/**
 * Stops A to Z, or those whose name contains ``q``. The API searches
 * from 2 characters (one is refused), so a single letter lists them all.
 */
export function useStops(q: string, { limit = 50, page = 1 } = {}) {
  const search = q.trim().length >= 2 ? q.trim() : ''
  return useQuery({
    queryKey: [...referenceKeys.stops(search), limit, page],
    queryFn: () =>
      unwrap(
        api.GET('/api/v1/stops', {
          params: {
            query: search ? { q: search, limit } : { limit, offset: (page - 1) * limit },
          },
        }),
      ),
    placeholderData: keepPreviousData,
    staleTime: 60_000,
  })
}

export function useSchedules(routeId: string | null) {
  return useQuery({
    queryKey: referenceKeys.schedules(routeId ?? ''),
    queryFn: () =>
      unwrap(
        api.GET('/api/v1/admin/routes/{route_id}/schedules', {
          params: { path: { route_id: routeId! } },
        }),
      ),
    enabled: Boolean(routeId),
  })
}

/** Approved drivers (the only ones that can go on a trip), by name or phone. */
export function useDriverChoices(q: string, enabled = true, status = 'approved') {
  return useQuery({
    queryKey: referenceKeys.drivers(q, status),
    queryFn: () =>
      unwrap(
        api.GET('/api/v1/admin/drivers', {
          params: { query: { status, q: q || undefined, limit: 20, offset: 0, sort: 'full_name' } },
        }),
      ),
    enabled,
    placeholderData: keepPreviousData,
  })
}

export function useVehicleChoices(q: string, enabled = true, status = 'approved') {
  return useQuery({
    queryKey: referenceKeys.vehicles(q, status),
    queryFn: () =>
      unwrap(
        api.GET('/api/v1/admin/vehicles', {
          params: {
            query: { status, q: q || undefined, limit: 20, offset: 0, sort: 'registration_number' },
          },
        }),
      ),
    enabled,
    placeholderData: keepPreviousData,
  })
}
