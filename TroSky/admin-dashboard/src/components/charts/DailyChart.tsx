import { CartesianGrid, Line, LineChart, XAxis, YAxis } from 'recharts'

import { ChartCard } from '@/components/charts/ChartCard'
import {
  ChartContainer,
  ChartTooltip,
  ChartTooltipContent,
  type ChartConfig,
} from '@/components/ui/chart'
import { formatDate, formatDayMonth, formatMoney, formatNumber } from '@/lib/format'

export interface SeriesPoint {
  date: string
  value: number
}

/** One figure, day by day: a single series, in Emerald. */
export function DailyChart({
  title,
  description,
  points,
  money,
  isFetching,
  csvName,
}: {
  title: string
  description: string
  points: SeriesPoint[]
  money: boolean
  isFetching?: boolean
  csvName: string
}) {
  const config = { value: { label: title, color: 'var(--chart-1)' } } satisfies ChartConfig
  const format = (value: number) => (money ? formatMoney(value) : formatNumber(value))
  return (
    <ChartCard
      title={title}
      description={description}
      rows={points}
      csvName={csvName}
      isFetching={isFetching}
      columns={[
        { key: 'date', label: 'Date', value: (row) => formatDate(row.date) },
        { key: 'value', label: title, value: (row) => format(row.value), align: 'right' },
      ]}
    >
      <ChartContainer config={config} className="aspect-auto h-64 w-full">
        <LineChart data={points} margin={{ left: 8, right: 12, top: 8 }}>
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
            width={money ? 84 : 48}
            tickFormatter={(value: number) =>
              money ? formatMoney(value).replace(/\.00$/, '') : formatNumber(value)
            }
          />
          <ChartTooltip
            cursor={{ strokeWidth: 1 }}
            content={
              <ChartTooltipContent
                labelFormatter={(value) => formatDate(String(value))}
                formatter={(value) => <span className="figure">{format(Number(value))}</span>}
              />
            }
          />
          <Line
            dataKey="value"
            type="monotone"
            stroke="var(--color-value)"
            strokeWidth={2}
            dot={false}
            isAnimationActive={false}
          />
        </LineChart>
      </ChartContainer>
    </ChartCard>
  )
}
