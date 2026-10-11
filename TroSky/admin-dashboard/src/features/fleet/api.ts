import { keepPreviousData, useQuery } from '@tanstack/react-query'

import { api, unwrap } from '@/api/client'
import type { Schemas } from '@/api/types'

export type Vehicle = Schemas['AdminVehicleResponse']
export type Driver = Schemas['AdminDriverResponse']
export type Fleet = Schemas['AdminFleetResponse']

export interface VehicleFilters {
  status: string
  live: string
  fleet: string
  expiring: string
  q: string
  sort: string
}

export interface DriverFilters {
  status: string
  live: string
  fleet: string
  expiring: string
  q: string
  sort: string
}

export interface FleetFilters {
  owner: string
  q: string
  sort: string
}

export const fleetKeys = {
  all: ['fleet'] as const,
  vehicles: (filters: VehicleFilters, page: number, limit: number) =>
    ['fleet', 'vehicles', filters, page, limit] as const,
  drivers: (filters: DriverFilters, page: number, limit: number) =>
    ['fleet', 'drivers', filters, page, limit] as const,
  fleets: (filters: FleetFilters, page: number, limit: number) =>
    ['fleet', 'fleets', filters, page, limit] as const,
  fleet: (id: string) => ['fleet', 'fleet', id] as const,
}

export function useVehicles(filters: VehicleFilters, page: number, limit = 20) {
  return useQuery({
    queryKey: fleetKeys.vehicles(filters, page, limit),
    queryFn: () =>
      unwrap(
        api.GET('/api/v1/admin/vehicles', {
          params: {
            query: {
              status: filters.status || undefined,
              live_status: filters.live || undefined,
              fleet_id: filters.fleet || undefined,
              expiring_within_days: filters.expiring ? Number(filters.expiring) : undefined,
              q: filters.q.trim() || undefined,
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

export function useDrivers(filters: DriverFilters, page: number, limit = 20) {
  return useQuery({
    queryKey: fleetKeys.drivers(filters, page, limit),
    queryFn: () =>
      unwrap(
        api.GET('/api/v1/admin/drivers', {
          params: {
            query: {
              status: filters.status || undefined,
              live_status: filters.live || undefined,
              fleet_id: filters.fleet || undefined,
              expiring_within_days: filters.expiring ? Number(filters.expiring) : undefined,
              q: filters.q.trim() || undefined,
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

export function useFleets(filters: FleetFilters, page: number, limit = 20, enabled = true) {
  return useQuery({
    queryKey: fleetKeys.fleets(filters, page, limit),
    queryFn: () =>
      unwrap(
        api.GET('/api/v1/admin/fleets', {
          params: {
            query: {
              owner_status: filters.owner || undefined,
              q: filters.q.trim() || undefined,
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

export function useFleet(id: string | null) {
  return useQuery({
    queryKey: fleetKeys.fleet(id ?? ''),
    queryFn: () =>
      unwrap(api.GET('/api/v1/admin/fleets/{fleet_id}', { params: { path: { fleet_id: id! } } })),
    enabled: Boolean(id),
  })
}
