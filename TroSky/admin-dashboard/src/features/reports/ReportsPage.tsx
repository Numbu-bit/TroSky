import { keepPreviousData, useQuery } from '@tanstack/react-query'
import { FileSpreadsheet, Printer } from 'lucide-react'
import { useState } from 'react'
import { Link } from 'react-router'
import { toast } from 'sonner'

import { api, downloadFile, unwrap } from '@/api/client'
import { errorMessage } from '@/api/errors'
import type { Schemas } from '@/api/types'
import { useSession } from '@/app/auth/auth-context'
import { ErrorState, TableSkeleton } from '@/components/feedback/states'
import { PageHeader } from '@/components/layout/PageHeader'
import { Button } from '@/components/ui/button'
import { useFleets } from '@/features/fleet/api'
import { CsvButton, FilterSelect } from '@/features/fleet/Filters'
import { useRoutes } from '@/features/shared/reference'
import { usePeriod } from '@/features/shared/period'
import { PeriodControls } from '@/features/shared/PeriodControls'
import { formatDate, formatMoney, formatNumber, formatPercent } from '@/lib/format'
import { isModuleEnabled } from '@/lib/modules'
import { useUrlState } from '@/lib/url-state'
import { cn } from '@/lib/utils'
import { saveBlob, toXlsx, type CellKind } from '@/lib/xlsx'

type ReportName = Schemas['ReportResponse']['report']
type Column = Schemas['ReportColumnResponse']
type Granularity = 'day' | 'week' | 'month'

/** The SRS §17 reports the API serves (driver performance has its own module). */
const REPORTS: { value: ReportName; label: string; series: boolean }[] = [
  { value: 'daily_rides', label: 'Daily rides', series: true },
  { value: 'revenue', label: 'Revenue', series: true },
  { value: 'peak_hours', label: 'Peak hours', series: false },
  { value: 'route_popularity', label: 'Route popularity', series: false },
  { value: 'passenger_growth', label: 'Passenger growth', series: true },
  { value: 'cancellation_rates', label: 'Cancellation rates', series: true },
]

/** A cell as the column's kind says: dates, hours, counts, cedis, shares. */
function show(value: unknown, column: Column, granularity: Granularity | null): string {
  if (value === null || value === undefined || value === '') return '—'
  switch (column.kind) {
    case 'period': {
      const date = String(value)
      if (granularity === 'month') {
        return new Date(`${date}T12:00:00Z`).toLocaleDateString('en-GB', {
          month: 'long',
          year: 'numeric',
          timeZone: 'Africa/Accra',
        })
      }
      return granularity === 'week' ? `Week of ${formatDate(date)}` : formatDate(date)
    }
    case 'hour':
      return `${String(value).padStart(2, '0')}:00`
    case 'count':
      return formatNumber(Number(value))
    case 'money':
      return formatMoney(String(value))
    case 'ratio':
      return formatPercent(String(value))
    default:
      return String(value)
  }
}

const SHEET_KIND: Record<Column['kind'], CellKind> = {
  period: 'text',
  hour: 'text',
  text: 'text',
  count: 'count',
  money: 'money',
  ratio: 'ratio',
}

