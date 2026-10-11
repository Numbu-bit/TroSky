import { keepPreviousData, useQuery } from '@tanstack/react-query'
import { type ColumnDef } from '@tanstack/react-table'
import { History } from 'lucide-react'
import { useId, useState } from 'react'
import { toast } from 'sonner'

import { api, downloadFile, unwrap } from '@/api/client'
import { errorMessage } from '@/api/errors'
import type { Schemas } from '@/api/types'
import { useSession } from '@/app/auth/auth-context'
import { DataTable } from '@/components/data-table/DataTable'
import { EmptyState, ErrorState } from '@/components/feedback/states'
import { PageHeader } from '@/components/layout/PageHeader'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetHeader,
  SheetTitle,
} from '@/components/ui/sheet'
import { Skeleton } from '@/components/ui/skeleton'
import { CsvButton, FilterRow, FilterSelect, SearchFilter } from '@/features/fleet/Filters'
import { formatDateTime, humanize } from '@/lib/format'
import { isModuleEnabled } from '@/lib/modules'
import { usePage, useUrlState } from '@/lib/url-state'

type Entry = Schemas['AuditLogResponse']

/** The backend's tables, as admins would call them. */
const ENTITY_TYPES: Record<string, string> = {
  drivers: 'Drivers',
  vehicles: 'Vehicles',
  trips: 'Trips',
  routes: 'Routes',
  stops: 'Stops',
  users: 'Accounts',
  bookings: 'Bookings',
  refund_requests: 'Refunds',
  cancellation_requests: 'Cancellations',
  withdrawal_requests: 'Payouts',
  complaints: 'Complaints',
  sos_alerts: 'SOS alerts',
  incidents: 'Incidents',
  fraud_flags: 'Fraud flags',
  fraud_rule_configs: 'Fraud rules',
  system_settings: 'Settings',
  feature_flags: 'Feature flags',
  wallet_transactions: 'Wallets',
}

const valueText = (value: unknown) =>
  value === null || value === undefined
    ? '—'
    : typeof value === 'object'
      ? JSON.stringify(value)
      : String(value)

function useEntry(id: string | null) {
  return useQuery({
    queryKey: ['audit-log', 'entry', id],
    queryFn: () =>
      unwrap(
        api.GET('/api/v1/admin/audit-logs/{entry_id}', { params: { path: { entry_id: id! } } }),
      ),
    enabled: Boolean(id),
  })
}

