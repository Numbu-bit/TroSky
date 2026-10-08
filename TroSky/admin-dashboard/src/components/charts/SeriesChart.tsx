import { CartesianGrid, Line, LineChart, XAxis, YAxis } from 'recharts'

import { ChartCard } from '@/components/charts/ChartCard'
import {
  ChartContainer,
  ChartLegend,
  ChartLegendContent,
  ChartTooltip,
  ChartTooltipContent,
  type ChartConfig,
} from '@/components/ui/chart'
import { formatDate, formatDayMonth, formatMoney, formatNumber, formatPercent } from '@/lib/format'

export interface Series {
  key: string
  label: string
  /** Day by day. */
  points: { date: string; value: number }[]
}

type Unit = 'count' | 'money' | 'ratio'

const PALETTE = [
  'var(--chart-1)',
  'var(--chart-2)',
  'var(--chart-3)',
  'var(--chart-4)',
  'var(--chart-5)',
  'var(--chart-6)',
]

function formatter(unit: Unit) {
  return (value: number) =>
    unit === 'money'
      ? formatMoney(value)
      : unit === 'ratio'
        ? formatPercent(value)
        : formatNumber(value)
}

/**
 * Several figures, day by day, on one axis (never two). Colours follow the
 * series in a fixed order; past six they fold into "Other".
 */
export function SeriesChart({
  title,
  description,
  series,
  unit = 'count',
  isFetching,
  csvName,
}: {
  title: string
  description?: string
  series: Series[]
  unit?: Unit
  isFetching?: boolean
  csvName: string
}) {
  const shown = series.length > 6 ? series.slice(0, 5) : series
  const folded: Series[] =
    series.length > 6
      ? [
          ...shown,
          {
            key: 'other',
            label: 'Other',
            points: series[0]!.points.map((point, position) => ({
              date: point.date,
              value: series
                .slice(5)
                .reduce((sum, item) => sum + (item.points[position]?.value ?? 0), 0),
            })),
          },
        ]
      : shown
  const dates = folded[0]?.points.map((point) => point.date) ?? []
  const rows = dates.map((date, position) => ({
    date,
    ...Object.fromEntries(folded.map((item) => [item.key, item.points[position]?.value ?? 0])),
  })) as ({ date: string } & Record<string, number>)[]
  const config = Object.fromEntries(
    folded.map((item, position) => [
      item.key,
      { label: item.label, color: item.key === 'other' ? 'var(--chart-other)' : PALETTE[position] },
    ]),
  ) satisfies ChartConfig
  const format = formatter(unit)
  return (
    <ChartCard
      title={title}
      description={description}
      rows={rows}
      csvName={csvName}
      isFetching={isFetching}
      columns={[
        { key: 'date', label: 'Date', value: (row) => formatDate(row.date) },
        ...folded.map((item) => ({
          key: item.key,
          label: item.label,
          value: (row: (typeof rows)[number]) => format(row[item.key] ?? 0),
          align: 'right' as const,
        })),
      ]}
    >
      <ChartContainer config={config} className="aspect-auto h-64 w-full">
        <LineChart data={rows} margin={{ left: 8, right: 12, top: 8 }}>
          <CartesianGrid vertical={false} strokeWidth={0.5} />
          <XAxis
            dataKey="date"
            tickLine={false}
            axisLine={false}
            minTickGap={24}
            tickFormatter={(value: string) => formatDayMonth(value)}
          />
          <YAxis
            tickLine={false}
            axisLine={false}
            width={unit === 'money' ? 84 : 48}
            tickFormatter={(value: number) => format(value).replace(/\.00$/, '')}
          />
          <ChartTooltip
            cursor={{ strokeWidth: 1 }}
            content={
              <ChartTooltipContent
                labelFormatter={(value) => formatDate(String(value))}
                formatter={(value, name) => (
                  <span className="flex w-full justify-between gap-3">
                    <span>{config[String(name)]?.label ?? name}</span>
                    <span className="figure">{format(Number(value))}</span>
                  </span>
                )}
              />
            }
          />
          {folded.length > 1 ? <ChartLegend content={<ChartLegendContent />} /> : null}
          {folded.map((item) => (
            <Line
              key={item.key}
              dataKey={item.key}
              type="monotone"
              stroke={`var(--color-${item.key})`}
              strokeWidth={2}
              dot={false}
              isAnimationActive={false}
            />
          ))}
        </LineChart>
      </ChartContainer>
    </ChartCard>
  )
}
