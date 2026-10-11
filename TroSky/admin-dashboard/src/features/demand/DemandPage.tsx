import { keepPreviousData, useQuery } from '@tanstack/react-query'
import { lazy, Suspense, useId } from 'react'

import { api, unwrap } from '@/api/client'
import type { Schemas } from '@/api/types'
import { BarList } from '@/components/charts/BarList'
import { ChartCard } from '@/components/charts/ChartCard'
import { heatStyle } from '@/components/charts/heat'
import { StatTile } from '@/components/charts/StatTile'
import { ErrorState } from '@/components/feedback/states'
import { PageHeader, Section } from '@/components/layout/PageHeader'
import { Label } from '@/components/ui/label'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import { Skeleton } from '@/components/ui/skeleton'
import { ToggleGroup, ToggleGroupItem } from '@/components/ui/toggle-group'
import { usePeriod } from '@/features/shared/period'
import { PeriodControls } from '@/features/shared/PeriodControls'
import { formatNumber, formatPercent } from '@/lib/format'
import { useUrlState } from '@/lib/url-state'

const DemandHeatMap = lazy(() => import('./DemandHeatMap'))

type Kind = 'searches' | 'unmet' | 'bookings'
const KINDS: { value: Kind; label: string; unit: string }[] = [
  { value: 'searches', label: 'Searches', unit: 'searches' },
  { value: 'unmet', label: 'Found nothing', unit: 'unmet searches' },
  { value: 'bookings', label: 'Seats booked', unit: 'seats' },
]
const DAYS = [
  ['mon', 'Mon'],
  ['tue', 'Tue'],
  ['wed', 'Wed'],
  ['thu', 'Thu'],
  ['fri', 'Fri'],
  ['sat', 'Sat'],
  ['sun', 'Sun'],
] as const
const HOURS = Array.from({ length: 24 }, (_, hour) => String(hour))

