import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'

import { api, unwrap } from '@/api/client'
import type { Schemas } from '@/api/types'

type Stop = Schemas['StopResponse']

export const networkKeys = {
  all: ['network'] as const,
  allStops: ['network', 'all-stops'] as const,
}

/**
 * Every active stop (100 at a time, the API's page cap), for naming the
 * ends of routes. Networks have hundreds of stops, not tens of thousands.
 */
export function useAllStops() {
  return useQuery({
    queryKey: networkKeys.allStops,
    queryFn: async () => {
      const items: Stop[] = []
      for (;;) {
        const page = await unwrap(
          api.GET('/api/v1/stops', { params: { query: { limit: 100, offset: items.length } } }),
        )
        items.push(...page.items)
        if (!page.items.length || items.length >= page.total || items.length >= 5000) break
      }
      return { items, byId: new Map(items.map((stop) => [stop.id, stop])) }
    },
    staleTime: 5 * 60_000,
  })
}

function useNetworkMutation<V, R>(run: (variables: V) => Promise<R>) {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: run,
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: networkKeys.all })
    },
  })
}

export function useCreateStop() {
  return useNetworkMutation((body: Schemas['StopCreateRequest']) =>
    unwrap(api.POST('/api/v1/admin/stops', { body })),
  )
}

export function useUpdateStop() {
  return useNetworkMutation(({ id, ...body }: { id: string } & Schemas['StopUpdateRequest']) =>
    unwrap(api.PATCH('/api/v1/admin/stops/{stop_id}', { params: { path: { stop_id: id } }, body })),
  )
}

export function useRetireStop() {
  return useNetworkMutation((id: string) =>
    unwrap(api.DELETE('/api/v1/admin/stops/{stop_id}', { params: { path: { stop_id: id } } })),
  )
}

export function useCreateRoute() {
  return useNetworkMutation((body: Schemas['RouteCreateRequest']) =>
    unwrap(api.POST('/api/v1/admin/routes', { body })),
  )
}

export function useUpdateRoute(id: string) {
  return useNetworkMutation((body: Schemas['RouteUpdateRequest']) =>
    unwrap(
      api.PATCH('/api/v1/admin/routes/{route_id}', { params: { path: { route_id: id } }, body }),
    ),
  )
}

export function useRetireRoute(id: string) {
  return useNetworkMutation(() =>
    unwrap(api.DELETE('/api/v1/admin/routes/{route_id}', { params: { path: { route_id: id } } })),
  )
}

export function useAddSchedule(routeId: string) {
  return useNetworkMutation((body: Schemas['RouteScheduleCreateRequest']) =>
    unwrap(
      api.POST('/api/v1/admin/routes/{route_id}/schedules', {
        params: { path: { route_id: routeId } },
        body,
      }),
    ),
  )
}
