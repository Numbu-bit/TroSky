import { keepPreviousData, useQueries, useQuery } from '@tanstack/react-query'

import { api, unwrap } from '@/api/client'
import { useSession } from '@/app/auth/auth-context'
import type { Permission } from '@/lib/permissions'

export function useOverview(
  params: { from?: string; to?: string; city?: string },
  enabled: boolean,
) {
  return useQuery({
    queryKey: ['overview', params],
    queryFn: () =>
      unwrap(
        api.GET('/api/v1/admin/reports/overview', {
          params: { query: { from: params.from, to: params.to, city: params.city || undefined } },
        }),
      ),
    enabled,
    placeholderData: keepPreviousData,
  })
}

export function useAlertsFeed(enabled: boolean, limit = 8) {
  return useQuery({
    queryKey: ['alerts', limit],
    queryFn: () => unwrap(api.GET('/api/v1/admin/alerts', { params: { query: { limit } } })),
    enabled,
    refetchInterval: 60_000,
  })
}

/** A queue waiting on an admin: how many, and where to work through it. */
export interface Queue {
  key: string
  label: string
  to: string
  permissions: Permission[]
  urgent?: boolean
  count: () => Promise<number>
}

const one = { limit: 1, offset: 0 }

export const QUEUES: Queue[] = [
  {
    key: 'sos',
    label: 'SOS alerts not yet acknowledged',
    to: '/safety?status=active',
    permissions: ['sos:review'],
    urgent: true,
    count: async () =>
      (
        await unwrap(
          api.GET('/api/v1/admin/sos-alerts', {
            params: { query: { alert_status: 'active', ...one } },
          }),
        )
      ).total,
  },
  {
    key: 'drivers',
    label: 'Drivers waiting for approval',
    to: '/approvals?queue=drivers',
    permissions: ['drivers:approve'],
    count: async () =>
      (await unwrap(api.GET('/api/v1/admin/drivers/pending', { params: { query: one } }))).total,
  },
  {
    key: 'vehicles',
    label: 'Vehicles waiting for approval',
    to: '/approvals?queue=vehicles',
    permissions: ['vehicles:approve'],
    count: async () =>
      (await unwrap(api.GET('/api/v1/admin/vehicles/pending', { params: { query: one } }))).total,
  },
  {
    key: 'refunds',
    label: 'Refunds awaiting a decision',
    to: '/bookings/refunds',
    permissions: ['refunds:approve'],
    count: async () =>
      (
        await unwrap(
          api.GET('/api/v1/admin/refund-requests', {
            params: { query: { refund_status: 'pending', ...one } },
          }),
        )
      ).total,
  },
  {
    key: 'cancellations',
    label: 'Cancellations after departure to decide',
    to: '/bookings/cancellations',
    permissions: ['refunds:approve'],
    count: async () =>
      (
        await unwrap(
          api.GET('/api/v1/admin/cancellation-requests', {
            params: { query: { request_status: 'pending', ...one } },
          }),
        )
      ).total,
  },
  {
    key: 'payouts',
    label: 'Payouts awaiting a decision',
    to: '/payouts?status=pending',
    permissions: ['withdrawals:review'],
    count: async () =>
      (
        await unwrap(
          api.GET('/api/v1/admin/withdrawals', {
            params: { query: { withdrawal_status: 'pending', ...one } },
          }),
        )
      ).total,
  },
  {
    key: 'payouts-to-send',
    label: 'Approved payouts to send',
    to: '/payouts?status=approved',
    permissions: ['withdrawals:review'],
    count: async () =>
      (
        await unwrap(
          api.GET('/api/v1/admin/withdrawals', {
            params: { query: { withdrawal_status: 'approved', ...one } },
          }),
        )
      ).total,
  },
  {
    key: 'complaints',
    label: 'Complaints open or in review',
    to: '/complaints?status=open,in_review',
    permissions: ['complaints:manage'],
    count: async () =>
      (
        await unwrap(
          api.GET('/api/v1/admin/complaints', {
            params: { query: { complaint_status: 'open,in_review', ...one } },
          }),
        )
      ).total,
  },
  {
    key: 'incidents',
    label: 'Incidents reported, not yet resolved',
    to: '/safety/incidents?status=reported',
    permissions: ['incidents:manage'],
    count: async () => {
      const [reported, reviewing] = await Promise.all(
        (['reported', 'in_review'] as const).map((incident_status) =>
          unwrap(
            api.GET('/api/v1/admin/incidents', { params: { query: { incident_status, ...one } } }),
          ),
        ),
      )
      return reported!.total + reviewing!.total
    },
  },
]

/** The queues this admin may work, with their counts. */
export function useQueueCounts(keys?: string[]) {
  const { can } = useSession()
  const queues = QUEUES.filter(
    (queue) => (!keys || keys.includes(queue.key)) && can(...queue.permissions),
  )
  const results = useQueries({
    queries: queues.map((queue) => ({
      queryKey: ['notifications', queue.key],
      queryFn: queue.count,
      refetchInterval: queue.urgent ? 15_000 : 60_000,
    })),
  })
  return queues.map((queue, index) => ({ queue, result: results[index]! }))
}
