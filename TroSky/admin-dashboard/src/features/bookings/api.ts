import {
  keepPreviousData,
  useMutation,
  useQueries,
  useQuery,
  useQueryClient,
} from '@tanstack/react-query'

import { api, unwrap } from '@/api/client'
import type { Schemas } from '@/api/types'
import { useSession } from '@/app/auth/auth-context'
import { accraDateKey } from '@/lib/format'

export type BookingStatus = Schemas['BookingStatus']
export type RefundStatus = Schemas['RefundStatus']
export type CancellationStatus = Schemas['CancellationStatus']

export const bookingKeys = {
  all: ['bookings'] as const,
  list: (status: string, page: number) => ['bookings', 'list', status, page] as const,
  detail: (id: string) => ['bookings', 'detail', id] as const,
  tickets: (id: string) => ['bookings', 'tickets', id] as const,
  payments: (reference: string) => ['bookings', 'payments', reference] as const,
  refunds: (status: string, page: number) => ['bookings', 'refunds', status, page] as const,
  cancellations: (status: string, page: number) =>
    ['bookings', 'cancellations', status, page] as const,
}

/** Every booking, newest first; the API filters by one status. */
export function useBookings(status: BookingStatus | '', page: number, limit: number) {
  return useQuery({
    queryKey: bookingKeys.list(status, page),
    queryFn: () =>
      unwrap(
        api.GET('/api/v1/admin/bookings', {
          params: {
            query: {
              booking_status: status || undefined,
              limit,
              offset: (page - 1) * limit,
            },
          },
        }),
      ),
    placeholderData: keepPreviousData,
  })
}

/** Anyone's booking (bookings:view_any). */
export function useBooking(id: string | null) {
  return useQuery({
    queryKey: bookingKeys.detail(id ?? ''),
    queryFn: () =>
      unwrap(api.GET('/api/v1/bookings/{booking_id}', { params: { path: { booking_id: id! } } })),
    enabled: Boolean(id),
  })
}

export function useBookingTickets(id: string | null, enabled: boolean) {
  return useQuery({
    queryKey: bookingKeys.tickets(id ?? ''),
    queryFn: () =>
      unwrap(
        api.GET('/api/v1/bookings/{booking_id}/tickets', {
          params: { path: { booking_id: id! } },
        }),
      ),
    enabled: Boolean(id) && enabled,
  })
}

/**
 * The payments made for a booking, found by its reference. The payments
 * list looks at 30 days by default: search from the day it was booked.
 */
export function useBookingPayments(booking: Schemas['BookingResponse'] | undefined) {
  const { can } = useSession()
  return useQuery({
    queryKey: bookingKeys.payments(booking?.booking_reference ?? ''),
    queryFn: () =>
      unwrap(
        api.GET('/api/v1/admin/payments', {
          params: {
            query: {
              q: booking!.booking_reference,
              from: accraDateKey(booking!.created_at),
              to: accraDateKey(),
              limit: 20,
              offset: 0,
            },
          },
        }),
      ),
    enabled: Boolean(booking) && can('payments:review', 'refunds:approve', 'reports:view'),
  })
}

function useBookingMutation<V, R>(run: (variables: V) => Promise<R>) {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: run,
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: bookingKeys.all })
      void queryClient.invalidateQueries({ queryKey: ['notifications'] })
      void queryClient.invalidateQueries({ queryKey: ['trips'] })
      void queryClient.invalidateQueries({ queryKey: ['dispatch'] })
    },
  })
}

/** Cancel anyone's booking: at once before the trip starts, else for review. */
export function useCancelBooking() {
  return useBookingMutation(({ id, reason }: { id: string; reason: string }) =>
    unwrap(
      api.POST('/api/v1/bookings/{booking_id}/cancel', {
        params: { path: { booking_id: id } },
        body: { reason: reason || null },
      }),
    ),
  )
}

export function useRefunds(status: RefundStatus | '', page: number, limit: number) {
  return useQuery({
    queryKey: bookingKeys.refunds(status, page),
    queryFn: () =>
      unwrap(
        api.GET('/api/v1/admin/refund-requests', {
          params: {
            query: { refund_status: status || undefined, limit, offset: (page - 1) * limit },
          },
        }),
      ),
    placeholderData: keepPreviousData,
  })
}

/** Approve (pays the money back at once) or reject a refund request. */
export function useDecideRefund() {
  return useBookingMutation(
    ({ id, approve, notes }: { id: string; approve: boolean; notes: string }) => {
      const options = { params: { path: { refund_id: id } }, body: { notes: notes || null } }
      return unwrap(
        approve
          ? api.POST('/api/v1/admin/refund-requests/{refund_id}/approve', options)
          : api.POST('/api/v1/admin/refund-requests/{refund_id}/reject', options),
      )
    },
  )
}

export function useCancellations(status: CancellationStatus | '', page: number, limit: number) {
  return useQuery({
    queryKey: bookingKeys.cancellations(status, page),
    queryFn: () =>
      unwrap(
        api.GET('/api/v1/admin/cancellation-requests', {
          params: {
            query: { request_status: status || undefined, limit, offset: (page - 1) * limit },
          },
        }),
      ),
    placeholderData: keepPreviousData,
  })
}

export function useReviewCancellation() {
  return useBookingMutation(
    ({ id, ...body }: { id: string } & Schemas['CancellationReviewRequest']) =>
      unwrap(
        api.POST('/api/v1/admin/cancellation-requests/{request_id}/review', {
          params: { path: { request_id: id } },
          body,
        }),
      ),
  )
}

/**
 * Who a refund goes to and how it was paid, for its confirmation: the
 * booking (bookings:view_any) and its payment, found by the booking's
 * reference.
 */
export function useRefundContext(refund: Schemas['RefundRequestResponse'] | null) {
  const { can } = useSession()
  const booking = useBooking(
    refund?.booking_id && can('bookings:view_any') ? refund.booking_id : null,
  )
  const payments = useBookingPayments(booking.data)
  return {
    booking: booking.data,
    payment: payments.data?.items.find((item) => item.id === refund?.payment_id),
    loading: booking.isLoading || payments.isLoading,
  }
}

/** The bookings behind a page of queue rows, for their references and passengers. */
export function useBookingsById(ids: (string | null)[]) {
  const { can } = useSession()
  const wanted = can('bookings:view_any') ? [...new Set(ids.filter(Boolean) as string[])] : []
  const results = useQueries({
    queries: wanted.map((id) => ({
      queryKey: bookingKeys.detail(id),
      queryFn: () =>
        unwrap(api.GET('/api/v1/bookings/{booking_id}', { params: { path: { booking_id: id } } })),
    })),
  })
  return new Map(
    results.flatMap((result) => (result.data ? [[result.data.id, result.data] as const] : [])),
  )
}
