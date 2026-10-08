import { type ColumnDef } from '@tanstack/react-table'
import { ArrowRight, Waypoints } from 'lucide-react'
import { useId, useState } from 'react'
import { Link, useNavigate } from 'react-router'

import type { Schemas } from '@/api/types'
import { DataTable } from '@/components/data-table/DataTable'
import { EmptyState } from '@/components/feedback/states'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { useRoutes } from '@/features/shared/reference'
import { formatDate, formatMinutes, formatNumber } from '@/lib/format'

import { useAllStops } from './api'
import { RouteDialog } from './RouteDialog'

type Route = Schemas['RouteResponse']

/** Every active route, A to Z, filtered as you type. */
export function RoutesPanel() {
  const navigate = useNavigate()
  const routes = useRoutes()
  const stops = useAllStops()
  const [filter, setFilter] = useState('')
  const filterId = useId()
  const name = (id: string) => stops.data?.byId.get(id)?.name ?? '…'
  const wanted = filter.trim().toLowerCase()
  const rows = routes.data?.items.filter(
    (route) =>
      !wanted ||
      route.name.toLowerCase().includes(wanted) ||
      name(route.origin_stop_id).toLowerCase().includes(wanted) ||
      name(route.destination_stop_id).toLowerCase().includes(wanted),
  )

  const columns: ColumnDef<Route, unknown>[] = [
    {
      header: 'Route',
      cell: ({ row }) => (
        <div className="min-w-48">
          <Link
            to={`/network/routes/${row.original.id}`}
            className="font-medium hover:underline"
            onClick={(event) => event.stopPropagation()}
          >
            {row.original.name}
          </Link>
          <p className="text-xs text-muted-foreground">
            {name(row.original.origin_stop_id)}{' '}
            <ArrowRight className="inline size-3" aria-label="to" />{' '}
            {name(row.original.destination_stop_id)}
          </p>
        </div>
      ),
    },
    {
      header: 'Length',
      meta: { align: 'right' },
      cell: ({ row }) =>
        row.original.distance_km
          ? `${formatNumber(row.original.distance_km, { decimals: true })} km`
          : '—',
    },
    {
      header: 'Time',
      meta: { align: 'right' },
      cell: ({ row }) =>
        row.original.estimated_duration_minutes
          ? formatMinutes(row.original.estimated_duration_minutes)
          : '—',
    },
    {
      header: 'Created',
      cell: ({ row }) => (
        <span className="whitespace-nowrap">{formatDate(row.original.created_at)}</span>
      ),
    },
  ]

  return (
    <>
      <div className="mb-4 flex flex-wrap items-end justify-between gap-3">
        <div className="grid w-full max-w-sm gap-1.5">
          <Label htmlFor={filterId}>Find a route</Label>
          <Input
            id={filterId}
            type="search"
            value={filter}
            placeholder="Route or stop name"
            onChange={(event) => setFilter(event.target.value)}
          />
        </div>
        <RouteDialog />
      </div>
      <DataTable
        columns={columns}
        rows={rows}
        getRowId={(row) => row.id}
        caption="Routes"
        isPending={routes.isPending}
        isError={routes.isError}
        error={routes.error}
        onRetry={() => void routes.refetch()}
        onRowClick={(row) => navigate(`/network/routes/${row.id}`)}
        empty={
          <EmptyState
            icon={Waypoints}
            title={wanted ? 'No route matches' : 'No routes yet'}
            description={
              wanted ? 'Try another name.' : 'Add stops first, then a route through them.'
            }
          />
        }
      />
      {rows && rows.length ? (
        <p className="mt-2 text-xs text-muted-foreground">
          {formatNumber(rows.length)} of {formatNumber(routes.data?.items.length ?? 0)} active
          routes. Retired routes aren’t listed; their trips and bookings keep them.
        </p>
      ) : null}
    </>
  )
}
