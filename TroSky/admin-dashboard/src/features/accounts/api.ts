import { keepPreviousData, useMutation, useQuery, useQueryClient } from '@tanstack/react-query'

import { api, unwrap } from '@/api/client'
import type { Schemas } from '@/api/types'

export type Account = Schemas['AdminUserResponse']
export type AccountDetail = Schemas['AdminUserDetailResponse']

export interface AccountFilters {
  role: string
  status: string
  sort: string
}

export const accountKeys = {
  all: ['accounts'] as const,
  search: (search: string, filters: AccountFilters, page: number, limit: number) =>
    ['accounts', 'search', search, filters, page, limit] as const,
  detail: (id: string) => ['accounts', 'detail', id] as const,
  sessions: (id: string) => ['accounts', 'sessions', id] as const,
}

/**
 * Users by name, phone or email (the text stays out of the URL: it can be
 * personal data), or every user when there is none.
 */
export function useAccounts(
  search: string,
  filters: AccountFilters,
  page: number,
  limit: number,
  enabled = true,
) {
  const text = search.trim()
  return useQuery({
    queryKey: accountKeys.search(text, filters, page, limit),
    queryFn: () =>
      unwrap(
        api.GET('/api/v1/admin/users', {
          params: {
            query: {
              search: text || undefined,
              role: filters.role || undefined,
              status: (filters.status || undefined) as
                'active' | 'suspended' | 'inactive' | undefined,
              sort: filters.sort || undefined,
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

export function useAccount(id: string | null) {
  return useQuery({
    queryKey: accountKeys.detail(id ?? ''),
    queryFn: () =>
      unwrap(api.GET('/api/v1/admin/users/{user_id}', { params: { path: { user_id: id! } } })),
    enabled: Boolean(id),
  })
}

export function useAccountSessions(id: string, enabled: boolean) {
  return useQuery({
    queryKey: accountKeys.sessions(id),
    queryFn: () =>
      unwrap(
        api.GET('/api/v1/admin/users/{user_id}/sessions', { params: { path: { user_id: id } } }),
      ),
    enabled,
  })
}

function useAccountMutation<V, R>(run: (variables: V) => Promise<R>) {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: run,
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: accountKeys.all })
    },
  })
}

/** Suspend (signs them out everywhere at once) or reactivate an account. */
export function useSuspension(id: string) {
  return useAccountMutation(({ suspend, reason }: { suspend: boolean; reason: string }) =>
    suspend
      ? unwrap(
          api.POST('/api/v1/admin/users/{user_id}/suspend', {
            params: { path: { user_id: id } },
            body: { reason },
          }),
        )
      : unwrap(
          api.POST('/api/v1/admin/users/{user_id}/reactivate', {
            params: { path: { user_id: id } },
          }),
        ),
  )
}

export function useEndSession(userId: string) {
  return useAccountMutation((sessionId: string) =>
    unwrap(
      api.DELETE('/api/v1/admin/users/{user_id}/sessions/{session_id}', {
        params: { path: { user_id: userId, session_id: sessionId } },
      }),
    ),
  )
}
