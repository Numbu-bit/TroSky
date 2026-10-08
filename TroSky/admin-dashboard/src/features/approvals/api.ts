import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'

import { api, unwrap } from '@/api/client'
import type { Schemas } from '@/api/types'

export type QueueKind = 'drivers' | 'vehicles'
export type DocumentType = Schemas['DocumentType']

export const approvalKeys = {
  all: ['approvals'] as const,
  queue: (kind: QueueKind) => ['approvals', 'queue', kind] as const,
  driver: (id: string) => ['approvals', 'driver', id] as const,
  vehicle: (id: string) => ['approvals', 'vehicle', id] as const,
  document: (id: string) => ['approvals', 'document', id] as const,
}

const QUEUE_LIMIT = 100

/** Pending drivers, oldest application first (the API's order). */
export function usePendingDrivers(enabled = true) {
  return useQuery({
    queryKey: approvalKeys.queue('drivers'),
    queryFn: () =>
      unwrap(
        api.GET('/api/v1/admin/drivers/pending', {
          params: { query: { limit: QUEUE_LIMIT, offset: 0 } },
        }),
      ),
    enabled,
  })
}

/** Pending vehicles, oldest first. */
export function usePendingVehicles(enabled = true) {
  return useQuery({
    queryKey: approvalKeys.queue('vehicles'),
    queryFn: () =>
      unwrap(
        api.GET('/api/v1/admin/vehicles/pending', {
          params: { query: { limit: QUEUE_LIMIT, offset: 0 } },
        }),
      ),
    enabled,
  })
}

export function useDriverDetail(id: string | null) {
  return useQuery({
    queryKey: approvalKeys.driver(id ?? ''),
    queryFn: () =>
      unwrap(
        api.GET('/api/v1/admin/drivers/{driver_id}', { params: { path: { driver_id: id! } } }),
      ),
    enabled: Boolean(id),
  })
}

export function useVehicleDetail(id: string | null) {
  return useQuery({
    queryKey: approvalKeys.vehicle(id ?? ''),
    queryFn: () =>
      unwrap(
        api.GET('/api/v1/admin/vehicles/{vehicle_id}', { params: { path: { vehicle_id: id! } } }),
      ),
    enabled: Boolean(id),
  })
}

/** A short-lived link to look at a document: refreshed before its 5 minutes run out. */
export function useDocumentLink(id: string | null) {
  return useQuery({
    queryKey: approvalKeys.document(id ?? ''),
    queryFn: () =>
      unwrap(
        api.GET('/api/v1/admin/documents/{document_id}', {
          params: { path: { document_id: id! } },
        }),
      ),
    enabled: Boolean(id),
    staleTime: 4 * 60_000,
    refetchInterval: 4 * 60_000,
  })
}

function useApprovalMutation<V, R>(run: (variables: V) => Promise<R>) {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: run,
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: approvalKeys.all })
      void queryClient.invalidateQueries({ queryKey: ['fleet'] })
      void queryClient.invalidateQueries({ queryKey: ['notifications'] })
    },
  })
}

export type Decision =
  | { kind: QueueKind; id: string; approve: true; notes?: string }
  | { kind: QueueKind; id: string; approve: false; reason: string; notes?: string }

/** Approve, or reject with a reason, a driver or a vehicle. */
export function useDecide() {
  return useApprovalMutation(
    (decision: Decision): Promise<{ status: Schemas['ApprovalStatus'] }> => {
      const body: Schemas['ApprovalReviewRequest'] = decision.approve
        ? { notes: decision.notes || null }
        : { rejection_reason: decision.reason, notes: decision.notes || null }
      if (decision.kind === 'drivers') {
        const params = { path: { driver_id: decision.id } }
        return unwrap(
          decision.approve
            ? api.POST('/api/v1/admin/drivers/{driver_id}/approve', { params, body })
            : api.POST('/api/v1/admin/drivers/{driver_id}/reject', { params, body }),
        )
      }
      const params = { path: { vehicle_id: decision.id } }
      return unwrap(
        decision.approve
          ? api.POST('/api/v1/admin/vehicles/{vehicle_id}/approve', { params, body })
          : api.POST('/api/v1/admin/vehicles/{vehicle_id}/reject', { params, body }),
      )
    },
  )
}

/** Ask for documents again, with a note, instead of rejecting. */
export function useRequestInfo() {
  return useApprovalMutation(
    ({ kind, id, ...body }: { kind: QueueKind; id: string } & Schemas['InfoRequestBody']) =>
      kind === 'drivers'
        ? unwrap(
            api.POST('/api/v1/admin/drivers/{driver_id}/request-info', {
              params: { path: { driver_id: id } },
              body,
            }),
          )
        : unwrap(
            api.POST('/api/v1/admin/vehicles/{vehicle_id}/request-info', {
              params: { path: { vehicle_id: id } },
              body,
            }),
          ),
  )
}
