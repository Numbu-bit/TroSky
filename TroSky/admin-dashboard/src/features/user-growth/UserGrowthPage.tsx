import { useQuery, keepPreviousData } from '@tanstack/react-query'
import { ArrowRight } from 'lucide-react'

import { api, unwrap } from '@/api/client'
import type { Schemas } from '@/api/types'
import { BarList } from '@/components/charts/BarList'
import { ChartCard } from '@/components/charts/ChartCard'
import { DailyChart } from '@/components/charts/DailyChart'
import { heatStyle } from '@/components/charts/heat'
import { SeriesChart } from '@/components/charts/SeriesChart'
import { StatTile } from '@/components/charts/StatTile'
import { ErrorState } from '@/components/feedback/states'
import { PageHeader } from '@/components/layout/PageHeader'
import { Skeleton } from '@/components/ui/skeleton'
import { ROLE_NAMES } from '@/features/accounts/labels'
import { usePeriod } from '@/features/shared/period'
import { PeriodControls } from '@/features/shared/PeriodControls'
import { formatDate, formatNumber, formatPercent } from '@/lib/format'

const STAGES: Record<string, string> = {
  searches: 'Searched',
  reserved: 'Reserved a seat',
  paid: 'Paid',
  boarded: 'Boarded',
}

function useUsers(from: string, to: string) {
  return useQuery({
    queryKey: ['user-growth', from, to],
    queryFn: () =>
      unwrap(api.GET('/api/v1/admin/analytics/users', { params: { query: { from, to } } })),
    placeholderData: keepPreviousData,
  })
}

function useFunnel(from: string, to: string, city: string) {
  return useQuery({
    queryKey: ['funnel', from, to, city],
    queryFn: () =>
      unwrap(
        api.GET('/api/v1/admin/analytics/funnel', {
          params: { query: { from, to, city: city || undefined } },
        }),
      ),
    placeholderData: keepPreviousData,
  })
}

const pct = (value: string | null) => (value === null ? '—' : formatPercent(value))

function Funnel({
  data,
  isFetching,
  csvName,
}: {
  data: Schemas['FunnelResponse']
  isFetching: boolean
  csvName: string
}) {
  const top = data.stages[0]?.value || 1
  return (
    <ChartCard
      title="From search to boarding"
      description="Searches, then bookings made in the period: reserved, paid, boarded (ticket scanned)"
      rows={data.stages}
      csvName={csvName}
      isFetching={isFetching}
      columns={[
        { key: 'stage', label: 'Stage', value: (row) => STAGES[row.stage] ?? row.stage },
        {
          key: 'value',
          label: 'This period',
          value: (row) => formatNumber(row.value),
          align: 'right',
        },
        {
          key: 'conversion',
          label: 'Of the stage before',
          value: (row) => pct(row.conversion),
          align: 'right',
        },
        {
          key: 'previous',
          label: 'Period before',
          value: (row) => formatNumber(row.previous),
          align: 'right',
        },
        {
          key: 'previous_conversion',
          label: 'Of the stage before, then',
          value: (row) => pct(row.previous_conversion),
          align: 'right',
        },
      ]}
    >
      <ol className="space-y-3" aria-label="Funnel stages">
        {data.stages.map((stage) => (
          <li key={stage.stage} className="space-y-1">
            <div className="flex flex-wrap items-baseline justify-between gap-2 text-sm">
              <span className="font-medium">{STAGES[stage.stage] ?? stage.stage}</span>
              <span className="figure">
                {formatNumber(stage.value)}
                {stage.conversion !== null ? (
                  <span className="ml-2 text-xs text-muted-foreground">
                    <ArrowRight className="inline size-3" aria-hidden />{' '}
                    {formatPercent(stage.conversion)} of the stage before
                    {stage.previous_conversion !== null
                      ? ` (before: ${formatPercent(stage.previous_conversion)})`
                      : ''}
                  </span>
                ) : null}
              </span>
            </div>
            <div className="h-3 rounded-full bg-muted" aria-hidden>
              <div
                className="h-3 rounded-full bg-chart-1"
                style={{ width: `${Math.max(1, (stage.value / top) * 100)}%` }}
              />
            </div>
          </li>
        ))}
      </ol>
    </ChartCard>
  )
}

