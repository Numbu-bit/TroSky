import { keepPreviousData, useMutation, useQuery, useQueryClient } from '@tanstack/react-query'

import { api, unwrap } from '@/api/client'
import type { Schemas } from '@/api/types'
import { useLiveInterval } from '@/app/live/live-context'

export type ActionKind = Schemas['DriverActionKind']
export type ActedAs = Schemas['ActedAs']

export interface ActionFilters {
  driver: string
  trip: string
  kind: string
  actedAs: string
  since: string
  until: string
}

export const dispatchKeys = {
  all: ['dispatch'] as const,
  requests: (tripId: string, driverId: string) =>
    ['dispatch', 'requests', tripId, driverId] as const,
  actions: (filters: Partial<ActionFilters>, page: number) =>
    ['dispatch', 'actions', filters, page] as const,
}

/** Bookings waiting for a driver's answer, soonest deadline first, kept live. */
export function useBookingRequests({ tripId = '', driverId = '' } = {}) {
  const interval = useLiveInterval()
  return useQuery({
    queryKey: dispatchKeys.requests(tripId, driverId),
    queryFn: () =>
      unwrap(
        api.GET('/api/v1/admin/booking-requests', {
          params: {
            query: {
              trip_id: tripId || undefined,
              driver_id: driverId || undefined,
              limit: 100,
              offset: 0,
            },
          },
        }),
      ),
    refetchInterval: interval ? Math.min(interval, 10_000) : false,
  })
}

export function useDriverActions(
  filters: Partial<ActionFilters>,
  page: number,
  limit = 50,
  enabled = true,
) {
  return useQuery({
    queryKey: dispatchKeys.actions(filters, page),
    queryFn: () =>
      unwrap(
        api.GET('/api/v1/admin/driver-actions', {
          params: {
            query: {
              driver_id: filters.driver || undefined,
              trip_id: filters.trip || undefined,
              kind: filters.kind || undefined,
              acted_as: (filters.actedAs || undefined) as ActedAs | undefined,
              since: filters.since ? `${filters.since}T00:00:00Z` : undefined,
              until: filters.until ? `${filters.until}T23:59:59Z` : undefined,
              limit,
              offset: (page - 1) * limit,
            },
          },
        }),
      ),
    placeholderData: keepPreviousData,
    enabled,
  })
}

function useDispatchMutation<V, R>(run: (variables: V) => Promise<R>) {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: run,
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: dispatchKeys.all })
      void queryClient.invalidateQueries({ queryKey: ['trips'] })
      void queryClient.invalidateQueries({ queryKey: ['bookings'] })
    },
  })
}

export function useAcceptBooking() {
  return useDispatchMutation((bookingId: string) =>
    unwrap(
      api.POST('/api/v1/admin/bookings/{booking_id}/accept', {
        params: { path: { booking_id: bookingId } },
      }),
    ),
  )
}

export function useDeclineBooking() {
  return useDispatchMutation(
    ({ bookingId, ...body }: { bookingId: string } & Schemas['AdminDeclineBookingRequest']) =>
      unwrap(
        api.POST('/api/v1/admin/bookings/{booking_id}/decline', {
          params: { path: { booking_id: bookingId } },
          body,
        }),
      ),
  )
}

export function useMoveBooking() {
  return useDispatchMutation(({ bookingId, tripId }: { bookingId: string; tripId: string }) =>
    unwrap(
      api.POST('/api/v1/admin/bookings/{booking_id}/move', {
        params: { path: { booking_id: bookingId } },
        body: { trip_id: tripId },
      }),
    ),
  )
}

export function useMarkOff() {
  return useDispatchMutation(({ tripId, passengerId }: { tripId: string; passengerId: string }) =>
    unwrap(
      api.POST('/api/v1/admin/trips/{trip_id}/passengers/{booking_passenger_id}/alight', {
        params: { path: { trip_id: tripId, booking_passenger_id: passengerId } },
        body: {},
      }),
    ),
  )
}
