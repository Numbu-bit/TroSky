import { useQuery } from '@tanstack/react-query'

import { api, unwrap } from '@/api/client'
import { isApiError } from '@/api/errors'
import { useLiveInterval } from '@/app/live/live-context'

export const liveKeys = {
  trips: ['live-trips'] as const,
  location: (id: string) => ['live-trips', 'location', id] as const,
  eta: (id: string) => ['live-trips', 'eta', id] as const,
  trip: (id: string) => ['trip', id] as const,
  track: (id: string) => ['live-trips', 'track', id] as const,
}

/** Every bus on the road with its last position, refreshed live. */
export function useLiveTrips(enabled = true) {
  const interval = useLiveInterval()
  return useQuery({
    queryKey: liveKeys.trips,
    queryFn: () => unwrap(api.GET('/api/v1/admin/live-trips')),
    refetchInterval: interval,
    enabled,
  })
}

export function useTrip(id: string | null) {
  return useQuery({
    queryKey: liveKeys.trip(id ?? ''),
    queryFn: () =>
      unwrap(api.GET('/api/v1/trips/{trip_id}', { params: { path: { trip_id: id! } } })),
    enabled: Boolean(id),
  })
}

/** Where the bus is now; null until its phone has reported. */
export function useTripLocation(id: string | null) {
  const interval = useLiveInterval()
  return useQuery({
    queryKey: liveKeys.location(id ?? ''),
    queryFn: async () => {
      try {
        return await unwrap(
          api.GET('/api/v1/trips/{trip_id}/location', { params: { path: { trip_id: id! } } }),
        )
      } catch (error) {
        if (isApiError(error, 404)) return null
        throw error
      }
    },
    enabled: Boolean(id),
    refetchInterval: interval,
  })
}

export function useTripEta(id: string | null, enabled: boolean) {
  const interval = useLiveInterval()
  return useQuery({
    queryKey: liveKeys.eta(id ?? ''),
    queryFn: async () => {
      try {
        return await unwrap(
          api.GET('/api/v1/trips/{trip_id}/eta', { params: { path: { trip_id: id! } } }),
        )
      } catch (error) {
        if (isApiError(error, 409) || isApiError(error, 404)) return null
        throw error
      }
    },
    enabled: Boolean(id) && enabled,
    refetchInterval: interval ? Math.max(interval, 30_000) : false,
  })
}
