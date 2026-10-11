import { type ColumnDef } from '@tanstack/react-table'
import { Building2 } from 'lucide-react'
import { useState } from 'react'
import { Link, useNavigate } from 'react-router'
import { toast } from 'sonner'

import { downloadFile } from '@/api/client'
import { errorMessage } from '@/api/errors'
import { DataTable } from '@/components/data-table/DataTable'
import { EmptyState } from '@/components/feedback/states'
import { StatusBadge } from '@/components/status/StatusBadge'
import { formatMoney, formatNumber, formatPercent } from '@/lib/format'
import { usePage, useUrlState } from '@/lib/url-state'

import { useFleets, type Fleet } from './api'
import { CsvButton, FilterRow, FilterSelect, SearchFilter } from './Filters'
import { APPROVAL } from './labels'

/** Fleets and their owners: size, use and takings. */
export function FleetsPanel() {
  const navigate = useNavigate()
  const [filters, update] = useUrlState({ owner: '', q: '', sort: 'fleet_name' })
  const { page, limit, setPage } = usePage()
  const fleets = useFleets(filters, page, limit)
  const [downloading, setDownloading] = useState(false)

  const columns: ColumnDef<Fleet, unknown>[] = [
    {
      header: 'Fleet',
      cell: ({ row }) => (
        <div className="min-w-40">
          <Link
            to={`/fleet/fleets/${row.original.id}`}
            className="font-medium hover:underline"
            onClick={(event) => event.stopPropagation()}
          >
            {row.original.name}
          </Link>
          <p className="text-xs text-muted-foreground">{row.original.owner.business_name}</p>
        </div>
      ),
    },
    {
      header: 'Owner',
      cell: ({ row }) => (
        <StatusBadge
          tone={APPROVAL[row.original.owner.status].tone}
          label={APPROVAL[row.original.owner.status].label}
        />
      ),
    },
    {
      header: 'Vehicles',
      meta: { align: 'right' },
      cell: ({ row }) => (
        <span>
          {formatNumber(row.original.approved_vehicles)} /{' '}
          {formatNumber(row.original.vehicle_count)}
          <span className="block text-xs text-muted-foreground">approved / all</span>
        </span>
      ),
    },
    {
      header: 'On a trip',
      meta: { align: 'right' },
      cell: ({ row }) => formatNumber(row.original.active_now),
    },
    {
      header: 'Drivers',
      meta: { align: 'right' },
      cell: ({ row }) => formatNumber(row.original.driver_count),
    },
    {
      header: 'Used, 7 days',
      meta: { align: 'right' },
      cell: ({ row }) =>
        row.original.utilization_7d === null ? '—' : formatPercent(row.original.utilization_7d),
    },
    {
      header: 'Fares, 30 days',
      meta: { align: 'right' },
      cell: ({ row }) => formatMoney(row.original.revenue_30d),
    },
    {
      header: 'Rating',
      meta: { align: 'right' },
      cell: ({ row }) => (row.original.average_rating ? `★ ${row.original.average_rating}` : '—'),
    },
  ]

  async function download() {
    setDownloading(true)
    try {
      await downloadFile(
        '/api/v1/admin/fleets',
        { format: 'csv', owner_status: filters.owner, q: filters.q, sort: filters.sort },
        'fleets.csv',
      )
    } catch (error) {
      toast.error(errorMessage(error))
    } finally {
      setDownloading(false)
    }
  }

  return (
    <>
      <FilterRow>
        <SearchFilter
          label="Find"
          value={filters.q}
          onChange={(q) => update({ q })}
          placeholder="Fleet or business name"
        />
        <FilterSelect
          label="Owner"
          value={filters.owner}
          onChange={(owner) => update({ owner })}
          options={(Object.keys(APPROVAL) as (keyof typeof APPROVAL)[]).map((value) => ({
            value,
            label: APPROVAL[value].label,
          }))}
          any="Any owner"
        />
        <FilterSelect
          label="Order"
          value={filters.sort}
          onChange={(sort) => update({ sort })}
          options={[
            { value: 'fleet_name', label: 'Name' },
            { value: '-revenue_30d', label: 'Most fares' },
            { value: '-vehicle_count', label: 'Most vehicles' },
            { value: '-active_now', label: 'Most on the road' },
            { value: '-average_rating', label: 'Best rated' },
            { value: '-created_at', label: 'Newest first' },
          ]}
        />
        <CsvButton onClick={() => void download()} busy={downloading} />
      </FilterRow>
      <DataTable
        columns={columns}
        rows={fleets.data?.items}
        total={fleets.data?.total}
        getRowId={(row) => row.id}
        caption="Fleets"
        isPending={fleets.isPending}
        isError={fleets.isError}
        error={fleets.error}
        onRetry={() => void fleets.refetch()}
        isFetching={fleets.isFetching && !fleets.isPending}
        page={page}
        pageSize={limit}
        onPageChange={setPage}
        onRowClick={(row) => navigate(`/fleet/fleets/${row.id}`)}
        empty={
          <EmptyState icon={Building2} title="No fleets match" description="Try other filters." />
        }
      />
    </>
  )
}
