import {
  ArrowDownRight,
  ArrowRight,
  ArrowUpRight,
  Bus,
  ChevronRight,
  Siren,
  type LucideIcon,
} from 'lucide-react'
import { Link } from 'react-router'

import type { Schemas } from '@/api/types'
import { useSession } from '@/app/auth/auth-context'
import { canOpen, screenByKey } from '@/app/screens'
import { alertLink, SEVERITY_TONE } from '@/features/alerts/links'
import { EmptyState, QueryState } from '@/components/feedback/states'
import { WidgetBoundary } from '@/components/feedback/WidgetBoundary'
import { PageHeader, Section } from '@/components/layout/PageHeader'
import { StatusBadge } from '@/components/status/StatusBadge'
import { Card, CardContent } from '@/components/ui/card'
import { Skeleton } from '@/components/ui/skeleton'
import { useLiveTrips } from '@/features/live-map/api'
import { formatMoney, formatNumber, formatRelative } from '@/lib/format'
import { useUrlState } from '@/lib/url-state'
import { cn } from '@/lib/utils'

import { useAlertsFeed, useOverview, useQueueCounts } from './api'
import { DailyChart } from '@/components/charts/DailyChart'
import { usePeriod } from '@/features/shared/period'
import { PeriodControls } from '@/features/shared/PeriodControls'

type FigureKey = keyof Schemas['OverviewFiguresResponse']

const FIGURES: { key: FigureKey; label: string; money?: boolean }[] = [
  { key: 'paid_bookings', label: 'Paid bookings' },
  { key: 'booking_payments', label: 'Booking payments', money: true },
  { key: 'completed_trips', label: 'Completed trips' },
  { key: 'new_users', label: 'New users' },
  { key: 'new_passengers', label: 'New passengers' },
  { key: 'new_drivers', label: 'New drivers' },
  { key: 'complaints', label: 'Complaints filed' },
  { key: 'sos_alerts', label: 'SOS alerts raised' },
]

type Figure = Schemas['CountFigure'] | Schemas['MoneyFigure']

function FigureTile({
  label,
  figure,
  money,
  period,
  selected,
  onSelect,
}: {
  label: string
  figure: Figure
  money?: boolean
  period: string
  selected: boolean
  onSelect: () => void
}) {
  const change = figure.change_percent === null ? null : Number(figure.change_percent)
  const Arrow =
    change === null || change === 0 ? ArrowRight : change > 0 ? ArrowUpRight : ArrowDownRight
  const show = (value: string | number) => (money ? formatMoney(value) : formatNumber(value))
  return (
    <button
      type="button"
      onClick={onSelect}
      aria-pressed={selected}
      className={cn(
        'rounded-xl border bg-card p-4 text-left shadow-xs transition-colors hover:border-brand focus-visible:ring-2 focus-visible:ring-ring focus-visible:outline-none',
        selected && 'border-brand ring-1 ring-brand',
      )}
    >
      <p className="text-sm text-muted-foreground">{label}</p>
      <p className="figure mt-1 text-2xl text-foreground">{show(figure.value)}</p>
      <p className="mt-1 text-xs text-muted-foreground">{period}</p>
      <p className="mt-2 flex items-center gap-1 text-xs">
        {change === null ? (
          <span className="text-muted-foreground">Previous period: {show(figure.previous)}</span>
        ) : (
          <>
            <Arrow className="size-3.5" aria-hidden />
            <span className="figure">{`${change > 0 ? '+' : ''}${figure.change_percent}%`}</span>
            <span className="text-muted-foreground">
              vs previous period ({show(figure.previous)})
            </span>
          </>
        )}
      </p>
    </button>
  )
}

function PeriodFigures() {
  const [period] = usePeriod()
  const [{ figure: chosen }, update] = useUrlState({ figure: 'paid_bookings' })
  const overview = useOverview({ from: period.from, to: period.to, city: period.city }, true)
  return (
    <QueryState
      query={overview}
      skeleton={
        <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
          {FIGURES.map((figure) => (
            <Skeleton key={figure.key} className="h-32" />
          ))}
        </div>
      }
    >
      {(data) => {
        const shown = FIGURES.filter((figure) => data.figures[figure.key])
        const selected = shown.find((figure) => figure.key === chosen) ?? shown[0]
        const series = selected ? data.figures[selected.key] : null
        return (
          <div className="space-y-4">
            <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
              {shown.map((figure) => (
                <FigureTile
                  key={figure.key}
                  label={figure.label}
                  money={figure.money}
                  figure={data.figures[figure.key]!}
                  period={period.label + (period.city ? ` · ${period.city}` : '')}
                  selected={figure.key === selected?.key}
                  onSelect={() => update({ figure: figure.key }, { keepPage: true })}
                />
              ))}
            </div>
            {selected && series ? (
              <DailyChart
                title={`${selected.label} per day`}
                description={`${period.label}${period.city ? ` · ${period.city}` : ''}`}
                money={Boolean(selected.money)}
                points={series.series.map((point) => ({
                  date: point.date,
                  value: Number(point.value),
                }))}
                isFetching={overview.isFetching}
                csvName={`${selected.key}-${data.period.from_date}-${data.period.to_date}`}
              />
            ) : null}
            <AllTime data={data} />
          </div>
        )
      }}
    </QueryState>
  )
}

