import { type ColumnDef } from '@tanstack/react-table'
import { TriangleAlert, UserRound } from 'lucide-react'
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
import { formatRelative, maskPhone } from '@/lib/format'
import { usePage, useUrlState } from '@/lib/url-state'
import { useNow } from '@/lib/use-now'

import { useDrivers, useFleets, type Driver } from './api'
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

/** Every driver: live status, rating, licence expiry. */
export function DriversPanel() {
  const navigate = useNavigate()
  const { can } = useSession()
  const [filters, update] = useUrlState({ ...NO_FILTERS, sort: 'full_name' })
  const { page, limit, setPage } = usePage()
  const drivers = useDrivers(filters, page, limit)
  const expiring = useDrivers({ ...NO_FILTERS, status: 'approved', expiring: '30' }, 1, 1)
  const seesFleets = can('vehicles:approve', 'reports:view')
  const fleets = useFleets({ owner: '', q: '', sort: 'fleet_name' }, 1, 100, seesFleets)
  const now = useNow(60_000)
  const [downloading, setDownloading] = useState(false)
  const soon = expiring.data?.total ?? 0

  const columns: ColumnDef<Driver, unknown>[] = [
    {
      header: 'Driver',
      cell: ({ row }) => (
        <div className="min-w-40">
          <Link
            to={`/fleet/drivers/${row.original.id}`}
            className="font-medium hover:underline"
            onClick={(event) => event.stopPropagation()}
          >
            {row.original.full_name ?? 'No name given'}
          </Link>
          <p className="figure text-xs text-muted-foreground">
            {maskPhone(row.original.phone_number)}
          </p>
        </div>
      ),
    },
    {
      header: 'Fleet',
      cell: ({ row }) =>
        row.original.fleet ? (
          seesFleets ? (
            <Link
              to={`/fleet/fleets/${row.original.fleet.id}`}
              className="hover:underline"
              onClick={(event) => event.stopPropagation()}
            >
              {row.original.fleet.name}
            </Link>
          ) : (
            row.original.fleet.name
          )
        ) : (
          <span className="text-muted-foreground">Independent</span>
        ),
    },
    {
      header: 'Vehicle',
      cell: ({ row }) => (
        <span className="figure">{row.original.vehicle?.registration_number ?? '—'}</span>
      ),
    },
    {
      header: 'Now',
      cell: ({ row }) => {
        const live = LIVE[row.original.live_status]
        return <StatusBadge tone={live.tone} label={live.label} icon={live.icon} />
      },
    },
    {
      header: 'Rating',
      meta: { align: 'right' },
      cell: ({ row }) =>
        row.original.average_rating
          ? `★ ${row.original.average_rating} (${row.original.rating_count})`
          : '—',
    },
    {
      header: 'Licence',
      cell: ({ row }) => <Expiry date={row.original.license_expiry} now={now} />,
    },
    {
      header: 'Last active',
      cell: ({ row }) =>
        row.original.last_active_at ? formatRelative(row.original.last_active_at, now) : 'Never',
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
        '/api/v1/admin/drivers',
        {
          format: 'csv',
          status: filters.status,
          live_status: filters.live,
          fleet_id: filters.fleet,
          expiring_within_days: filters.expiring,
          q: filters.q,
          sort: filters.sort,
        },
        'drivers.csv',
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
            {soon} approved driver{soon === 1 ? '’s licence runs' : 's’ licences run'} out within 30
            days.
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
          label="Find"
          value={filters.q}
          onChange={(q) => update({ q })}
          placeholder="Name, phone or licence"
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
          label="Licence"
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
            { value: 'full_name', label: 'Name' },
            { value: '-average_rating', label: 'Best rated' },
            { value: 'average_rating', label: 'Lowest rated' },
            { value: '-last_active_at', label: 'Active most recently' },
            { value: 'license_expiry', label: 'Licence runs out soonest' },
            { value: '-created_at', label: 'Newest first' },
          ]}
        />
        <CsvButton onClick={() => void download()} busy={downloading} />
      </FilterRow>
      <DataTable
        columns={columns}
        rows={drivers.data?.items}
        total={drivers.data?.total}
        getRowId={(row) => row.id}
        caption="Drivers"
        isPending={drivers.isPending}
        isError={drivers.isError}
        error={drivers.error}
        onRetry={() => void drivers.refetch()}
        isFetching={drivers.isFetching && !drivers.isPending}
        page={page}
        pageSize={limit}
        onPageChange={setPage}
        onRowClick={(row) => navigate(`/fleet/drivers/${row.id}`)}
        empty={
          <EmptyState icon={UserRound} title="No drivers match" description="Try other filters." />
        }
      />
    </>
  )
}