function DayHourGrid({ data, csvName }: { data: Schemas['DemandResponse']; csvName: string }) {
  const most = Math.max(1, ...data.by_day_and_hour.flatMap((day) => day.hours))
  const label = (day: string) => DAYS.find(([key]) => key === day)?.[1] ?? day
  return (
    <ChartCard
      title="By day and hour"
      description="Ghana time; darker means more"
      rows={data.by_day_and_hour}
      csvName={csvName}
      columns={[
        { key: 'day', label: 'Day', value: (row) => label(row.day) },
        ...HOURS.map((hour) => ({
          key: `h${hour}`,
          label: `${hour.padStart(2, '0')}:00`,
          value: (row: Schemas['DemandDay']) => row.hours[Number(hour)] ?? 0,
          align: 'right' as const,
        })),
      ]}
    >
      <div className="overflow-x-auto">
        <table className="w-full min-w-160 text-xs">
          <caption className="sr-only">Demand by day of the week and hour of the day</caption>
          <thead>
            <tr className="text-muted-foreground">
              <th scope="col" className="w-10 font-normal" />
              {HOURS.map((hour) => (
                <th key={hour} scope="col" className="font-normal">
                  {Number(hour) % 3 === 0 ? (
                    hour.padStart(2, '0')
                  ) : (
                    <span className="sr-only">{hour}</span>
                  )}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {data.by_day_and_hour.map((day) => (
              <tr key={day.day}>
                <th scope="row" className="pr-1 text-left font-normal text-muted-foreground">
                  {label(day.day)}
                </th>
                {day.hours.map((value, hour) => (
                  <td key={hour} className="p-px">
                    <span
                      className="block h-6 rounded-sm"
                      style={heatStyle(value / most)}
                      title={`${label(day.day)} ${String(hour).padStart(2, '0')}:00: ${formatNumber(value)}`}
                    >
                      <span className="sr-only">{formatNumber(value)}</span>
                    </span>
                  </td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </ChartCard>
  )
}

/** Where and when people want to travel, and where they found nothing. */
export default function DemandPage() {
  const [period] = usePeriod()
  const [filters, update] = useUrlState({ type: 'searches', days: '', hour_from: '', hour_to: '' })
  const kind = (KINDS.find((option) => option.value === filters.type)?.value ?? 'searches') as Kind
  const unit = KINDS.find((option) => option.value === kind)!.unit
  const days = filters.days ? filters.days.split(',') : []
  const fromId = useId()
  const toId = useId()
  const demand = useQuery({
    queryKey: [
      'demand',
      kind,
      period.from,
      period.to,
      period.city,
      filters.days,
      filters.hour_from,
      filters.hour_to,
    ],
    queryFn: () =>
      unwrap(
        api.GET('/api/v1/admin/analytics/demand', {
          params: {
            query: {
              type: kind,
              from: period.from,
              to: period.to,
              city: period.city || undefined,
              days: filters.days || undefined,
              hour_from: filters.hour_from ? Number(filters.hour_from) : undefined,
              hour_to: filters.hour_to ? Number(filters.hour_to) : undefined,
            },
          },
        }),
      ),
    placeholderData: keepPreviousData,
  })
  const data = demand.data
  const csv = `${kind}-${period.from}-${period.to}`

  return (
    <>
      <PageHeader
        title="Demand map"
        description={`${period.label}${period.city ? ` · ${period.city}` : ''}. Where people searched, where they found no bus with a free seat, and where seats were booked.`}
        actions={<PeriodControls />}
      />
      <div className="mb-4 flex flex-wrap items-end gap-4" role="group" aria-label="What and when">
        <div className="grid gap-1.5">
          <span className="text-sm font-medium">Show</span>
          <ToggleGroup
            type="single"
            variant="outline"
            value={kind}
            onValueChange={(value) => value && update({ type: value })}
            aria-label="What to show"
          >
            {KINDS.map((option) => (
              <ToggleGroupItem key={option.value} value={option.value}>
                {option.label}
              </ToggleGroupItem>
            ))}
          </ToggleGroup>
        </div>
        <div className="grid gap-1.5">
          <span className="text-sm font-medium">Days</span>
          <ToggleGroup
            type="multiple"
            variant="outline"
            value={days}
            onValueChange={(value: string[]) =>
              update({
                days:
                  value.length && value.length < 7
                    ? DAYS.map(([key]) => key)
                        .filter((key) => value.includes(key))
                        .join(',')
                    : null,
              })
            }
            aria-label="Days of the week"
          >
            {DAYS.map(([key, label]) => (
              <ToggleGroupItem key={key} value={key} aria-label={label}>
                {label.slice(0, 2)}
              </ToggleGroupItem>
            ))}
          </ToggleGroup>
        </div>
        {(
          [
            [fromId, 'From hour', 'hour_from'],
            [toId, 'To hour', 'hour_to'],
          ] as const
        ).map(([id, label, key]) => (
          <div key={key} className="grid gap-1.5">
            <Label htmlFor={id}>{label}</Label>
            <Select
              value={filters[key] || 'any'}
              onValueChange={(value) => update({ [key]: value === 'any' ? null : value })}
            >
              <SelectTrigger id={id} className="w-28">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="any">Any</SelectItem>
                {HOURS.map((hour) => (
                  <SelectItem key={hour} value={hour}>
                    {hour.padStart(2, '0')}:00
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
        ))}
      </div>
      {demand.isPending ? (
        <Skeleton className="h-112" />
      ) : demand.isError ? (
        <ErrorState error={demand.error} onRetry={() => void demand.refetch()} />
      ) : data ? (
        <div className="space-y-6">
          <div className="grid gap-3 sm:grid-cols-3">
            <StatTile
              label={`${KINDS.find((option) => option.value === kind)!.label} in the period`}
              value={formatNumber(data.total)}
              previous={formatNumber(data.previous_total)}
              changePercent={data.change_percent}
            />
            <StatTile
              label="Places shown"
              value={formatNumber(data.cells.length)}
              note="Cells about 550 m across"
            />
            <StatTile
              label="Kept back"
              value={formatNumber(data.withheld)}
              note="In places with too few to show without singling anyone out"
            />
          </div>
          <Suspense fallback={<Skeleton className="h-112" />}>
            <DemandHeatMap cells={data.cells} label={`Heat map of ${unit}`} />
          </Suspense>
          <div className="grid gap-6 xl:grid-cols-2">
            <BarList
              title="Busiest pickup stops"
              rows={data.top_origins.map((stop) => ({
                key: stop.stop_id,
                label: stop.name,
                value: stop.weight,
                hint: stop.city ?? undefined,
              }))}
              valueLabel={unit}
              csvName={`top-origins-${csv}`}
              isFetching={demand.isFetching}
            />
            <BarList
              title="Busiest journeys"
              rows={data.top_pairs.map((pair) => ({
                key: `${pair.origin_stop_id}-${pair.destination_stop_id}`,
                label: `${pair.origin_name} → ${pair.destination_name}`,
                value: pair.weight,
              }))}
              valueLabel={unit}
              csvName={`top-journeys-${csv}`}
              isFetching={demand.isFetching}
            />
          </div>
          <DayHourGrid data={data} csvName={`by-day-and-hour-${csv}`} />
          <Section
            title="Where searches found nothing"
            description="Pickup stops where searches most often found no bus with a free seat: the supply gaps."
          >
            {data.supply_gaps.length ? (
              <div className="overflow-x-auto rounded-lg border bg-card">
                <table className="w-full text-sm">
                  <caption className="sr-only">Supply gaps</caption>
                  <thead>
                    <tr className="border-b text-left text-muted-foreground">
                      <th scope="col" className="px-3 py-2 font-medium">
                        Stop
                      </th>
                      <th scope="col" className="px-3 py-2 text-right font-medium">
                        Searches
                      </th>
                      <th scope="col" className="px-3 py-2 text-right font-medium">
                        Found nothing
                      </th>
                      <th scope="col" className="px-3 py-2 text-right font-medium">
                        Share
                      </th>
                    </tr>
                  </thead>
                  <tbody className="figure">
                    {data.supply_gaps.map((gap) => (
                      <tr key={gap.stop_id} className="border-b last:border-0">
                        <th scope="row" className="px-3 py-2 text-left font-normal">
                          {gap.name}
                          {gap.city ? (
                            <span className="text-muted-foreground"> · {gap.city}</span>
                          ) : null}
                        </th>
                        <td className="px-3 py-2 text-right">{formatNumber(gap.searches)}</td>
                        <td className="px-3 py-2 text-right">{formatNumber(gap.unmet)}</td>
                        <td className="px-3 py-2 text-right font-medium">
                          {formatPercent(gap.unmet_share)}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            ) : (
              <p className="text-sm text-muted-foreground">No stop stands out in this period.</p>
            )}
          </Section>
        </div>
      ) : null}
    </>
  )
}