/** The reports, on screen and as CSV, Excel or PDF (printed from the browser). */
export default function ReportsPage() {
  const { can } = useSession()
  const [period] = usePeriod()
  const [filters, update] = useUrlState({
    report: 'daily_rides',
    granularity: 'day',
    route: '',
    fleet: '',
  })
  const report = REPORTS.find((option) => option.value === filters.report) ?? REPORTS[0]!
  const granularity = (
    ['day', 'week', 'month'].includes(filters.granularity) ? filters.granularity : 'day'
  ) as Granularity
  const routes = useRoutes()
  const seesFleets = can('vehicles:approve', 'reports:view')
  const fleets = useFleets({ owner: '', q: '', sort: 'fleet_name' }, 1, 100, seesFleets)
  const [downloading, setDownloading] = useState(false)
  const query = {
    from: period.from,
    to: period.to,
    city: period.city || undefined,
    route: filters.route || undefined,
    fleet: filters.fleet || undefined,
    granularity,
  }
  const result = useQuery({
    queryKey: ['reports', report.value, query],
    queryFn: () =>
      unwrap(
        api.GET('/api/v1/admin/reports/{report}', {
          params: { path: { report: report.value }, query },
        }),
      ),
    placeholderData: keepPreviousData,
  })
  const data = result.data
  const fileName = `${report.value.replace(/_/g, '-')}-${period.from}-${period.to}`

  async function downloadCsv() {
    setDownloading(true)
    try {
      await downloadFile(
        `/api/v1/admin/reports/${report.value}`,
        { ...query, format: 'csv' },
        `${fileName}.csv`,
      )
    } catch (error) {
      toast.error(errorMessage(error))
    } finally {
      setDownloading(false)
    }
  }

  function downloadXlsx() {
    if (!data) return
    const rows = data.rows.map((row) =>
      data.columns.map((column) => {
        const value = (row as Record<string, unknown>)[column.key]
        if (value === null || value === undefined) return null
        return column.kind === 'period' || column.kind === 'hour'
          ? show(value, column, data.granularity ?? null)
          : (value as string | number)
      }),
    )
    const totals = data.columns.map((column, index) =>
      index === 0
        ? 'Total'
        : (((data.totals as Record<string, unknown>)[column.key] as
            string | number | null | undefined) ?? null),
    )
    saveBlob(
      toXlsx(
        data.title,
        data.columns.map((column) => ({ label: column.label, kind: SHEET_KIND[column.kind] })),
        [...rows, totals],
      ),
      `${fileName}.xlsx`,
    )
  }

  return (
    <>
      <PageHeader
        title="Reports"
        description={`${period.label}${period.city ? ` · ${period.city}` : ''}.`}
        actions={
          <div data-print="hide">
            <PeriodControls />
          </div>
        }
      />
      <div
        className="mb-4 grid gap-3 sm:grid-cols-2 lg:grid-cols-[repeat(auto-fit,minmax(11rem,1fr))] lg:items-end"
        role="group"
        aria-label="Report"
        data-print="hide"
      >
        <FilterSelect
          label="Report"
          value={report.value}
          onChange={(value) => update({ report: value ?? 'daily_rides' })}
          options={REPORTS.map((option) => ({ value: option.value, label: option.label }))}
        />
        {report.series ? (
          <FilterSelect
            label="Rows per"
            value={granularity}
            onChange={(value) => update({ granularity: value ?? 'day' })}
            options={[
              { value: 'day', label: 'Day' },
              { value: 'week', label: 'Week (from Monday)' },
              { value: 'month', label: 'Month' },
            ]}
          />
        ) : null}
        <FilterSelect
          label="Route"
          value={filters.route}
          onChange={(route) => update({ route })}
          options={(routes.data?.items ?? []).map((route) => ({
            value: route.id,
            label: route.name,
          }))}
          any="Every route"
        />
        {seesFleets ? (
          <FilterSelect
            label="Fleet"
            value={filters.fleet}
            onChange={(fleet) => update({ fleet })}
            options={(fleets.data?.items ?? []).map((fleet) => ({
              value: fleet.id,
              label: fleet.name,
            }))}
            any="Every fleet"
          />
        ) : null}
        <div className="flex flex-wrap gap-2">
          <CsvButton onClick={() => void downloadCsv()} busy={downloading} />
          <Button variant="outline" onClick={downloadXlsx} disabled={!data}>
            <FileSpreadsheet aria-hidden /> Excel
          </Button>
          <Button variant="outline" onClick={() => window.print()} disabled={!data}>
            <Printer aria-hidden /> PDF
          </Button>
        </div>
      </div>
      {isModuleEnabled('driver-performance') && can('reports:view', 'drivers:approve') ? (
        <p className="mb-4 text-sm text-muted-foreground" data-print="hide">
          The driver performance report is in{' '}
          <Link to="/driver-performance" className="link-inline">
            Driver performance
          </Link>
          , with its own CSV.
        </p>
      ) : null}
      {result.isPending ? (
        <TableSkeleton rows={8} columns={6} />
      ) : result.isError ? (
        <ErrorState error={result.error} onRetry={() => void result.refetch()} />
      ) : data ? (
        <section
          aria-label={data.title}
          className={cn('space-y-3 transition-opacity', result.isFetching && 'opacity-60')}
        >
          <h2 className="text-lg font-semibold">{data.title}</h2>
          <div className="overflow-x-auto rounded-lg border bg-card">
            <table className="w-full text-sm">
              <caption className="sr-only">{data.title}</caption>
              <thead>
                <tr className="border-b text-left">
                  {data.columns.map((column) => (
                    <th
                      key={column.key}
                      scope="col"
                      className={cn(
                        'px-3 py-2 font-medium whitespace-nowrap',
                        ['count', 'money', 'ratio'].includes(column.kind) && 'text-right',
                        column.key === 'route_id' && 'hidden',
                      )}
                    >
                      {column.label}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody className="figure">
                {data.rows.map((row, position) => (
                  <tr key={position} className="border-b last:border-0">
                    {data.columns.map((column) => (
                      <td
                        key={column.key}
                        className={cn(
                          'px-3 py-1.5 whitespace-nowrap',
                          ['count', 'money', 'ratio'].includes(column.kind) && 'text-right',
                          column.key === 'route_id' && 'hidden',
                        )}
                      >
                        {show(
                          (row as Record<string, unknown>)[column.key],
                          column,
                          data.granularity ?? null,
                        )}
                      </td>
                    ))}
                  </tr>
                ))}
              </tbody>
              <tfoot className="figure border-t-2 font-semibold">
                <tr>
                  {data.columns.map((column, index) => (
                    <td
                      key={column.key}
                      className={cn(
                        'px-3 py-2 whitespace-nowrap',
                        ['count', 'money', 'ratio'].includes(column.kind) && 'text-right',
                        column.key === 'route_id' && 'hidden',
                      )}
                    >
                      {index === 0
                        ? 'Total'
                        : column.key in data.totals
                          ? show((data.totals as Record<string, unknown>)[column.key], column, null)
                          : ''}
                    </td>
                  ))}
                </tr>
              </tfoot>
            </table>
          </div>
          {data.notes.length ? (
            <ul className="list-disc space-y-1 pl-5 text-xs text-muted-foreground">
              {data.notes.map((note) => (
                <li key={note}>{note}</li>
              ))}
            </ul>
          ) : null}
        </section>
      ) : null}
    </>
  )
}
