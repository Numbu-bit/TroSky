import { type ColumnDef } from '@tanstack/react-table'
import { ShieldCheck } from 'lucide-react'
import { useState } from 'react'
import { Link, useNavigate } from 'react-router'
import { toast } from 'sonner'

import { downloadFile } from '@/api/client'
import { errorMessage } from '@/api/errors'
import { useSession } from '@/app/auth/auth-context'
import { BarList } from '@/components/charts/BarList'
import { StatTile } from '@/components/charts/StatTile'
import { DataTable } from '@/components/data-table/DataTable'
import { EmptyState, ErrorState } from '@/components/feedback/states'
import { StatusBadge } from '@/components/status/StatusBadge'
import { Skeleton } from '@/components/ui/skeleton'
import { CsvButton, FilterRow, FilterSelect } from '@/features/fleet/Filters'
import { usePeriod } from '@/features/shared/period'
import { formatMoney, formatNumber, formatPercent, formatRelative } from '@/lib/format'
import { usePage, useUrlState } from '@/lib/url-state'
import { useNow } from '@/lib/use-now'
import { cn } from '@/lib/utils'

import { useFlags, useFraudStats, type Flag } from './api'
import { FLAG_STATUS, OPEN_FILTER, SEVERITY } from './labels'

export function RiskBadge({ score, severity }: { score: number; severity: Flag['severity'] }) {
  return (
    <span
      className={cn(
        'figure inline-flex min-w-9 justify-center rounded-md px-1.5 py-0.5 text-sm font-semibold',
        score >= 90
          ? 'bg-danger text-danger-foreground'
          : score >= 70
            ? 'bg-danger-soft text-danger-text'
            : score >= 50
              ? 'bg-warning-soft text-warning-text'
              : 'bg-muted',
      )}
      title={`Risk ${score} of 100 · ${SEVERITY[severity].label} severity`}
      role="img"
      aria-label={`Risk ${score} of 100, ${SEVERITY[severity].label.toLowerCase()} severity`}
    >
      {score}
    </span>
  )
}

function Figures() {
  const [period] = usePeriod()
  const stats = useFraudStats(period.from, period.to)
  if (stats.isPending) return <Skeleton className="mb-6 h-32" />
  if (stats.isError)
    return <ErrorState error={stats.error} onRetry={() => void stats.refetch()} className="mb-6" />
  const data = stats.data
  return (
    <section className="mb-6 space-y-4" aria-label="Fraud figures">
      <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-5">
        <StatTile
          label="Open now"
          value={formatNumber(data.open)}
          note="Open, or being looked into"
        />
        <StatTile
          label="High risk"
          value={formatNumber(data.high_risk)}
          note="Of those, risk 70 or more"
          tone={data.high_risk ? 'danger' : undefined}
        />
        <StatTile
          label="Money at risk"
          value={formatMoney(data.amount_at_risk)}
          note="Over the open flags"
        />
        <StatTile
          label={`Found, ${period.label.toLowerCase()}`}
          value={formatNumber(data.detected.value)}
          previous={formatNumber(data.detected.previous)}
          changePercent={data.detected.change_percent}
        />
        <StatTile
          label="Right when reviewed"
          value={data.precision.value === null ? '—' : formatPercent(data.precision.value)}
          previous={data.precision.previous === null ? '—' : formatPercent(data.precision.previous)}
          note={`${formatNumber(data.confirmed)} confirmed, ${formatNumber(data.false_positive)} false alarms`}
        />
      </div>
      <BarList
        title="Found by each rule"
        description={period.label}
        valueLabel="Flags"
        csvName={`fraud-by-rule-${period.from}`}
        isFetching={stats.isFetching}
        rows={data.by_rule.map((rule) => ({
          key: rule.rule,
          label: rule.rule_title,
          value: rule.detected,
          hint: `${rule.confirmed} confirmed · ${rule.false_positive} false alarms`,
        }))}
      />
    </section>
  )
}

