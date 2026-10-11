import { keepPreviousData, useMutation, useQuery, useQueryClient } from '@tanstack/react-query'

import { api, unwrap } from '@/api/client'
import type { Schemas } from '@/api/types'
import { useLiveInterval } from '@/app/live/live-context'

export interface TripFilters {
  status: string
  date: string
  route: string
  driver: string
}

export const tripKeys = {
  all: ['trips'] as const,
  list: (filters: TripFilters, page: number) => ['trips', 'list', filters, page] as const,
  summary: (id: string) => ['trips', 'summary', id] as const,
  track: (id: string) => ['trips', 'track', id] as const,
}

export function useTrips(filters: TripFilters, page: number, limit: number) {
  return useQuery({
    queryKey: tripKeys.list(filters, page),
    queryFn: () =>
      unwrap(
        api.GET('/api/v1/admin/trips', {
          params: {
            query: {
              status: filters.status || undefined,
              date: filters.date || undefined,
              route_id: filters.route || undefined,
              driver_id: filters.driver || undefined,
              limit,
              offset: (page - 1) * limit,
            },
          },
        }),
      ),
    placeholderData: keepPreviousData,
  })
}

/**
 * The admin's view of one trip (driver's answer, seats booked): the trips
 * list for its day and route, which has it.
 */
export function useTripSummary(trip: Schemas['TripDetailResponse'] | undefined) {
  return useQuery({
    queryKey: tripKeys.summary(trip?.id ?? ''),
    queryFn: async () => {
      const page = await unwrap(
        api.GET('/api/v1/admin/trips', {
          params: {
            query: {
              date: trip!.scheduled_departure_at.slice(0, 10),
              route_id: trip!.route_id,
              limit: 100,
              offset: 0,
            },
          },
        }),
      )
      return page.items.find((item) => item.trip_id === trip!.id) ?? null
    },
    enabled: Boolean(trip),
  })
}

/** Where the bus went (its GPS points), refreshed while it is on the road. */
export function useTripTrack(id: string | null, live: boolean) {
  const interval = useLiveInterval()
  return useQuery({
    queryKey: tripKeys.track(id ?? ''),
    queryFn: () =>
      unwrap(
        api.GET('/api/v1/admin/trips/{trip_id}/track', { params: { path: { trip_id: id! } } }),
      ),
    enabled: Boolean(id),
    refetchInterval: live && interval ? Math.max(interval, 30_000) : false,
  })
}

function useTripMutation<V, R>(run: (variables: V) => Promise<R>) {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: run,
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: tripKeys.all })
      void queryClient.invalidateQueries({ queryKey: ['trip'] })
      void queryClient.invalidateQueries({ queryKey: ['live-trips'] })
      void queryClient.invalidateQueries({ queryKey: ['dispatch'] })
      void queryClient.invalidateQueries({ queryKey: ['notifications'] })
    },
  })
}

export function useCreateTrip() {
  return useTripMutation((body: Schemas['TripCreateRequest']) =>
    unwrap(api.POST('/api/v1/admin/trips', { body })),
  )
}

export function useCreateTripFromSchedule() {
  return useTripMutation((body: Schemas['ScheduleTripRequest']) =>
    unwrap(api.POST('/api/v1/admin/trips/from-schedule', { body })),
  )
}

export function useAssignDriver(tripId: string) {
  return useTripMutation((driverId: string) =>
    unwrap(
      api.POST('/api/v1/admin/trips/{trip_id}/assign-driver', {
        params: { path: { trip_id: tripId } },
        body: { driver_id: driverId },
      }),
    ),
  )
}

export function useAssignVehicle(tripId: string) {
  return useTripMutation((vehicleId: string) =>
    unwrap(
      api.POST('/api/v1/admin/trips/{trip_id}/assign-vehicle', {
        params: { path: { trip_id: tripId } },
        body: { vehicle_id: vehicleId },
      }),
    ),
  )
}

export function useCancelTrip(tripId: string) {
  return useTripMutation((reason: string) =>
    unwrap(
      api.POST('/api/v1/admin/trips/{trip_id}/cancel', {
        params: { path: { trip_id: tripId } },
        body: { reason: reason || null },
      }),
    ),
  )
}

/** Answer a trip for its driver (dispatch): accept, or decline with a reason. */
export function useAnswerForDriver(tripId: string) {
  return useTripMutation(({ accept, reason }: { accept: boolean; reason?: string }) =>
    accept
      ? unwrap(
          api.POST('/api/v1/admin/trips/{trip_id}/accept-for-driver', {
            params: { path: { trip_id: tripId } },
          }),
        )
      : unwrap(
          api.POST('/api/v1/admin/trips/{trip_id}/decline-for-driver', {
            params: { path: { trip_id: tripId } },
            body: { reason: reason ?? '' },
          }),
        ),
  )
}