function EntryDrawer({ id, onClose }: { id: string | null; onClose: () => void }) {
  const entry = useEntry(id)
  const data = entry.data
  const keys = data
    ? [...new Set([...Object.keys(data.before ?? {}), ...Object.keys(data.after ?? {})])]
    : []
  return (
    <Sheet open={Boolean(id)} onOpenChange={(open) => !open && onClose()}>
      <SheetContent className="w-full overflow-y-auto sm:max-w-lg">
        <SheetHeader>
          <SheetTitle>{data ? humanize(data.action) : 'Audit entry'}</SheetTitle>
          <SheetDescription>
            {data
              ? `${data.actor_name ?? 'Someone'} · ${formatDateTime(data.created_at)}`
              : 'Loading'}
          </SheetDescription>
        </SheetHeader>
        {entry.isPending ? (
          <Skeleton className="mx-4 h-40" />
        ) : entry.isError ? (
          <ErrorState error={entry.error} onRetry={() => void entry.refetch()} />
        ) : data ? (
          <div className="space-y-5 px-4 pb-6 text-sm">
            <dl className="grid grid-cols-[auto_1fr] gap-x-4 gap-y-1">
              <dt className="text-muted-foreground">Request</dt>
              <dd className="figure break-all">
                {data.method} {data.path}
              </dd>
              <dt className="text-muted-foreground">Record</dt>
              <dd className="figure break-all">
                {ENTITY_TYPES[data.entity_type] ?? data.entity_type}
                {data.entity_id ? ` · ${data.entity_id}` : ''}
              </dd>
              <dt className="text-muted-foreground">Reason</dt>
              <dd>{data.reason ?? '—'}</dd>
              <dt className="text-muted-foreground">From</dt>
              <dd className="figure break-all">{data.ip_address ?? '—'}</dd>
              <dt className="text-muted-foreground">Browser</dt>
              <dd className="text-xs break-all">{data.user_agent ?? '—'}</dd>
              <dt className="text-muted-foreground">Request id</dt>
              <dd className="figure">{data.request_id ?? '—'}</dd>
            </dl>
            <section aria-label="What changed">
              <h3 className="mb-2 font-semibold">What changed</h3>
              {keys.length ? (
                <table className="w-full table-fixed text-xs">
                  <caption className="sr-only">Values before and after</caption>
                  <thead>
                    <tr className="border-b text-left text-muted-foreground">
                      <th scope="col" className="w-1/3 py-1 font-medium">
                        Field
                      </th>
                      <th scope="col" className="py-1 font-medium">
                        Before
                      </th>
                      <th scope="col" className="py-1 font-medium">
                        After
                      </th>
                    </tr>
                  </thead>
                  <tbody className="figure">
                    {keys.map((key) => (
                      <tr key={key} className="border-b align-top last:border-0">
                        <th scope="row" className="py-1 pr-2 text-left font-normal wrap-break-word">
                          {key}
                        </th>
                        <td className="py-1 pr-2 wrap-break-word text-danger-text">
                          {valueText(data.before?.[key])}
                        </td>
                        <td className="py-1 wrap-break-word text-success-text">
                          {valueText(data.after?.[key])}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              ) : (
                <p className="text-muted-foreground">No values were itemised for this action.</p>
              )}
            </section>
          </div>
        ) : null}
      </SheetContent>
    </Sheet>
  )
}

/** Every admin action, newest first, with what it changed. */
export default function AuditLogScreen() {
  const { can } = useSession()
  const [filters, update] = useUrlState({
    actor: '',
    action: '',
    entity_type: '',
    entity_id: '',
    from: '',
    to: '',
    entry: '',
  })
  const { page, limit, setPage } = usePage()
  const fromId = useId()
  const toId = useId()
  const team = useQuery({
    queryKey: ['audit-log', 'team'],
    queryFn: () => unwrap(api.GET('/api/v1/admin/admins')),
    enabled: can('admins:manage') && isModuleEnabled('team'),
    staleTime: 5 * 60_000,
  })
  const query = {
    actor_id: filters.actor || undefined,
    action: filters.action || undefined,
    entity_type: filters.entity_type || undefined,
    entity_id: filters.entity_id || undefined,
    from: filters.from || undefined,
    to: filters.to || undefined,
  }
  const entries = useQuery({
    queryKey: ['audit-log', query, page, limit],
    queryFn: () =>
      unwrap(
        api.GET('/api/v1/admin/audit-logs', {
          params: { query: { ...query, limit, offset: (page - 1) * limit } },
        }),
      ),
    placeholderData: keepPreviousData,
  })
  const [downloading, setDownloading] = useState(false)

  const columns: ColumnDef<Entry, unknown>[] = [
    {
      header: 'When',
      cell: ({ row }) => (
        <span className="whitespace-nowrap">{formatDateTime(row.original.created_at)}</span>
      ),
    },
    {
      header: 'Who',
      cell: ({ row }) =>
        row.original.actor_name ?? <span className="text-muted-foreground">—</span>,
    },
    {
      header: 'What',
      cell: ({ row }) => (
        <button
          type="button"
          className="link-inline text-left font-medium"
          onClick={(event) => {
            event.stopPropagation()
            update({ entry: row.original.id }, { keepPage: true })
          }}
        >
          {humanize(row.original.action)}
        </button>
      ),
    },
    {
      header: 'Record',
      cell: ({ row }) => (
        <span className="text-sm">
          {ENTITY_TYPES[row.original.entity_type] ?? row.original.entity_type}
          {row.original.entity_id ? (
            <span className="figure block text-xs text-muted-foreground">
              {row.original.entity_id.slice(0, 8)}…
            </span>
          ) : null}
        </span>
      ),
    },
    {
      header: 'Reason',
      cell: ({ row }) => (
        <span className="line-clamp-2 max-w-72 text-sm text-muted-foreground">
          {row.original.reason ?? '—'}
        </span>
      ),
    },
  ]

  async function download() {
    setDownloading(true)
    try {
      await downloadFile('/api/v1/admin/audit-logs', { ...query, format: 'csv' }, 'audit-log.csv')
    } catch (error) {
      toast.error(errorMessage(error))
    } finally {
      setDownloading(false)
    }
  }

  return (
    <>
      <PageHeader
        title="Audit log"
        description="Every change an admin made, newest first, with the values before and after."
      />
      <FilterRow>
        {team.data ? (
          <FilterSelect
            label="Who"
            value={filters.actor}
            onChange={(actor) => update({ actor })}
            options={team.data.map((member) => ({
              value: member.id,
              label: member.full_name ?? member.phone_number,
            }))}
            any="Anyone"
          />
        ) : null}
        <FilterSelect
          label="Record"
          value={filters.entity_type}
          onChange={(entity_type) => update({ entity_type })}
          options={Object.entries(ENTITY_TYPES).map(([value, label]) => ({ value, label }))}
          any="Any record"
        />
        <SearchFilter
          label="Action"
          value={filters.action}
          onChange={(action) => update({ action })}
          placeholder="e.g. approve_driver"
        />
        <SearchFilter
          label="Record id"
          value={filters.entity_id}
          onChange={(entity_id) => update({ entity_id })}
          placeholder="The record’s id"
        />
        <div className="grid gap-1.5">
          <Label htmlFor={fromId}>From</Label>
          <Input
            id={fromId}
            type="date"
            value={filters.from}
            max={filters.to || undefined}
            onChange={(event) => update({ from: event.target.value })}
          />
        </div>
        <div className="grid gap-1.5">
          <Label htmlFor={toId}>To</Label>
          <Input
            id={toId}
            type="date"
            value={filters.to}
            min={filters.from || undefined}
            onChange={(event) => update({ to: event.target.value })}
          />
        </div>
        <CsvButton onClick={() => void download()} busy={downloading} />
      </FilterRow>
      <DataTable
        columns={columns}
        rows={entries.data?.items}
        total={entries.data?.total}
        getRowId={(row) => row.id}
        caption="Audit log"
        isPending={entries.isPending}
        isError={entries.isError}
        error={entries.error}
        onRetry={() => void entries.refetch()}
        isFetching={entries.isFetching && !entries.isPending}
        page={page}
        pageSize={limit}
        onPageChange={setPage}
        onRowClick={(row) => update({ entry: row.id }, { keepPage: true })}
        selectedId={filters.entry || null}
        empty={
          <EmptyState
            icon={History}
            title="Nothing recorded"
            description="No admin action matches these filters."
          />
        }
      />
      <EntryDrawer
        id={filters.entry || null}
        onClose={() => update({ entry: null }, { keepPage: true })}
      />
    </>
  )
}
