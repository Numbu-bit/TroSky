import { keepPreviousData, useQuery } from '@tanstack/react-query'

import { api, unwrap } from '@/api/client'
import type { Schemas } from '@/api/types'

export type Performance = Schemas['DriverPerformanceResponse']

export interface PerformanceFilters {
  from: string
  to: string
  city: string
  fleet: string
  risk: string
  min: string
  sort: string
}

/** The score's parts and their weights (the backend's SCORE_WEIGHTS). */
export const SCORE_PARTS = [
  { key: 'rating', label: 'Rating', weight: 0.35 },
  { key: 'on_time', label: 'Starting on time', weight: 0.25 },
  { key: 'reliability', label: 'Not cancelling', weight: 0.15 },
  { key: 'complaints', label: 'Few complaints', weight: 0.15 },
  { key: 'qr_scanning', label: 'Scanning tickets', weight: 0.1 },
] as const

export const performanceKeys = {
  list: (filters: PerformanceFilters, page: number, limit: number) =>
    ['driver-performance', 'list', filters, page, limit] as const,
  detail: (id: string, from: string, to: string) => ['driver-performance', id, from, to] as const,
}

export function usePerformance(filters: PerformanceFilters, page: number, limit = 20) {
  return useQuery({
    queryKey: performanceKeys.list(filters, page, limit),
    queryFn: () =>
      unwrap(
        api.GET('/api/v1/admin/drivers/performance', {
          params: {
            query: {
              from: filters.from,
              to: filters.to,
              city: filters.city || undefined,
              fleet_id: filters.fleet || undefined,
              at_risk: filters.risk === 'yes' ? true : undefined,
              min_trips: filters.min ? Number(filters.min) : undefined,
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

export function useDriverPerformance(id: string, from: string, to: string) {
  return useQuery({
    queryKey: performanceKeys.detail(id, from, to),
    queryFn: () =>
      unwrap(
        api.GET('/api/v1/admin/drivers/{driver_id}/performance', {
          params: { path: { driver_id: id }, query: { from, to } },
        }),
      ),
    placeholderData: keepPreviousData,
  })
}
