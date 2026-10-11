import { keepPreviousData, useQuery } from '@tanstack/react-query'

import { api, unwrap } from '@/api/client'
import type { Schemas } from '@/api/types'

export type AdminPayment = Schemas['AdminPaymentResponse']

export interface PaymentFilters {
  method: string
  status: string
  purpose: string
  sort: string
}

export function useRevenue(from: string, to: string, city: string) {
  return useQuery({
    queryKey: ['revenue', from, to, city],
    queryFn: () =>
      unwrap(
        api.GET('/api/v1/admin/analytics/revenue', {
          params: { query: { from, to, city: city || undefined } },
        }),
      ),
    placeholderData: keepPreviousData,
  })
}

/** Payments in the period: a reference or phone in ``q`` (kept out of the URL). */
export function usePayments(
  period: { from: string; to: string; city: string },
  filters: PaymentFilters,
  q: string,
  page: number,
  limit = 20,
) {
  return useQuery({
    queryKey: ['revenue', 'payments', period, filters, q, page, limit],
    queryFn: () =>
      unwrap(
        api.GET('/api/v1/admin/payments', {
          params: {
            query: {
              from: period.from,
              to: period.to,
              city: period.city || undefined,
              method: filters.method || undefined,
              status: filters.status || undefined,
              purpose: filters.purpose || undefined,
              q: q.trim() || undefined,
              sort: filters.sort || undefined,
              limit,
              offset: (page - 1) * limit,
            },
          },
        }),
      ),
    placeholderData: keepPreviousData,
  })
}
