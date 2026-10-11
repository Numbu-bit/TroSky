import { type ColumnDef } from '@tanstack/react-table'
import { ArrowRight, Bus, Download } from 'lucide-react'
import { useId, useState } from 'react'
import { Link, useNavigate } from 'react-router'
import { toast } from 'sonner'

import { downloadFile } from '@/api/client'
import { errorMessage } from '@/api/errors'
import type { Schemas } from '@/api/types'
import { useSession } from '@/app/auth/auth-context'
import { DataTable } from '@/components/data-table/DataTable'
import { EmptyState } from '@/components/feedback/states'
import { PageHeader } from '@/components/layout/PageHeader'
import { DriverPicker } from '@/components/pickers/pickers'
import { StatusBadge } from '@/components/status/StatusBadge'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import { useRoutes } from '@/features/shared/reference'
import { accraDateKey, formatDayMonth, formatNumber, formatTime, humanize } from '@/lib/format'
import { usePage, useUrlState } from '@/lib/url-state'

import { useTrips } from './api'
import { DriverAnswer } from './DriverAnswer'
import { TRIP_STATUSES, tripStatusTone } from './status'
import { CreateTripDialog, TripFromTimetableDialog } from './TripDialogs'

type TripRow = Schemas['AdminTripSummaryResponse']

const NOT_FINISHED = 'scheduled,boarding,in_progress,paused'

const STATUS_FILTERS = [
  { value: 'open', label: 'Not finished' },
  ...TRIP_STATUSES.map((status) => ({ value: status as string, label: humanize(status) })),
  { value: 'all', label: 'Any status' },
]

const ANY_DAY = 'all'
const ANY_ROUTE = 'all'

