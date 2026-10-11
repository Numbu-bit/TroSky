import { type ColumnDef } from '@tanstack/react-table'
import { Bus, TriangleAlert } from 'lucide-react'
import { useState } from 'react'
import { Link, useNavigate } from 'react-router'
import { toast } from 'sonner'

import { downloadFile } from '@/api/client'
import { errorMessage } from '@/api/errors'
import { useSession } from '@/app/auth/auth-context'
import { DataTable } from '@/components/data-table/DataTable'
import { EmptyState } from '@/components/feedback/states'
import { StatusBadge } from '@/components/status/StatusBadge'
import { Button } from '@/components/ui/button'
import { Expiry } from '@/features/approvals/DocumentList'
import { humanize } from '@/lib/format'
import { usePage, useUrlState } from '@/lib/url-state'
import { useNow } from '@/lib/use-now'

import { useFleets, useVehicles, type Vehicle } from './api'
import { CsvButton, FilterRow, FilterSelect, SearchFilter } from './Filters'
import { APPROVAL, LIVE } from './labels'

const NO_FILTERS = { status: '', live: '', fleet: '', expiring: '', q: '', sort: '' }

const STATUS_OPTIONS = (Object.keys(APPROVAL) as (keyof typeof APPROVAL)[]).map((value) => ({
  value,
  label: APPROVAL[value].label,
}))
const LIVE_OPTIONS = (Object.keys(LIVE) as (keyof typeof LIVE)[]).map((value) => ({
  value,
  label: LIVE[value].label,
}))