function Cohorts({ cohorts, csvName }: { cohorts: Schemas['CohortResponse'][]; csvName: string }) {
  const weeks = Math.max(0, ...cohorts.map((cohort) => cohort.retention_rates.length))
  return (
    <ChartCard
      title="Who came back"
      description="People who joined each week, and the share active in each week after"
      rows={cohorts}
      csvName={csvName}
      columns={[
        { key: 'week', label: 'Week joined', value: (row) => formatDate(row.week) },
        { key: 'size', label: 'Joined', value: (row) => formatNumber(row.size), align: 'right' },
        ...Array.from({ length: weeks }, (_, week) => ({
          key: `week_${week + 1}`,
          label: `Week ${week + 1}`,
          value: (row: Schemas['CohortResponse']) =>
            row.retention_rates[week] === undefined
              ? ''
              : formatPercent(row.retention_rates[week]!),
          align: 'right' as const,
        })),
      ]}
    >
      {cohorts.length ? (
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <caption className="sr-only">Retention by the week people joined</caption>
            <thead>
              <tr className="text-xs text-muted-foreground">
                <th scope="col" className="py-1 pr-2 text-left font-normal">
                  Week joined
                </th>
                <th scope="col" className="py-1 pr-2 text-right font-normal">
                  Joined
                </th>
                {Array.from({ length: weeks }, (_, week) => (
                  <th key={week} scope="col" className="px-1 py-1 text-center font-normal">
                    Wk {week + 1}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody className="figure">
              {cohorts.map((cohort) => (
                <tr key={cohort.week}>
                  <th scope="row" className="py-0.5 pr-2 text-left font-normal">
                    {formatDate(cohort.week)}
                  </th>
                  <td className="py-0.5 pr-2 text-right">{formatNumber(cohort.size)}</td>
                  {Array.from({ length: weeks }, (_, week) => {
                    const rate = cohort.retention_rates[week]
                    return (
                      <td key={week} className="p-0.5">
                        {rate === undefined ? null : (
                          <span
                            className="block rounded px-1 py-1 text-center text-xs"
                            style={heatStyle(Number(rate))}
                          >
                            {formatPercent(rate)}
                          </span>
                        )}
                      </td>
                    )
                  })}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      ) : (
        <p className="py-6 text-center text-sm text-muted-foreground">
          Nobody joined in this period.
        </p>
      )}
    </ChartCard>
  )
}

/** Sign-ups, who is active, who books after joining, and who comes back. */
export default function UserGrowthPage() {
  const [period] = usePeriod()
  const users = useUsers(period.from, period.to)
  const funnel = useFunnel(period.from, period.to, period.city)
  const data = users.data
  return (
    <>
      <PageHeader
        title="User growth"
        description={`${period.label}. Active: signed in or made a booking that day. The city applies to the funnel.`}
        actions={<PeriodControls />}
      />
      {users.isPending ? (
        <Skeleton className="h-72" />
      ) : users.isError ? (
        <ErrorState error={users.error} onRetry={() => void users.refetch()} />
      ) : data ? (
        <div className="space-y-6">
          <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-5">
            <StatTile
              label="New users"
              value={formatNumber(data.new_users.value)}
              previous={formatNumber(data.new_users.previous)}
              changePercent={data.new_users.change_percent}
            />
            <StatTile
              label="Active a day, on average"
              value={data.average_daily_active.value ?? '—'}
              previous={data.average_daily_active.previous ?? '—'}
            />
            <StatTile
              label="Active in the last week"
              value={data.weekly_active.value ?? '—'}
              previous={data.weekly_active.previous ?? '—'}
            />
            <StatTile
              label="Active in the last 30 days"
              value={data.monthly_active.value ?? '—'}
              previous={data.monthly_active.previous ?? '—'}
            />
            <StatTile
              label="Booked within a week of joining"
              value={pct(data.activation.rate)}
              previous={pct(data.activation.previous_rate)}
              note={`${formatNumber(data.activation.activated)} of ${formatNumber(data.activation.signed_up)} new passengers`}
            />
          </div>
          <div className="grid gap-6 xl:grid-cols-2">
            <SeriesChart
              title="Sign-ups by role"
              description="Day by day"
              isFetching={users.isFetching}
              csvName={`signups-${period.from}-${period.to}`}
              series={data.signups_by_role.map((role) => ({
                key: role.role,
                label: ROLE_NAMES[role.role] ?? role.role,
                points: role.series,
              }))}
            />
            <DailyChart
              title="Active users"
              description="Signed in or booked, day by day"
              points={data.daily_active}
              money={false}
              isFetching={users.isFetching}
              csvName={`active-users-${period.from}-${period.to}`}
            />
            <DailyChart
              title="Users in all"
              description="Accounts at the end of each day"
              points={data.cumulative_users}
              money={false}
              isFetching={users.isFetching}
              csvName={`total-users-${period.from}-${period.to}`}
            />
            {funnel.data ? (
              <Funnel
                data={funnel.data}
                isFetching={funnel.isFetching}
                csvName={`funnel-${period.from}-${period.to}`}
              />
            ) : funnel.isError ? (
              <ErrorState error={funnel.error} onRetry={() => void funnel.refetch()} />
            ) : (
              <Skeleton className="h-64" />
            )}
          </div>
          <Cohorts cohorts={data.cohorts} csvName={`cohorts-${period.from}-${period.to}`} />
          <BarList
            title="Travellers by city"
            description="Passengers with a paid booking, by where their trip started"
            rows={data.travellers_by_city.map((row) => ({
              key: row.city,
              label: row.city,
              value: row.users,
            }))}
            valueLabel="Passengers"
            csvName={`travellers-by-city-${period.from}`}
          />
        </div>
      ) : null}
    </>
  )
}
