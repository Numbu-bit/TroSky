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

export type PayoutStatus = Schemas['WithdrawalStatus']
export type Payout = Schemas['WithdrawalResponse']

export const payoutKeys = {
  all: ['payouts'] as const,
  list: (status: string, page: number) => ['payouts', 'list', status, page] as const,
  detail: (id: string) => ['payouts', 'detail', id] as const,
}

export function usePayouts(status: PayoutStatus | '', page: number, limit: number) {
  return useQuery({
    queryKey: payoutKeys.list(status, page),
    queryFn: () =>
      unwrap(
        api.GET('/api/v1/admin/withdrawals', {
          params: {
            query: { withdrawal_status: status || undefined, limit, offset: (page - 1) * limit },
          },
        }),
      ),
    placeholderData: keepPreviousData,
  })
}

/** Anyone's payout (withdrawals:review), for the drawer. */
export function usePayout(id: string | null) {
  return useQuery({
    queryKey: payoutKeys.detail(id ?? ''),
    queryFn: () =>
      unwrap(
        api.GET('/api/v1/wallet/withdrawals/{withdrawal_id}', {
          params: { path: { withdrawal_id: id! } },
        }),
      ),
    enabled: Boolean(id),
  })
}

/** Who asked for each payout, for admins who may look accounts up. */
export function usePayoutOwners(userIds: string[]) {
  const { can } = useSession()
  const wanted = can('users:manage', 'users:suspend') ? [...new Set(userIds)] : []
  const results = useQueries({
    queries: wanted.map((id) => ({
      queryKey: ['accounts', 'detail', id],
      queryFn: () =>
        unwrap(api.GET('/api/v1/admin/users/{user_id}', { params: { path: { user_id: id } } })),
      staleTime: 5 * 60_000,
    })),
  })
  return new Map(
    results.flatMap((result) => (result.data ? [[result.data.id, result.data] as const] : [])),
  )
}

export type PayoutAction =
  | { id: string; action: 'approve' | 'reject'; notes: string }
  | { id: string; action: 'complete'; reference: string }
  | { id: string; action: 'fail'; reason: string }

/** Approve (money leaves the wallet), reject, mark sent or mark failed (money goes back). */
export function usePayoutAction() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (variables: PayoutAction) => {
      const params = { path: { withdrawal_id: variables.id } }
      switch (variables.action) {
        case 'approve':
          return unwrap(
            api.POST('/api/v1/admin/withdrawals/{withdrawal_id}/approve', {
              params,
              body: { notes: variables.notes || null },
            }),
          )
        case 'reject':
          return unwrap(
            api.POST('/api/v1/admin/withdrawals/{withdrawal_id}/reject', {
              params,
              body: { notes: variables.notes || null },
            }),
          )
        case 'complete':
          return unwrap(
            api.POST('/api/v1/admin/withdrawals/{withdrawal_id}/complete', {
              params,
              body: { provider_reference: variables.reference || null },
            }),
          )
        case 'fail':
          return unwrap(
            api.POST('/api/v1/admin/withdrawals/{withdrawal_id}/fail', {
              params,
              body: { reason: variables.reason },
            }),
          )
      }
    },
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: payoutKeys.all })
      void queryClient.invalidateQueries({ queryKey: ['notifications'] })
      void queryClient.invalidateQueries({ queryKey: ['accounts'] })
    },
  })
}
