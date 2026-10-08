import { useQueries } from '@tanstack/react-query'
import { type ColumnDef } from '@tanstack/react-table'
import { Download, ShieldCheck, Siren } from 'lucide-react'
import { toast } from 'sonner'
import { Link, Navigate, Route, Routes } from 'react-router'

import { api, downloadFile, unwrap } from '@/api/client'
import { errorMessage } from '@/api/errors'
import type { Schemas } from '@/api/types'
import { useSession } from '@/app/auth/auth-context'
import { ConfirmButton } from '@/components/confirm/ConfirmButton'
import { ConfirmFacts } from '@/components/confirm/ConfirmDialog'
import { DataTable } from '@/components/data-table/DataTable'
import { EmptyState } from '@/components/feedback/states'
import { PageHeader } from '@/components/layout/PageHeader'
import { ScreenTabs } from '@/components/layout/ScreenTabs'
import { StatusBadge } from '@/components/status/StatusBadge'
import { Button } from '@/components/ui/button'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import { formatDateTime, formatRelative, humanize, maskPhone } from '@/lib/format'
import { usePage, useUrlState } from '@/lib/url-state'
import { useNow } from '@/lib/use-now'

import {
  safetyKeys,
  useIncidents,
  useResolveIncident,
  useSosAlerts,
  type IncidentStatus,
  type SosStatus,
} from './api'
import { SosDrawer } from './SosDrawer'
import { INCIDENT_STATUS, SEVERITY_TONE, SOS_STATUS } from './status'

function Tabs() {
  const { can } = useSession()
  return (
    <ScreenTabs
      label="Safety"
      tabs={[
        { to: '/safety', label: 'SOS alerts', show: can('sos:review'), end: true },
        { to: '/safety/incidents', label: 'Incidents', show: can('incidents:manage') },
      ].filter((tab) => tab.show)}
    />
  )
}

const SOS_FILTERS: { value: SosStatus | 'open' | 'all'; label: string }[] = [
  { value: 'open', label: 'Open (not yet resolved)' },
  { value: 'active', label: 'Not acknowledged' },
  { value: 'acknowledged', label: 'Acknowledged' },
  { value: 'resolved', label: 'Resolved' },
  { value: 'false_alarm', label: 'False alarms' },
  { value: 'all', label: 'All' },
]

type SosRow = Schemas['SosAlertResponse']