function AllTime({ data }: { data: Schemas['PlatformOverviewResponse'] }) {
  const rows: [string, string][] = [
    ['Users', formatNumber(data.total_users)],
    ['Passengers', formatNumber(data.total_passengers)],
    ['Drivers', formatNumber(data.total_drivers)],
    ['Fleet owners', formatNumber(data.total_fleet_owners)],
    ['Bookings', formatNumber(data.total_bookings)],
    ['Completed bookings', formatNumber(data.completed_bookings)],
    ['Revenue collected', formatMoney(data.total_revenue)],
  ]
  return (
    <Card className="py-4">
      <CardContent>
        <h3 className="mb-3 text-sm font-semibold">All time</h3>
        <dl className="grid grid-cols-2 gap-x-6 gap-y-3 sm:grid-cols-4 xl:grid-cols-7">
          {rows.map(([label, value]) => (
            <div key={label}>
              <dt className="text-xs text-muted-foreground">{label}</dt>
              <dd className="figure text-lg">{value}</dd>
            </div>
          ))}
        </dl>
      </CardContent>
    </Card>
  )
}

function LiveTile({
  label,
  value,
  to,
  icon: Icon,
  tone,
  pending,
  error,
}: {
  label: string
  value: number | undefined
  to: string
  icon?: LucideIcon
  tone?: 'danger'
  pending?: boolean
  error?: boolean
}) {
  return (
    <Link
      to={to}
      className={cn(
        'group flex items-center justify-between gap-3 rounded-xl border bg-card p-4 shadow-xs hover:border-brand focus-visible:ring-2 focus-visible:ring-ring focus-visible:outline-none',
        tone === 'danger' && value ? 'border-danger bg-danger-soft' : null,
      )}
    >
      <div className="min-w-0">
        <p
          className={cn(
            'text-sm text-muted-foreground',
            tone === 'danger' && value ? 'text-danger-text' : null,
          )}
        >
          {label}
        </p>
        {pending ? (
          <Skeleton className="mt-1 h-7 w-12" />
        ) : (
          <p className="figure text-2xl">{error ? '—' : formatNumber(value ?? 0)}</p>
        )}
      </div>
      {Icon ? <Icon className="size-5 text-muted-foreground" aria-hidden /> : null}
      <ChevronRight
        className="size-4 text-muted-foreground group-hover:text-foreground"
        aria-hidden
      />
    </Link>
  )
}

function LiveTiles() {
  const { can } = useSession()
  const seesBuses = can('trips:monitor_live', 'trips:manage')
  const buses = useLiveTrips(seesBuses)
  const queues = useQueueCounts()
  const onTheRoad = buses.data?.filter((trip) => trip.status !== 'boarding').length
  if (!seesBuses && queues.length === 0) return null
  return (
    <Section title="Right now" description="Live counts. Each opens its screen.">
      <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
        {seesBuses ? (
          <LiveTile
            label="Buses on the road"
            value={onTheRoad}
            to="/live"
            icon={Bus}
            pending={buses.isPending}
            error={buses.isError}
          />
        ) : null}
        {queues.map(({ queue, result }) => (
          <LiveTile
            key={queue.key}
            label={queue.label}
            value={result.data}
            to={queue.to}
            icon={queue.urgent ? Siren : undefined}
            tone={queue.urgent ? 'danger' : undefined}
            pending={result.isPending}
            error={result.isError}
          />
        ))}
      </div>
    </Section>
  )
}

function AlertsList() {
  const { permissions } = useSession()
  const enabled = canOpen(screenByKey('alerts'), permissions)
  const feed = useAlertsFeed(enabled)
  if (!enabled) return null
  return (
    <Section
      title="Needs attention"
      description="SOS first, then by severity."
      actions={
        <Link to="/alerts" className="link-inline text-sm font-medium">
          All alerts
        </Link>
      }
    >
      <QueryState
        query={feed}
        isEmpty={(data) => data.items.length === 0}
        empty={
          <EmptyState
            title="Nothing needs attention"
            description="No open SOS, overdue complaints, expiring documents or waiting approvals."
          />
        }
      >
        {(data) => (
          <ul className="divide-y rounded-xl border bg-card">
            {data.items.map((alert) => (
              <li key={`${alert.type}-${alert.entity_id}`}>
                <Link
                  to={alertLink(alert)}
                  className="flex flex-wrap items-center gap-3 px-4 py-3 hover:bg-accent focus-visible:bg-accent focus-visible:outline-none"
                >
                  <StatusBadge
                    tone={SEVERITY_TONE[alert.severity] ?? 'neutral'}
                    label={alert.severity}
                  />
                  <span className="min-w-0 flex-1 truncate text-sm font-medium">{alert.title}</span>
                  <span className="text-xs text-muted-foreground">
                    {formatRelative(alert.since)}
                  </span>
                </Link>
              </li>
            ))}
          </ul>
        )}
      </QueryState>
    </Section>
  )
}

export default function OverviewPage() {
  const { can, me } = useSession()
  const figures = can('reports:view')
  return (
    <div className="space-y-6">
      <PageHeader
        title="Overview"
        description={`Akwaaba, ${me.full_name?.split(' ')[0] ?? 'admin'}. Here is the platform today.`}
        actions={figures ? <PeriodControls /> : null}
      />
      <WidgetBoundary title="Live counts failed">
        <LiveTiles />
      </WidgetBoundary>
      <WidgetBoundary title="Alerts failed">
        <AlertsList />
      </WidgetBoundary>
      {figures ? (
        <Section
          title="Platform figures"
          description="From the platform overview report, for the period chosen above."
        >
          <WidgetBoundary title="Figures failed">
            <PeriodFigures />
          </WidgetBoundary>
        </Section>
      ) : null}
    </div>
  )
}
