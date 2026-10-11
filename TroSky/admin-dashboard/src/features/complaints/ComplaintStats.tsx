import { type ReactNode } from 'react'

import type { Schemas } from '@/api/types'
import { ErrorState } from '@/components/feedback/states'
import { Skeleton } from '@/components/ui/skeleton'
import { formatNumber } from '@/lib/format'
import { cn } from '@/lib/utils'

import { useComplaintStats } from './api'
import { CATEGORY, PRIORITY } from './labels'

type Stats = Schemas['ComplaintStatsResponse']

function Tile({
  label,
  value,
  note,
  tone,
  onClick,
  active,
}: {
  label: string
  value: ReactNode
  note?: ReactNode
  tone?: 'danger'
  onClick?: () => void
  active?: boolean
}) {
  const body = (
    <>
      <p className={cn('text-sm text-muted-foreground', tone && 'text-danger-text')}>{label}</p>
      <p className="figure mt-1 text-2xl">{value}</p>
      {note ? <p className="mt-1 text-xs text-muted-foreground">{note}</p> : null}
    </>
  )
  const style = cn(
    'rounded-xl border bg-card p-4 text-left shadow-xs',
    tone && 'border-danger bg-danger-soft',
    active && 'border-brand ring-1 ring-brand',
  )
  return onClick ? (
    <button
      type="button"
      onClick={onClick}
      aria-pressed={active}
      className={cn(
        style,
        'transition-colors hover:border-brand focus-visible:ring-2 focus-visible:ring-ring focus-visible:outline-none',
      )}
    >
      {body}
    </button>
  ) : (
    <div className={style}>{body}</div>
  )
}

const hours = (value: string | null) =>
  value === null ? '—' : `${formatNumber(value, { decimals: true })} h`

function compared(figure: Schemas['Compared'], unit: (value: string | null) => string) {
  return figure.previous === null ? 'Nothing before to compare' : `Before: ${unit(figure.previous)}`
}

function ByCategory({ stats }: { stats: Stats }) {
  const most = Math.max(1, ...stats.by_category.flatMap((row) => [row.filed, row.previous]))
  return (
    <table className="w-full text-sm">
      <caption className="mb-2 text-left text-sm font-semibold">Filed by category</caption>
      <thead className="sr-only">
        <tr>
          <th scope="col">Category</th>
          <th scope="col">This period</th>
          <th scope="col">Period before</th>
        </tr>
      </thead>
      <tbody>
        {stats.by_category.map((row) => (
          <tr key={row.category}>
            <th scope="row" className="w-36 py-1 pr-2 text-left font-normal">
              {CATEGORY[row.category]}
            </th>
            <td className="py-1">
              <div className="flex items-center gap-2">
                <div
                  className="h-2.5 rounded-full bg-chart-1"
                  style={{ width: `${(row.filed / most) * 100}%` }}
                  aria-hidden
                />
                <span className="figure">{formatNumber(row.filed)}</span>
              </div>
            </td>
            <td className="figure w-24 py-1 text-right text-muted-foreground">
              before {formatNumber(row.previous)}
            </td>
          </tr>
        ))}
      </tbody>
    </table>
  )
}

function ByPriority({ stats }: { stats: Stats }) {
  return (
    <table className="w-full text-sm">
      <caption className="mb-2 text-left text-sm font-semibold">Open now, by priority</caption>
      <thead>
        <tr className="text-left text-xs text-muted-foreground">
          <th scope="col" className="py-1 font-normal">
            Priority
          </th>
          <th scope="col" className="py-1 text-right font-normal">
            Due within
          </th>
          <th scope="col" className="py-1 text-right font-normal">
            Open
          </th>
          <th scope="col" className="py-1 text-right font-normal">
            Overdue
          </th>
          <th scope="col" className="py-1 text-right font-normal">
            Unassigned
          </th>
        </tr>
      </thead>
      <tbody className="figure">
        {stats.by_priority.map((row) => (
          <tr key={row.priority} className="border-t">
            <th scope="row" className="py-1 text-left font-normal">
              {PRIORITY[row.priority].label}
            </th>
            <td className="py-1 text-right">{row.resolution_hours} h</td>
            <td className="py-1 text-right">{formatNumber(row.open)}</td>
            <td className={cn('py-1 text-right', row.overdue && 'font-semibold text-danger-text')}>
              {formatNumber(row.overdue)}
            </td>
            <td className="py-1 text-right">{formatNumber(row.unassigned)}</td>
          </tr>
        ))}
      </tbody>
    </table>
  )
}

/**
 * The complaints module's figures: what is open and overdue now (the tiles
 * filter the list), and how the last 30 days were handled.
 */
export function ComplaintStats({
  filter,
  onFilter,
}: {
  filter: { overdue: string; assigned: string }
  onFilter: (patch: { overdue?: string | null; assigned?: string | null; status?: string }) => void
}) {
  // No dates: the API's default, the 30 days to today.
  const stats = useComplaintStats(true)
  if (stats.isPending) return <Skeleton className="mb-6 h-40" />
  if (stats.isError) {
    return <ErrorState error={stats.error} onRetry={() => void stats.refetch()} className="mb-6" />
  }
  const data = stats.data
  return (
    <section className="mb-6 space-y-4" aria-label="Complaint figures">
      <div className="grid gap-3 sm:grid-cols-3 xl:grid-cols-6">
        <Tile
          label="Open now"
          value={formatNumber(data.open)}
          note="Open or in review"
          onClick={() => onFilter({ overdue: null, assigned: null, status: 'open,in_review' })}
          active={!filter.overdue && !filter.assigned}
        />
        <Tile
          label="Overdue"
          value={formatNumber(data.overdue)}
          note="Past their due time"
          tone={data.overdue ? 'danger' : undefined}
          onClick={() => onFilter({ overdue: 'yes', assigned: null, status: 'open,in_review' })}
          active={filter.overdue === 'yes'}
        />
        <Tile
          label="Unassigned"
          value={formatNumber(data.unassigned)}
          note="Nobody has it yet"
          onClick={() => onFilter({ assigned: 'none', overdue: null, status: 'open,in_review' })}
          active={filter.assigned === 'none'}
        />
        <Tile
          label="Filed, last 30 days"
          value={formatNumber(data.filed.value)}
          note={`Before: ${formatNumber(data.filed.previous)}`}
        />
        <Tile
          label="First response"
          value={hours(data.avg_first_response_hours.value)}
          note={compared(data.avg_first_response_hours, hours)}
        />
        <Tile
          label="Time to decide"
          value={hours(data.avg_resolution_hours.value)}
          note={compared(data.avg_resolution_hours, hours)}
        />
      </div>
      <div className="grid gap-6 rounded-xl border bg-card p-4 lg:grid-cols-2">
        <ByPriority stats={data} />
        <div className="space-y-2">
          <ByCategory stats={data} />
          <p className="text-xs text-muted-foreground">
            {data.per_1000_trips.value === null
              ? 'No completed trips to compare against.'
              : `${formatNumber(data.per_1000_trips.value, { decimals: true })} complaints per 1,000 completed trips (before: ${data.per_1000_trips.previous === null ? '—' : formatNumber(data.per_1000_trips.previous, { decimals: true })}).`}
          </p>
        </div>
      </div>
    </section>
  )
}
