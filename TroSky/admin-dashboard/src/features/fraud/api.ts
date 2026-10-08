import { keepPreviousData, useMutation, useQuery, useQueryClient } from '@tanstack/react-query'

import { api, unwrap } from '@/api/client'
import type { Schemas } from '@/api/types'
import { useSession } from '@/app/auth/auth-context'
import { isModuleEnabled } from '@/lib/modules'

export type Flag = Schemas['FraudFlagResponse']
export type FlagDetail = Schemas['FraudFlagDetailResponse']
export type FlagStatus = Schemas['FraudFlagStatus']
export type Severity = Schemas['FraudSeverity']
export type FraudAction = Schemas['FraudActionRequest']['action']

export interface FlagFilters {
  status: string
  severity: string
  rule: string
  risk: string
  assigned: string
  sort: string
}

export const fraudKeys = {
  all: ['fraud'] as const,
  flags: (filters: FlagFilters, page: number) => ['fraud', 'flags', filters, page] as const,
  flag: (id: string) => ['fraud', 'flag', id] as const,
  stats: (from: string, to: string) => ['fraud', 'stats', from, to] as const,
  rules: ['fraud', 'rules'] as const,
  team: ['fraud', 'team'] as const,
}

export function useFlags(filters: FlagFilters, page: number, me: string, limit = 20) {
  return useQuery({
    queryKey: fraudKeys.flags(filters, page),
    queryFn: () =>
      unwrap(
        api.GET('/api/v1/admin/fraud/flags', {
          params: {
            query: {
              status: filters.status || undefined,
              severity: filters.severity || undefined,
              rule: filters.rule || undefined,
              min_risk: filters.risk ? Number(filters.risk) : undefined,
              assigned_to: filters.assigned === 'me' ? me : undefined,
              unassigned: filters.assigned === 'none' ? true : undefined,
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

export function useFlag(id: string) {
  return useQuery({
    queryKey: fraudKeys.flag(id),
    queryFn: () =>
      unwrap(api.GET('/api/v1/admin/fraud/flags/{flag_id}', { params: { path: { flag_id: id } } })),
  })
}

export function useFraudStats(from: string, to: string) {
  return useQuery({
    queryKey: fraudKeys.stats(from, to),
    queryFn: () =>
      unwrap(api.GET('/api/v1/admin/fraud/stats', { params: { query: { from, to } } })),
    placeholderData: keepPreviousData,
  })
}

export function useRules(enabled: boolean) {
  return useQuery({
    queryKey: fraudKeys.rules,
    queryFn: () => unwrap(api.GET('/api/v1/admin/fraud/rules')),
    enabled,
  })
}

/** Who a flag can be given to: the team members who review fraud (admins:manage). */
export function useFraudTeam() {
  const { can } = useSession()
  return useQuery({
    queryKey: fraudKeys.team,
    queryFn: () => unwrap(api.GET('/api/v1/admin/admins')),
    enabled: can('admins:manage') && isModuleEnabled('team'),
    select: (team) =>
      team.filter(
        (member) =>
          member.is_active &&
          !member.is_suspended &&
          (member.role === 'super_admin' ||
            member.permissions.some((permission) => permission.startsWith('fraud:'))),
      ),
    staleTime: 5 * 60_000,
  })
}

function useFraudMutation<V, R>(run: (variables: V) => Promise<R>) {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: run,
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: fraudKeys.all })
      void queryClient.invalidateQueries({ queryKey: ['alerts'] })
      void queryClient.invalidateQueries({ queryKey: ['accounts'] })
    },
  })
}

/** Assign (null unassigns) or set the status; confirming or clearing needs a reason. */
export function useUpdateFlag(id: string) {
  return useFraudMutation((body: Schemas['FraudFlagUpdateRequest']) =>
    unwrap(
      api.PATCH('/api/v1/admin/fraud/flags/{flag_id}', { params: { path: { flag_id: id } }, body }),
    ),
  )
}

/** Suspend the account, freeze or unfreeze its wallet, block or unblock the device. */
export function useFlagAction(id: string) {
  return useFraudMutation((body: Schemas['FraudActionRequest']) =>
    unwrap(
      api.POST('/api/v1/admin/fraud/flags/{flag_id}/actions', {
        params: { path: { flag_id: id } },
        body,
      }),
    ),
  )
}

export function useUpdateRule() {
  return useFraudMutation(({ key, ...body }: { key: string } & Schemas['FraudRuleUpdateRequest']) =>
    unwrap(
      api.PATCH('/api/v1/admin/fraud/rules/{rule}', { params: { path: { rule: key } }, body }),
    ),
  )
}

export function useScan() {
  return useFraudMutation(() => unwrap(api.POST('/api/v1/admin/fraud/scan')))
}