/** Every vehicle, not only those waiting for approval: live status and documents. */
export function VehiclesPanel() {
  const navigate = useNavigate()
  const { can } = useSession()
  const [filters, update] = useUrlState({ ...NO_FILTERS, sort: 'registration_number' })
  const { page, limit, setPage } = usePage()
  const vehicles = useVehicles(filters, page, limit)
  const expiring = useVehicles({ ...NO_FILTERS, status: 'approved', expiring: '30' }, 1, 1)
  const seesFleets = can('vehicles:approve', 'reports:view')
  const fleets = useFleets({ owner: '', q: '', sort: 'fleet_name' }, 1, 100, seesFleets)
  const now = useNow(60_000)
  const [downloading, setDownloading] = useState(false)
  const soon = expiring.data?.total ?? 0

  const columns: ColumnDef<Vehicle, unknown>[] = [
    {
      header: 'Vehicle',
      cell: ({ row }) => (
        <div className="min-w-40">
          <Link
            to={`/fleet/vehicles/${row.original.id}`}
            className="figure font-medium hover:underline"
            onClick={(event) => event.stopPropagation()}
          >
            {row.original.registration_number}
          </Link>
          <p className="text-xs text-muted-foreground">
            {row.original.make_model ?? humanize(row.original.vehicle_type)} ·{' '}
            {row.original.capacity} seats
          </p>
        </div>
      ),
    },
    {
      header: 'Fleet',
      cell: ({ row }) => (
        <div>
          {seesFleets ? (
            <Link
              to={`/fleet/fleets/${row.original.fleet.id}`}
              className="hover:underline"
              onClick={(event) => event.stopPropagation()}
            >
              {row.original.fleet.name}
            </Link>
          ) : (
            row.original.fleet.name
          )}
          <p className="text-xs text-muted-foreground">{row.original.fleet_owner.name}</p>
        </div>
      ),
    },
    {
      header: 'Driver',
      cell: ({ row }) =>
        row.original.driver?.name ?? <span className="text-muted-foreground">—</span>,
    },
    {
      header: 'Now',
      cell: ({ row }) => {
        const live = LIVE[row.original.live_status]
        return row.original.current_trip_id ? (
          <Link
            to={`/trips/${row.original.current_trip_id}`}
            onClick={(event) => event.stopPropagation()}
          >
            <StatusBadge tone={live.tone} label={live.label} icon={live.icon} />
          </Link>
        ) : (
          <StatusBadge tone={live.tone} label={live.label} icon={live.icon} />
        )
      },
    },
    {
      header: 'Insurance',
      cell: ({ row }) => <Expiry date={row.original.insurance_expiry} now={now} />,
    },
    {
      header: 'Roadworthy',
      cell: ({ row }) => <Expiry date={row.original.roadworthy_expiry} now={now} />,
    },
    {
      header: 'Status',
      cell: ({ row }) => (
        <StatusBadge
          tone={APPROVAL[row.original.status].tone}
          label={APPROVAL[row.original.status].label}
        />
      ),
    },
  ]

  async function download() {
    setDownloading(true)
    try {
      await downloadFile(
        '/api/v1/admin/vehicles',
        {
          format: 'csv',
          status: filters.status,
          live_status: filters.live,
          fleet_id: filters.fleet,
          expiring_within_days: filters.expiring,
          q: filters.q,
          sort: filters.sort,
        },
        'vehicles.csv',
      )
    } catch (error) {
      toast.error(errorMessage(error))
    } finally {
      setDownloading(false)
    }
  }

  return (
    <>
      {soon && filters.expiring !== '30' ? (
        <div
          role="status"
          className="mb-4 flex flex-wrap items-center gap-3 rounded-lg border border-warning/40 bg-warning-soft p-3 text-sm text-warning-text"
        >
          <TriangleAlert className="size-4 shrink-0" aria-hidden />
          <span className="flex-1">
            {soon} approved vehicle{soon === 1 ? ' has' : 's have'} insurance or a roadworthiness
            certificate running out within 30 days.
          </span>
          <Button
            size="sm"
            variant="outline"
            onClick={() => update({ expiring: '30', status: 'approved' })}
          >
            Show them
          </Button>
        </div>
      ) : null}
      <FilterRow>
        <SearchFilter
          label="Plate"
          value={filters.q}
          onChange={(q) => update({ q })}
          placeholder="GR 2451"
        />
        <FilterSelect
          label="Status"
          value={filters.status}
          onChange={(status) => update({ status })}
          options={STATUS_OPTIONS}
          any="Any status"
        />
        <FilterSelect
          label="Now"
          value={filters.live}
          onChange={(live) => update({ live })}
          options={LIVE_OPTIONS}
          any="Anything"
        />
        {seesFleets ? (
          <FilterSelect
            label="Fleet"
            value={filters.fleet}
            onChange={(fleet) => update({ fleet })}
            options={(fleets.data?.items ?? []).map((fleet) => ({
              value: fleet.id,
              label: fleet.name,
            }))}
            any="Every fleet"
          />
        ) : null}
        <FilterSelect
          label="Documents"
          value={filters.expiring}
          onChange={(expiring) => update({ expiring })}
          options={[
            { value: '0', label: 'Already expired' },
            { value: '30', label: 'Running out within 30 days' },
            { value: '90', label: 'Running out within 90 days' },
          ]}
          any="Any"
        />
        <FilterSelect
          label="Order"
          value={filters.sort}
          onChange={(sort) => update({ sort })}
          options={[
            { value: 'registration_number', label: 'Plate' },
            { value: '-created_at', label: 'Newest first' },
            { value: 'insurance_expiry', label: 'Insurance runs out soonest' },
            { value: 'roadworthy_expiry', label: 'Roadworthiness runs out soonest' },
            { value: '-capacity', label: 'Most seats' },
          ]}
        />
        <CsvButton onClick={() => void download()} busy={downloading} />
      </FilterRow>
      <DataTable
        columns={columns}
        rows={vehicles.data?.items}
        total={vehicles.data?.total}
        getRowId={(row) => row.id}
        caption="Vehicles"
        isPending={vehicles.isPending}
        isError={vehicles.isError}
        error={vehicles.error}
        onRetry={() => void vehicles.refetch()}
        isFetching={vehicles.isFetching && !vehicles.isPending}
        page={page}
        pageSize={limit}
        onPageChange={setPage}
        onRowClick={(row) => navigate(`/fleet/vehicles/${row.id}`)}
        empty={<EmptyState icon={Bus} title="No vehicles match" description="Try other filters." />}
      />
    </>
  )
}
