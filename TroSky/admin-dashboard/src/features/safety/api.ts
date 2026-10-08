import { keepPreviousData, useMutation, useQuery, useQueryClient } from '@tanstack/react-query'

import { api, unwrap } from '@/api/client'
import type { Schemas } from '@/api/types'
import { useLiveInterval } from '@/app/live/live-context'

export type SosStatus = Schemas['SosAlertStatus']
export type IncidentStatus = Schemas['IncidentStatus']

export const safetyKeys = {
  sos: ['sos'] as const,
  sosList: (status: string, page: number) => ['sos', 'list', status, page] as const,
  sosActive: ['sos', 'active'] as const,
  sosDetail: (id: string) => ['sos', 'detail', id] as const,
  incidents: (status: string, page: number) => ['incidents', status, page] as const,
}

/** The SOS queue: unacknowledged and acknowledged first, all refreshed live. */
export function useSosAlerts(status: SosStatus | 'open' | 'all', page: number, limit = 20) {
  const interval = useLiveInterval()
  return useQuery({
    queryKey: safetyKeys.sosList(status, page),
    queryFn: async () => {
      if (status === 'open') {
        // "Open" is two statuses; the API filters by one at a time.
        const [active, acknowledged] = await Promise.all(
          (['active', 'acknowledged'] as const).map((alert_status) =>
            unwrap(
              api.GET('/api/v1/admin/sos-alerts', {
                params: { query: { alert_status, limit: 100, offset: 0 } },
              }),
            ),
          ),
        )
        const items = [...active!.items, ...acknowledged!.items]
        return { items, total: items.length, limit: 100, offset: 0 }
      }
      return unwrap(
        api.GET('/api/v1/admin/sos-alerts', {
          params: {
            query: {
              alert_status: status === 'all' ? undefined : status,
              limit,
              offset: (page - 1) * limit,
            },
          },
        }),
      )
    },
    refetchInterval: interval,
    placeholderData: keepPreviousData,
  })
}

/** Unacknowledged SOS alerts, for the banner on every page. */
export function useActiveSos(enabled: boolean) {
  const interval = useLiveInterval()
  return useQuery({
    queryKey: safetyKeys.sosActive,
    queryFn: () =>
      unwrap(
        api.GET('/api/v1/admin/sos-alerts', {
          params: { query: { alert_status: 'active', limit: 20, offset: 0 } },
        }),
      ),
    enabled,
    refetchInterval: interval,
  })
}

export function useSosDetail(id: string | null) {
  const interval = useLiveInterval()
  return useQuery({
    queryKey: safetyKeys.sosDetail(id ?? ''),
    queryFn: () =>
      unwrap(
        api.GET('/api/v1/admin/sos-alerts/{alert_id}', { params: { path: { alert_id: id! } } }),
      ),
    enabled: Boolean(id),
    refetchInterval: interval,
  })
}

function useSafetyMutation<V, R>(run: (variables: V) => Promise<R>) {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: run,
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: safetyKeys.sos })
      void queryClient.invalidateQueries({ queryKey: ['incidents'] })
      void queryClient.invalidateQueries({ queryKey: ['alerts'] })
      void queryClient.invalidateQueries({ queryKey: ['notifications'] })
      void queryClient.invalidateQueries({ queryKey: ['overview'] })
    },
  })
}

export function useAcknowledgeSos() {
  return useSafetyMutation((id: string) =>
    unwrap(
      api.POST('/api/v1/admin/sos-alerts/{alert_id}/acknowledge', {
        params: { path: { alert_id: id } },
      }),
    ),
  )
}

export function useResolveSos() {
  return useSafetyMutation(
    ({ id, notes, falseAlarm }: { id: string; notes: string; falseAlarm: boolean }) =>
      unwrap(
        api.POST('/api/v1/admin/sos-alerts/{alert_id}/resolve', {
          params: { path: { alert_id: id } },
          body: { notes, false_alarm: falseAlarm },
        }),
      ),
  )
}

export function useLogEscalation() {
  return useSafetyMutation(({ id, ...body }: { id: string } & Schemas['SosEscalationRequest']) =>
    unwrap(
      api.POST('/api/v1/admin/sos-alerts/{alert_id}/escalations', {
        params: { path: { alert_id: id } },
        body,
      }),
    ),
  )
}

export function useIncidents(status: IncidentStatus | 'all', page: number, limit = 20) {
  return useQuery({
    queryKey: safetyKeys.incidents(status, page),
    queryFn: () =>
      unwrap(
        api.GET('/api/v1/admin/incidents', {
          params: {
            query: {
              incident_status: status === 'all' ? undefined : status,
              limit,
              offset: (page - 1) * limit,
            },
          },
        }),
      ),
    placeholderData: keepPreviousData,
  })
}

export function useResolveIncident() {
  return useSafetyMutation(({ id, notes }: { id: string; notes: string }) =>
    unwrap(
      api.POST('/api/v1/admin/incidents/{incident_id}/resolve', {
        params: { path: { incident_id: id } },
        body: { notes: notes || null },
      }),
    ),
  )
}