/** What the fraud rules found, riskiest first, with who is looking into each. */
export function FlagsPanel() {
  const navigate = useNavigate()
  const { me } = useSession()
  const [period] = usePeriod()
  const stats = useFraudStats(period.from, period.to)
  const [filters, update] = useUrlState({
    status: OPEN_FILTER,
    severity: '',
    rule: '',
    risk: '',
    assigned: '',
    sort: '-risk_score',
  })
  const { page, limit, setPage } = usePage()
  const flags = useFlags(filters, page, me.id, limit)
  const now = useNow(60_000)
  const [downloading, setDownloading] = useState(false)

  const columns: ColumnDef<Flag, unknown>[] = [
    {
      header: 'Risk',
      cell: ({ row }) => (
        <RiskBadge score={row.original.risk_score} severity={row.original.severity} />
      ),
    },
    {
      header: 'What was found',
      cell: ({ row }) => (
        <div className="min-w-56">
          <Link
            to={`/fraud/${row.original.id}`}
            className="font-medium hover:underline"
            onClick={(event) => event.stopPropagation()}
          >
            {row.original.summary}
          </Link>
          <p className="text-xs text-muted-foreground">{row.original.rule_title}</p>
        </div>
      ),
    },
    {
      header: 'Who',
      cell: ({ row }) =>
        row.original.subject_name ?? <span className="text-muted-foreground">—</span>,
    },
    {
      header: 'At risk',
      meta: { align: 'right' },
      cell: ({ row }) =>
        row.original.amount_at_risk === null ? '—' : formatMoney(row.original.amount_at_risk),
    },
    {
      header: 'Status',
      cell: ({ row }) => {
        const status = FLAG_STATUS[row.original.status]
        return <StatusBadge tone={status.tone} label={status.label} icon={status.icon} />
      },
    },
    {
      header: 'With',
      cell: ({ row }) =>
        row.original.assignee_name ?? <span className="text-muted-foreground">Nobody yet</span>,
    },
    {
      header: 'Found',
      cell: ({ row }) => (
        <div className="whitespace-nowrap">
          <p>{formatRelative(row.original.first_detected_at, now)}</p>
          {row.original.occurrences > 1 ? (
            <p className="text-xs text-muted-foreground">
              {row.original.occurrences} times, last{' '}
              {formatRelative(row.original.last_detected_at, now)}
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
        '/api/v1/admin/fraud/flags',
        {
          format: 'csv',
          status: filters.status,
          severity: filters.severity,
          rule: filters.rule,
          min_risk: filters.risk,
          assigned_to: filters.assigned === 'me' ? me.id : undefined,
          unassigned: filters.assigned === 'none' ? true : undefined,
          sort: filters.sort,
        },
        'fraud-flags.csv',
      )
    } catch (error) {
      toast.error(errorMessage(error))
    } finally {
      setDownloading(false)
    }
  }

  return (
    <>
      <Figures />
      <FilterRow>
        <FilterSelect
          label="Status"
          value={filters.status}
          onChange={(status) => update({ status })}
          options={[
            { value: OPEN_FILTER, label: 'Open, or being looked into' },
            ...(Object.keys(FLAG_STATUS) as (keyof typeof FLAG_STATUS)[]).map((value) => ({
              value,
              label: FLAG_STATUS[value].label,
            })),
          ]}
          any="Any status"
        />
        <FilterSelect
          label="Risk"
          value={filters.risk}
          onChange={(risk) => update({ risk })}
          options={[
            { value: '50', label: '50 or more' },
            { value: '70', label: '70 or more (high)' },
            { value: '90', label: '90 or more' },
          ]}
          any="Any risk"
        />
        <FilterSelect
          label="Rule"
          value={filters.rule}
          onChange={(rule) => update({ rule })}
          options={(stats.data?.by_rule ?? []).map((rule) => ({
            value: rule.rule,
            label: rule.rule_title,
          }))}
          any="Any rule"
        />
        <FilterSelect
          label="With"
          value={filters.assigned}
          onChange={(assigned) => update({ assigned })}
          options={[
            { value: 'me', label: 'Me' },
            { value: 'none', label: 'Nobody yet' },
          ]}
          any="Anyone"
        />
        <FilterSelect
          label="Order"
          value={filters.sort}
          onChange={(sort) => update({ sort })}
          options={[
            { value: '-risk_score', label: 'Riskiest first' },
            { value: '-first_detected_at', label: 'Newest first' },
            { value: '-last_detected_at', label: 'Seen again most recently' },
            { value: '-amount_at_risk', label: 'Most money at risk' },
          ]}
        />
        <CsvButton onClick={() => void download()} busy={downloading} />
      </FilterRow>
      <DataTable
        columns={columns}
        rows={flags.data?.items}
        total={flags.data?.total}
        getRowId={(row) => row.id}
        caption="Fraud flags"
        isPending={flags.isPending}
        isError={flags.isError}
        error={flags.error}
        onRetry={() => void flags.refetch()}
        isFetching={flags.isFetching && !flags.isPending}
        page={page}
        pageSize={limit}
        onPageChange={setPage}
        onRowClick={(row) => navigate(`/fraud/${row.id}`)}
        empty={
          <EmptyState
            icon={ShieldCheck}
            title="Nothing flagged"
            description="No flag matches these filters."
          />
        }
      />
    </>
  )
}