function SosPanel() {
  const [{ status, alert }, update] = useUrlState({ status: 'open', alert: '' })
  const { page, limit, setPage } = usePage()
  const filter = (SOS_FILTERS.find((option) => option.value === status)?.value ?? 'open') as
    SosStatus | 'open' | 'all'
  const list = useSosAlerts(filter, page, limit)
  const now = useNow(5000)
  // Open alerts are few: their details (who, which bus) fill in the queue.
  const openRows = (list.data?.items ?? [])
    .filter((row) => row.status === 'active' || row.status === 'acknowledged')
    .slice(0, 12)
  const details = useQueries({
    queries: openRows.map((row) => ({
      queryKey: safetyKeys.sosDetail(row.id),
      queryFn: () =>
        unwrap(
          api.GET('/api/v1/admin/sos-alerts/{alert_id}', {
            params: { path: { alert_id: row.id } },
          }),
        ),
    })),
  })
  const detailById = new Map(
    details.flatMap((result) => (result.data ? [[result.data.id, result.data] as const] : [])),
  )

  const columns: ColumnDef<SosRow, unknown>[] = [
    {
      header: 'Status',
      cell: ({ row }) => {
        const style = SOS_STATUS[row.original.status]
        return <StatusBadge tone={style.tone} label={style.label} icon={style.icon} />
      },
    },
    {
      header: 'Raised',
      cell: ({ row }) => (
        <div>
          <p className="font-medium">{formatRelative(row.original.created_at, now)}</p>
          <p className="text-xs text-muted-foreground">{formatDateTime(row.original.created_at)}</p>
        </div>
      ),
    },
    {
      header: 'Who and where',
      cell: ({ row }) => {
        const detail = detailById.get(row.original.id)
        return (
          <button
            type="button"
            className="text-left hover:underline focus-visible:underline focus-visible:outline-none"
            onClick={(event) => {
              event.stopPropagation()
              update({ alert: row.original.id }, { keepPage: true })
            }}
          >
            <span className="block font-medium">
              {detail?.triggered_by_name ?? (detail ? 'Unknown rider' : 'Open details')}
              {detail?.triggered_by_phone ? (
                <span className="font-normal text-muted-foreground">
                  {' '}
                  · {maskPhone(detail.triggered_by_phone)}
                </span>
              ) : null}
            </span>
            <span className="block text-xs text-muted-foreground">
              {detail?.trip
                ? `${detail.trip.route_name} · ${detail.trip.vehicle_registration_number ?? 'no vehicle'}`
                : row.original.trip_id
                  ? 'On a trip'
                  : 'Not on a trip'}
            </span>
          </button>
        )
      },
    },
  ]

  return (
    <div className="space-y-3">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <Select value={filter} onValueChange={(value) => update({ status: value })}>
          <SelectTrigger className="w-56" aria-label="Show SOS alerts">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            {SOS_FILTERS.map((option) => (
              <SelectItem key={option.value} value={option.value}>
                {option.label}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>
      <DataTable
        columns={columns}
        rows={list.data?.items}
        total={list.data?.total}
        getRowId={(row) => row.id}
        caption="SOS alerts"
        isPending={list.isPending}
        isError={list.isError}
        error={list.error}
        onRetry={() => void list.refetch()}
        isFetching={list.isFetching && !list.isPending}
        page={page}
        pageSize={filter === 'open' ? 100 : limit}
        onPageChange={filter === 'open' ? undefined : setPage}
        selectedId={alert || null}
        onRowClick={(row) => update({ alert: row.id }, { keepPage: true })}
        empty={
          <EmptyState
            icon={Siren}
            title={filter === 'open' ? 'No open SOS alerts' : 'No SOS alerts here'}
            description={
              filter === 'open' ? 'Every SOS has been dealt with.' : 'None match this filter.'
            }
          />
        }
      />
      <SosDrawer
        alertId={alert || null}
        onClose={() => update({ alert: null }, { keepPage: true })}
      />
    </div>
  )
}

const INCIDENT_FILTERS: { value: IncidentStatus | 'all'; label: string }[] = [
  { value: 'all', label: 'All incidents' },
  { value: 'reported', label: 'Reported' },
  { value: 'in_review', label: 'In review' },
  { value: 'resolved', label: 'Resolved' },
  { value: 'closed', label: 'Closed' },
]

type IncidentRow = Schemas['IncidentResponse']

function IncidentsPanel() {
  const [{ status }, update] = useUrlState({ status: 'all' })
  const { page, limit, setPage } = usePage()
  const filter = (INCIDENT_FILTERS.find((option) => option.value === status)?.value ?? 'all') as
    IncidentStatus | 'all'
  const list = useIncidents(filter, page, limit)
  const resolve = useResolveIncident()

  const columns: ColumnDef<IncidentRow, unknown>[] = [
    {
      header: 'Reported',
      cell: ({ row }) => (
        <span className="whitespace-nowrap">{formatDateTime(row.original.created_at)}</span>
      ),
    },
    {
      header: 'What happened',
      cell: ({ row }) => (
        <div className="max-w-md">
          <p className="font-medium">{humanize(row.original.incident_type)}</p>
          <p className="line-clamp-2 text-xs text-muted-foreground">{row.original.description}</p>
        </div>
      ),
    },
    {
      header: 'Severity',
      cell: ({ row }) => (
        <StatusBadge
          tone={SEVERITY_TONE[row.original.severity]}
          label={humanize(row.original.severity)}
        />
      ),
    },
    {
      header: 'Status',
      cell: ({ row }) => {
        const style = INCIDENT_STATUS[row.original.status]
        return <StatusBadge tone={style.tone} label={style.label} />
      },
    },
    {
      header: 'Trip',
      cell: ({ row }) => (
        <Link to={`/trips/${row.original.trip_id}`} className="link-inline text-sm">
          View trip
        </Link>
      ),
    },
    {
      id: 'actions',
      header: () => <span className="sr-only">Actions</span>,
      cell: ({ row }) =>
        row.original.status === 'reported' || row.original.status === 'in_review' ? (
          <ConfirmButton
            size="sm"
            variant="outline"
            icon={ShieldCheck}
            label="Resolve"
            title="Resolve this incident?"
            description="The note is kept with the incident."
            confirmLabel="Resolve"
            details={
              <ConfirmFacts
                rows={[
                  ['Incident', humanize(row.original.incident_type)],
                  ['Reported', formatDateTime(row.original.created_at)],
                ]}
              />
            }
            reason={{ label: 'Resolution note', required: true }}
            onConfirm={async (notes) => {
              await resolve.mutateAsync({ id: row.original.id, notes })
              toast.success('Incident resolved.')
            }}
          />
        ) : row.original.resolution_notes ? (
          <span className="line-clamp-2 max-w-48 text-xs text-muted-foreground">
            {row.original.resolution_notes}
          </span>
        ) : null,
    },
  ]

  return (
    <div className="space-y-3">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <Select value={filter} onValueChange={(value) => update({ status: value })}>
          <SelectTrigger className="w-48" aria-label="Show incidents">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            {INCIDENT_FILTERS.map((option) => (
              <SelectItem key={option.value} value={option.value}>
                {option.label}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
        <Button
          variant="outline"
          onClick={() =>
            downloadFile(
              '/api/v1/admin/incidents',
              { format: 'csv', incident_status: filter === 'all' ? undefined : filter },
              'incidents.csv',
            ).catch((error: unknown) => toast.error(errorMessage(error)))
          }
        >
          <Download aria-hidden /> Export CSV
        </Button>
      </div>
      <DataTable
        columns={columns}
        rows={list.data?.items}
        total={list.data?.total}
        getRowId={(row) => row.id}
        caption="Incidents reported on trips"
        isPending={list.isPending}
        isError={list.isError}
        error={list.error}
        onRetry={() => void list.refetch()}
        isFetching={list.isFetching && !list.isPending}
        page={page}
        pageSize={limit}
        onPageChange={setPage}
        empty={<EmptyState title="No incidents here" description="None match this filter." />}
      />
    </div>
  )
}

export default function SafetyPage() {
  const { can } = useSession()
  return (
    <div>
      <PageHeader
        title="Safety"
        description="SOS alerts from riders and drivers, and incidents reported on trips."
      />
      <Tabs />
      <Routes>
        <Route
          index
          element={can('sos:review') ? <SosPanel /> : <Navigate to="incidents" replace />}
        />
        <Route
          path="incidents"
          element={can('incidents:manage') ? <IncidentsPanel /> : <Navigate to="/safety" replace />}
        />
      </Routes>
    </div>
  )
}
