import { type ColumnDef } from '@tanstack/react-table'
import { ShieldAlert, Trophy } from 'lucide-react'
import { useState } from 'react'
import { Link, useNavigate } from 'react-router'
import { toast } from 'sonner'

import { downloadFile } from '@/api/client'
import { errorMessage } from '@/api/errors'
import { useSession } from '@/app/auth/auth-context'
import { DataTable } from '@/components/data-table/DataTable'
import { EmptyState } from '@/components/feedback/states'
import { PageHeader } from '@/components/layout/PageHeader'
import { StatusBadge } from '@/components/status/StatusBadge'
import { Button } from '@/components/ui/button'
import { useFleets } from '@/features/fleet/api'
import { CsvButton, FilterRow, FilterSelect } from '@/features/fleet/Filters'
import { usePeriod } from '@/features/shared/period'
import { PeriodControls } from '@/features/shared/PeriodControls'
import { formatNumber, formatPercent } from '@/lib/format'
import { usePage, useUrlState } from '@/lib/url-state'
import { cn } from '@/lib/utils'

import { usePerformance, type Performance } from './api'

const percent = (value: string | null) => (value === null ? '—' : formatPercent(value))

export function ScoreBar({ score }: { score: string | null }) {
  if (score === null) return <span className="text-muted-foreground">—</span>
  const value = Number(score)
  return (
    <span className="inline-flex items-center gap-2">
      <span className="figure w-10 text-right font-medium">
        {formatNumber(value, { decimals: true })}
      </span>
      <span className="h-2 w-20 rounded-full bg-muted" aria-hidden>
        <span
          className={cn(
            'block h-2 rounded-full',
            value < 60 ? 'bg-danger' : value < 75 ? 'bg-warning' : 'bg-chart-1',
          )}
          style={{ width: `${value}%` }}
        />
      </span>
    </span>
  )
}

