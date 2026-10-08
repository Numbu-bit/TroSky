import type { ReactNode } from 'react'

import { ChartCard } from '@/components/charts/ChartCard'
import { formatMoney, formatNumber, formatPercent } from '@/lib/format'

export interface BarRow {
  key: string
  label: string
  value: number
  /** A second line under the label, e.g. "143 payments". */
  hint?: string
  /** Where clicking the label goes. */
  link?: ReactNode
}

type Unit = 'count' | 'money' | 'ratio'

function formatUnit(unit: Unit, value: number): string {
  return unit === 'money'
    ? formatMoney(value)
    : unit === 'ratio'
      ? formatPercent(value)
      : formatNumber(value)
}

/**
 * A ranked list as horizontal bars (no chart library needed): one colour,
 * the value beside each bar, with a table view and CSV like every chart.
 */
export function BarList({
  title,
  description,
  rows,
  unit = 'count',
  valueLabel,
  csvName,
  isFetching,
  empty = 'Nothing in this period.',
  className,
}: {
  title: string
  description?: ReactNode
  rows: BarRow[]
  unit?: Unit
  valueLabel: string
  csvName: string
  isFetching?: boolean
  empty?: string
  className?: string
}) {
  const most = Math.max(...rows.map((row) => row.value), 0) || 1
  return (
    <ChartCard
      title={title}
      description={description}
      rows={rows}
      csvName={csvName}
      isFetching={isFetching}
      className={className}
      columns={[
        { key: 'label', label: title, value: (row) => row.label },
        {
          key: 'value',
          label: valueLabel,
          value: (row) => formatUnit(unit, row.value),
          align: 'right',
        },
        ...(rows.some((row) => row.hint)
          ? [{ key: 'hint', label: 'Notes', value: (row: BarRow) => row.hint ?? '' }]
          : []),
      ]}
    >
      {rows.length ? (
        <ul className="space-y-2.5" aria-label={title}>
          {rows.map((row) => (
            <li
              key={row.key}
              className="grid grid-cols-[minmax(7rem,12rem)_1fr_auto] items-center gap-3 text-sm"
            >
              <span className="min-w-0">
                <span className="block truncate">{row.link ?? row.label}</span>
                {row.hint ? (
                  <span className="block truncate text-xs text-muted-foreground">{row.hint}</span>
                ) : null}
              </span>
              <span className="h-3 rounded-full bg-muted" aria-hidden>
                <span
                  className="block h-3 rounded-full bg-chart-1"
                  style={{ width: `${Math.max(2, (row.value / most) * 100)}%` }}
                />
              </span>
              <span className="figure text-right">{formatUnit(unit, row.value)}</span>
            </li>
          ))}
        </ul>
      ) : (
        <p className="py-6 text-center text-sm text-muted-foreground">{empty}</p>
      )}
    </ChartCard>
  )
}