/** Every trip, soonest departure first; today's unfinished ones to start with. */
export function TripsList() {
  const navigate = useNavigate()
  const { can } = useSession()
  const today = accraDateKey()
  const [filters, update] = useUrlState({ status: 'open', date: today, route: '', driver: '' })
  const { page, limit, setPage } = usePage()
  const [downloading, setDownloading] = useState(false)
  const routes = useRoutes()
  const ids = { status: useId(), date: useId(), route: useId(), driver: useId() }

  const query = {
    status:
      filters.status === 'open' ? NOT_FINISHED : filters.status === 'all' ? '' : filters.status,
    date: filters.date === ANY_DAY ? '' : filters.date,
    route: filters.route,
    driver: filters.driver,
  }
  const trips = useTrips(query, page, limit)
  const rows = trips.data?.items
  const manages = can('trips:manage')
  const picksDrivers = can('drivers:approve', 'trips:monitor_live')

  const columns: ColumnDef<TripRow, unknown>[] = [
    {
      header: 'Departs',
      cell: ({ row }) => (
        <div className="whitespace-nowrap">
          <p className="figure font-medium">{formatTime(row.original.scheduled_departure_at)}</p>
          {query.date ? null : (
            <p className="text-xs text-muted-foreground">
              {formatDayMonth(row.original.scheduled_departure_at)}
            </p>
          )}
        </div>
      ),
    },
    {
      header: 'Route',
      cell: ({ row }) => (
        <div className="min-w-48">
          <Link
            to={`/trips/${row.original.trip_id}`}
            className="font-medium hover:underline"
            onClick={(event) => event.stopPropagation()}
          >
            {row.original.route_name}
          </Link>
          <p className="text-xs text-muted-foreground">
            {row.original.origin_stop_name} <ArrowRight className="inline size-3" aria-label="to" />{' '}
            {row.original.destination_stop_name}
          </p>
        </div>
      ),
    },
    {
      header: 'Status',
      cell: ({ row }) => (
        <StatusBadge
          tone={tripStatusTone(row.original.status)}
          label={humanize(row.original.status)}
        />
      ),
    },
    {
      header: 'Driver',
      cell: ({ row }) =>
        row.original.driver_id ? (
          <div className="space-y-1">
            <p>{row.original.driver_name ?? 'Unnamed driver'}</p>
            <DriverAnswer response={row.original.driver_response} />
          </div>
        ) : (
          <span className="text-muted-foreground">None yet</span>
        ),
    },
    {
      header: 'Vehicle',
      cell: ({ row }) =>
        row.original.vehicle_registration_number ?? (
          <span className="text-muted-foreground">None yet</span>
        ),
    },
    {
      header: 'Seats',
      meta: { align: 'right' },
      cell: ({ row }) => (
        <div>
          <p>
            {formatNumber(row.original.seats_booked)} / {formatNumber(row.original.seats_total)}
          </p>
          {row.original.boarded_count ? (
            <p className="text-xs text-muted-foreground">
              {formatNumber(row.original.boarded_count)} boarded
            </p>
          ) : null}
        </div>
      ),
    },
  ]

  async function download() {
    setDownloading(true)
    try {
      await downloadFile(
        '/api/v1/admin/trips',
        {
          format: 'csv',
          status: query.status,
          date: query.date,
          route_id: query.route,
          driver_id: query.driver,
        },
        `trips-${query.date || 'all-days'}.csv`,
      )
    } catch (error) {
      toast.error(errorMessage(error))
    } finally {
      setDownloading(false)
    }
  }

  const driverName = rows?.find((row) => row.driver_id === filters.driver)?.driver_name

  return (
    <>
      <PageHeader
        title="Trips"
        description="Soonest departure first. Times are Accra time."
        actions={
          <>
            <Button variant="outline" onClick={() => void download()} disabled={downloading}>
              <Download aria-hidden /> CSV
            </Button>
            {manages ? (
              <>
                <TripFromTimetableDialog />
                <CreateTripDialog />
              </>
            ) : null}
          </>
        }
      />
      <div
        className="mb-4 grid gap-3 sm:grid-cols-2 lg:grid-cols-4"
        role="group"
        aria-label="Filters"
      >
        <div className="grid gap-1.5">
          <Label htmlFor={ids.date}>Day</Label>
          <div className="flex gap-1">
            <Input
              id={ids.date}
              type="date"
              value={filters.date === ANY_DAY ? '' : filters.date}
              onChange={(event) => update({ date: event.target.value || ANY_DAY })}
            />
            {filters.date === today ? (
              <Button variant="ghost" onClick={() => update({ date: ANY_DAY })}>
                Any day
              </Button>
            ) : (
              <Button variant="ghost" onClick={() => update({ date: today })}>
                Today
              </Button>
            )}
          </div>
        </div>
        <div className="grid gap-1.5">
          <Label htmlFor={ids.status}>Status</Label>
          <Select value={filters.status} onValueChange={(status) => update({ status })}>
            <SelectTrigger id={ids.status}>
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              {STATUS_FILTERS.map((option) => (
                <SelectItem key={option.value} value={option.value}>
                  {option.label}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
        <div className="grid gap-1.5">
          <Label htmlFor={ids.route}>Route</Label>
          <Select
            value={filters.route || ANY_ROUTE}
            onValueChange={(route) => update({ route: route === ANY_ROUTE ? null : route })}
          >
            <SelectTrigger id={ids.route}>
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value={ANY_ROUTE}>Every route</SelectItem>
              {(routes.data?.items ?? []).map((route) => (
                <SelectItem key={route.id} value={route.id}>
                  {route.name}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
        {picksDrivers ? (
          <div className="grid gap-1.5">
            <Label htmlFor={ids.driver}>Driver</Label>
            <DriverPicker
              id={ids.driver}
              value={filters.driver || null}
              selectedLabel={driverName ?? 'The chosen driver'}
              onChange={(option) => update({ driver: option?.value ?? null })}
              placeholder="Every driver"
              allowClear
            />
          </div>
        ) : null}
      </div>
      <DataTable
        columns={columns}
        rows={rows}
        total={trips.data?.total}
        getRowId={(row) => row.trip_id}
        caption="Trips"
        isPending={trips.isPending}
        isError={trips.isError}
        error={trips.error}
        onRetry={() => void trips.refetch()}
        isFetching={trips.isFetching && !trips.isPending}
        page={page}
        pageSize={limit}
        onPageChange={setPage}
        onRowClick={(row) => navigate(`/trips/${row.trip_id}`)}
        empty={
          <EmptyState
            icon={Bus}
            title="No trips match"
            description={
              manages
                ? 'Try another day or status, or create a trip.'
                : 'Try another day or status.'
            }
          />
        }
      />
    </>
  )
}