/** Drivers by a 0-100 score, worst first, and who is at risk and why. */
export function Leaderboard() {
  const navigate = useNavigate()
  const { can } = useSession()
  const [period] = usePeriod()
  const [filters, update] = useUrlState({ fleet: '', risk: '', min: '', sort: 'score' })
  const { page, limit, setPage } = usePage()
  const query = { from: period.from, to: period.to, city: period.city, ...filters }
  const rows = usePerformance(query, page, limit)
  const atRisk = usePerformance({ ...query, risk: 'yes' }, 1, 1)
  const seesFleets = can('vehicles:approve', 'reports:view')
  const fleets = useFleets({ owner: '', q: '', sort: 'fleet_name' }, 1, 100, seesFleets)
  const [downloading, setDownloading] = useState(false)
  const risky = atRisk.data?.total ?? 0

  const columns: ColumnDef<Performance, unknown>[] = [
    {
      header: 'Driver',
      cell: ({ row }) => (
        <div className="min-w-36">
          <Link
            to={`/driver-performance/${row.original.driver_id}`}
            className="font-medium hover:underline"
            onClick={(event) => event.stopPropagation()}
          >
            {row.original.full_name ?? 'No name given'}
          </Link>
          {row.original.at_risk ? (
            <p className="mt-0.5">
              <StatusBadge tone="danger" icon={ShieldAlert} label="At risk" />
            </p>
          ) : null}
        </div>
      ),
    },
    { header: 'Score', cell: ({ row }) => <ScoreBar score={row.original.score} /> },
    {
      header: 'Rating',
      meta: { align: 'right' },
      cell: ({ row }) =>
        row.original.average_rating
          ? `★ ${row.original.average_rating} (${row.original.rating_count})`
          : '—',
    },
    {
      header: 'On time',
      meta: { align: 'right' },
      cell: ({ row }) => percent(row.original.on_time_rate),
    },
    {
      header: 'Cancelled',
      meta: { align: 'right' },
      cell: ({ row }) => percent(row.original.cancellation_rate),
    },
    {
      header: 'Complaints / 100 trips',
      meta: { align: 'right' },
      cell: ({ row }) =>
        row.original.complaints_per_100_trips === null
          ? '—'
          : formatNumber(row.original.complaints_per_100_trips, { decimals: true }),
    },
    {
      header: 'Tickets scanned',
      meta: { align: 'right' },
      cell: ({ row }) => percent(row.original.qr_scan_rate),
    },
    {
      header: 'Trips',
      meta: { align: 'right' },
      cell: ({ row }) =>
        `${formatNumber(row.original.trips_completed)} / ${formatNumber(row.original.trips_assigned)}`,
    },
    {
      header: 'Why at risk',
      cell: ({ row }) =>
        row.original.at_risk_reasons.length ? (
          <ul className="max-w-64 list-disc pl-4 text-xs text-danger-text">
            {row.original.at_risk_reasons.map((reason) => (
              <li key={reason.code}>{reason.message}</li>
            ))}
          </ul>
        ) : null,
    },
  ]

  async function download() {
    setDownloading(true)
    try {
      await downloadFile(
        '/api/v1/admin/drivers/performance',
        {
          format: 'csv',
          from: query.from,
          to: query.to,
          city: query.city,
          fleet_id: query.fleet,
          at_risk: query.risk === 'yes' ? true : undefined,
          min_trips: query.min,
          sort: query.sort,
        },
        `driver-performance-${query.from}-${query.to}.csv`,
      )
    } catch (error) {
      toast.error(errorMessage(error))
    } finally {
      setDownloading(false)
    }
  }

  return (
    <>
      <PageHeader
        title="Driver performance"
        description={`${period.label}. Every driver with a trip in the period, by a 0-100 score built from rating, on-time starts, cancellations, complaints and ticket scanning.`}
        actions={<PeriodControls />}
      />
      {risky && filters.risk !== 'yes' ? (
        <div
          role="status"
          className="mb-4 flex flex-wrap items-center gap-3 rounded-lg border border-danger/30 bg-danger-soft p-3 text-sm text-danger-text"
        >
          <ShieldAlert className="size-4 shrink-0" aria-hidden />
          <span className="flex-1">
            {risky} driver{risky === 1 ? ' is' : 's are'} at risk in this period.
          </span>
          <Button size="sm" variant="outline" onClick={() => update({ risk: 'yes' })}>
            Show them
          </Button>
        </div>
      ) : null}
      <FilterRow>
        <FilterSelect
          label="Drivers"
          value={filters.risk}
          onChange={(risk) => update({ risk })}
          options={[{ value: 'yes', label: 'At risk only' }]}
          any="Everyone"
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
          label="Completed trips"
          value={filters.min}
          onChange={(min) => update({ min })}
          options={[
            { value: '5', label: '5 or more' },
            { value: '10', label: '10 or more' },
            { value: '20', label: '20 or more' },
          ]}
          any="Any"
        />
        <FilterSelect
          label="Order"
          value={filters.sort}
          onChange={(sort) => update({ sort })}
          options={[
            { value: 'score', label: 'Lowest score first' },
            { value: '-score', label: 'Highest score first' },
            { value: 'average_rating', label: 'Lowest rated' },
            { value: 'on_time_rate', label: 'Least on time' },
            { value: '-cancellation_rate', label: 'Most cancellations' },
            { value: '-complaints_per_100_trips', label: 'Most complaints' },
            { value: '-trips_completed', label: 'Most trips' },
          ]}
        />
        <CsvButton onClick={() => void download()} busy={downloading} />
      </FilterRow>
      <DataTable
        columns={columns}
        rows={rows.data?.items}
        total={rows.data?.total}
        getRowId={(row) => row.driver_id}
        caption="Driver performance"
        isPending={rows.isPending}
        isError={rows.isError}
        error={rows.error}
        onRetry={() => void rows.refetch()}
        isFetching={rows.isFetching && !rows.isPending}
        page={page}
        pageSize={limit}
        onPageChange={setPage}
        onRowClick={(row) => navigate(`/driver-performance/${row.driver_id}`)}
        empty={
          <EmptyState
            icon={Trophy}
            title="No drivers match"
            description="Nobody drove in this period with these filters."
          />
        }
      />
    </>
  )
}
