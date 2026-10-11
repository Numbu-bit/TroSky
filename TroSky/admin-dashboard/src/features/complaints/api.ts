import { keepPreviousData, useMutation, useQuery, useQueryClient } from '@tanstack/react-query'

import { api, unwrap } from '@/api/client'
import type { Schemas } from '@/api/types'
import { useSession } from '@/app/auth/auth-context'
import { isModuleEnabled } from '@/lib/modules'

export type Complaint = Schemas['AdminComplaintResponse']
export type ComplaintStatus = Schemas['ComplaintStatus']
export type ComplaintPriority = Schemas['ComplaintPriority']
export type ComplaintCategory = Schemas['ComplaintCategory']

export interface ComplaintFilters {
  status: string
  priority: string
  category: string
  assigned: string
  overdue: string
  sort: string
}

export const complaintKeys = {
  all: ['complaints'] as const,
  list: (filters: ComplaintFilters, page: number) => ['complaints', 'list', filters, page] as const,
  detail: (id: string) => ['complaints', 'detail', id] as const,
  stats: ['complaints', 'stats'] as const,
  team: ['complaints', 'team'] as const,
}

export function useComplaints(filters: ComplaintFilters, page: number, limit: number, me: string) {
  return useQuery({
    queryKey: complaintKeys.list(filters, page),
    queryFn: () =>
      unwrap(
        api.GET('/api/v1/admin/complaints', {
          params: {
            query: {
              complaint_status: filters.status || undefined,
              priority: filters.priority || undefined,
              category: filters.category || undefined,
              assigned_to: filters.assigned === 'me' ? me : undefined,
              unassigned: filters.assigned === 'none' ? true : undefined,
              overdue: filters.overdue === 'yes' ? true : undefined,
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

export function useComplaint(id: string | null) {
  return useQuery({
    queryKey: complaintKeys.detail(id ?? ''),
    queryFn: () =>
      unwrap(
        api.GET('/api/v1/admin/complaints/{complaint_id}', {
          params: { path: { complaint_id: id! } },
        }),
      ),
    enabled: Boolean(id),
  })
}

/** Open and overdue now, and how the last 30 days were handled (insights module). */
export function useComplaintStats(enabled: boolean) {
  return useQuery({
    queryKey: complaintKeys.stats,
    queryFn: () => unwrap(api.GET('/api/v1/admin/complaints/stats')),
    enabled,
  })
}

/** The admins a complaint can be given to: the team list (admins:manage). */
export function useComplaintTeam() {
  const { can } = useSession()
  return useQuery({
    queryKey: complaintKeys.team,
    queryFn: () => unwrap(api.GET('/api/v1/admin/admins')),
    enabled: can('admins:manage') && isModuleEnabled('team'),
    select: (team) =>
      team.filter(
        (member) =>
          member.is_active &&
          !member.is_suspended &&
          (member.role === 'super_admin' || member.permissions.includes('complaints:manage')),
      ),
    staleTime: 5 * 60_000,
  })
}

function useComplaintMutation<V, R>(run: (variables: V) => Promise<R>) {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: run,
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: complaintKeys.all })
      void queryClient.invalidateQueries({ queryKey: ['notifications'] })
      void queryClient.invalidateQueries({ queryKey: ['alerts'] })
    },
  })
}

/** Assign (null unassigns), set the priority, or start the review. */
export function useUpdateComplaint(id: string) {
  return useComplaintMutation((body: Schemas['ComplaintUpdateRequest']) =>
    unwrap(
      api.PATCH('/api/v1/admin/complaints/{complaint_id}', {
        params: { path: { complaint_id: id } },
        body,
      }),
    ),
  )
}

/** An internal note for the team, or a message sent to the passenger. */
export function useAddComplaintNote(id: string) {
  return useComplaintMutation((body: Schemas['ComplaintNoteRequest']) =>
    unwrap(
      api.POST('/api/v1/admin/complaints/{complaint_id}/notes', {
        params: { path: { complaint_id: id } },
        body,
      }),
    ),
  )
}

export function useDecideComplaint(id: string) {
  return useComplaintMutation(({ resolve, notes }: { resolve: boolean; notes: string }) => {
    const options = { params: { path: { complaint_id: id } }, body: { notes } }
    return unwrap(
      resolve
        ? api.POST('/api/v1/admin/complaints/{complaint_id}/resolve', options)
        : api.POST('/api/v1/admin/complaints/{complaint_id}/dismiss', options),
    )
  })
}
