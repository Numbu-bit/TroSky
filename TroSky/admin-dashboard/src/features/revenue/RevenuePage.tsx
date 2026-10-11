import { useQuery } from '@tanstack/react-query'
import { type ColumnDef } from '@tanstack/react-table'
import { Receipt, Search } from 'lucide-react'
import { useEffect, useId, useState } from 'react'
import { Link, useLocation } from 'react-router'
import { toast } from 'sonner'

import { api, downloadFile, unwrap } from '@/api/client'
import { errorMessage } from '@/api/errors'
import { useSession } from '@/app/auth/auth-context'
import { BarList } from '@/components/charts/BarList'
import { SeriesChart } from '@/components/charts/SeriesChart'
import { StatTile } from '@/components/charts/StatTile'
import { DataTable } from '@/components/data-table/DataTable'
import { EmptyState, ErrorState } from '@/components/feedback/states'
import { PageHeader, Section } from '@/components/layout/PageHeader'
import { StatusBadge } from '@/components/status/StatusBadge'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Skeleton } from '@/components/ui/skeleton'
import { CsvButton, FilterRow, FilterSelect } from '@/features/fleet/Filters'
import { CHANNEL_LABELS, PAYMENT_STATUS, type Channel } from '@/features/shared/money'
import { usePeriod } from '@/features/shared/period'
import { PeriodControls } from '@/features/shared/PeriodControls'
import {
  accraDateKey,
  formatDateTime,
  formatMoney,
  formatNumber,
  formatPercent,
  maskPhone,
} from '@/lib/format'
import { usePage, useUrlState } from '@/lib/url-state'
import { useDebounced } from '@/lib/use-debounced'

import { usePayments, useRevenue, type AdminPayment } from './api'

function Transactions({ period }: { period: { from: string; to: string; city: string } }) {
  const { can } = useSession()
  const [filters, update] = useUrlState({
    method: '',
    status: '',
    purpose: '',
    sort: '-created_at',
  })
  const { page, limit, setPage } = usePage()
  // A reference or a phone number: personal data, so not in the address.
  // The global search hands a payment's reference over in the page state.
  const location = useLocation()
  const [text, setText] = useState(
    () => (location.state as { search?: string } | null)?.search ?? '',
  )
  const q = useDebounced(text, 300)
  const payments = usePayments(period, filters, q, page, limit)
  const [downloading, setDownloading] = useState(false)
  const searchId = useId()

  const columns: ColumnDef<AdminPayment, unknown>[] = [
    {
      header: 'When',
      cell: ({ row }) => (
        <span className="whitespace-nowrap">{formatDateTime(row.original.created_at)}</span>
      ),
    },
    {
      header: 'Reference',
      cell: ({ row }) => (
        <div>
          <p className="figure">{row.original.reference}</p>
          {row.original.booking ? (
            can('bookings:view_any') ? (
              <Link
                to={`/bookings?booking=${row.original.booking.id}`}
                className="figure link-inline text-xs"
              >
                {row.original.booking.reference}
              </Link>
            ) : (
              <p className="figure text-xs text-muted-foreground">
                {row.original.booking.reference}
              </p>
            )
          ) : (
            <p className="text-xs text-muted-foreground">Wallet top-up</p>
          )}
        </div>
      ),
    },
    {
      header: 'Paid by',
      cell: ({ row }) => (
        <div>
          <p>{row.original.payer.name ?? '—'}</p>
          <p className="figure text-xs text-muted-foreground">
            {maskPhone(row.original.payer.phone_number)}
          </p>
        </div>
      ),
    },
    { header: 'Method', cell: ({ row }) => CHANNEL_LABELS[row.original.method] },
    { header: 'Route', cell: ({ row }) => row.original.route_name ?? '—' },
    {
      header: 'Amount',
      meta: { align: 'right' },
      cell: ({ row }) => formatMoney(row.original.amount),
    },
    {
      header: 'Fee',
      meta: { align: 'right' },
      cell: ({ row }) =>
        row.original.platform_fee === null ? '—' : formatMoney(row.original.platform_fee),
    },
    {
      header: 'Status',
      cell: ({ row }) => (
        <div className="space-y-0.5">
          <StatusBadge
            tone={PAYMENT_STATUS[row.original.status].tone}
            label={PAYMENT_STATUS[row.original.status].label}
          />
          {Number(row.original.refunded_amount) > 0 ? (
            <p className="text-xs text-muted-foreground">
              {formatMoney(row.original.refunded_amount)} refunded
            </p>
          ) : null}
          {row.original.failure_reason ? (
            <p className="max-w-48 text-xs text-danger-text">{row.original.failure_reason}</p>
          ) : null}
        </div>
      ),
    },
  ]

  async function download() {
    setDownloading(true)
    try {
      await downloadFile(
        '/api/v1/admin/payments',
        {
          format: 'csv',
          from: period.from,
          to: period.to,
          city: period.city,
          method: filters.method,
          status: filters.status,
          purpose: filters.purpose,
          q: q.trim(),
          sort: filters.sort,
        },
        `payments-${period.from}-${period.to}.csv`,
      )
    } catch (error) {
      toast.error(errorMessage(error))
    } finally {
      setDownloading(false)
    }
  }

  return (
    <Section title="Transactions" description="Every payment in the period.">
      <FilterRow>
        <div className="grid gap-1.5">
          <Label htmlFor={searchId}>Find</Label>
          <div className="relative">
            <Search
              className="pointer-events-none absolute top-2.5 left-2.5 size-4 text-muted-foreground"
              aria-hidden
            />
            <Input
              id={searchId}
              type="search"
              className="pl-8"
              value={text}
              autoComplete="off"
              placeholder="Reference or phone"
              onChange={(event) => {
                setText(event.target.value)
                setPage(1)
              }}
            />
          </div>
        </div>
        <FilterSelect
          label="Method"
          value={filters.method}
          onChange={(method) => update({ method })}
          options={(Object.keys(CHANNEL_LABELS) as Channel[]).map((value) => ({
            value,
            label: CHANNEL_LABELS[value],
          }))}
          any="Any method"
        />
        <FilterSelect
          label="Status"
          value={filters.status}
          onChange={(status) => update({ status })}
          options={(Object.keys(PAYMENT_STATUS) as (keyof typeof PAYMENT_STATUS)[]).map(
            (value) => ({ value, label: PAYMENT_STATUS[value].label }),
          )}
          any="Any status"
        />
        <FilterSelect
          label="For"
          value={filters.purpose}
          onChange={(purpose) => update({ purpose })}
          options={[
            { value: 'booking_payment', label: 'Bookings' },
            { value: 'wallet_topup', label: 'Wallet top-ups' },
          ]}
          any="Anything"
        />
        <FilterSelect
          label="Order"
          value={filters.sort}
          onChange={(sort) => update({ sort })}
          options={[
            { value: '-created_at', label: 'Newest first' },
            { value: 'created_at', label: 'Oldest first' },
            { value: '-amount', label: 'Largest first' },
            { value: 'status', label: 'Status' },
          ]}
        />
        <CsvButton onClick={() => void download()} busy={downloading} />
      </FilterRow>
      <DataTable
        columns={columns}
        rows={payments.data?.items}
        total={payments.data?.total}
        getRowId={(row) => row.id}
        caption="Payments"
        isPending={payments.isPending}
        isError={payments.isError}
        error={payments.error}
        onRetry={() => void payments.refetch()}
        isFetching={payments.isFetching && !payments.isPending}
        page={page}
        pageSize={limit}
        onPageChange={setPage}
        empty={
          <EmptyState
            icon={Receipt}
            title="No payments match"
            description="Try another period or filter."
          />
        }
      />
    </Section>
  )
}

/**
 * A payment handed over by the global search may be older than the
 * period shown: move the period to its day (when the admin may read it).
 */
function usePaymentPeriod(
  period: { from: string; to: string },
  update: ReturnType<typeof usePeriod>[1],
) {
  const { can } = useSession()
  const location = useLocation()
  const paymentId = (location.state as { payment?: string } | null)?.payment ?? null
  const payment = useQuery({
    queryKey: ['payment', paymentId],
    queryFn: () =>
      unwrap(
        api.GET('/api/v1/payments/{payment_id}', {
          params: { path: { payment_id: paymentId! } },
        }),
      ),
    enabled: Boolean(paymentId) && can('payments:review'),
  })
  const day = payment.data ? accraDateKey(payment.data.created_at) : null
  useEffect(() => {
    if (day && (day < period.from || day > period.to)) {
      update({ days: 'custom', from: day, to: day })
    }
  }, [day, period.from, period.to, update])
}

/** What came in, what went back out, and where it came from. */
export default function RevenuePage() {
  const [period, updatePeriod] = usePeriod()
  usePaymentPeriod(period, updatePeriod)
  const revenue = useRevenue(period.from, period.to, period.city)
  const data = revenue.data
  const money = (figure: { value: string; previous: string; change_percent: string | null }) => ({
    value: formatMoney(figure.value),
    previous: formatMoney(figure.previous),
    changePercent: figure.change_percent,
  })
  return (
    <>
      <PageHeader
        title="Revenue"
        description={`${period.label}${period.city ? ` · ${period.city}` : ''}. Payments by when they were collected; refunds by when they were paid out.`}
        actions={<PeriodControls />}
      />
      {revenue.isPending ? (
        <Skeleton className="h-72" />
      ) : revenue.isError ? (
        <ErrorState error={revenue.error} onRetry={() => void revenue.refetch()} />
      ) : data ? (
        <div className="space-y-6">
          <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
            <StatTile label="Gross" {...money(data.gross)} />
            <StatTile label="Refunds paid" {...money(data.refunds)} />
            <StatTile label="Net" {...money(data.net)} />
            <StatTile label="Platform fees" {...money(data.platform_fees)} />
            <StatTile
              label="Paid bookings"
              value={formatNumber(data.paid_bookings.value)}
              previous={formatNumber(data.paid_bookings.previous)}
              changePercent={data.paid_bookings.change_percent}
            />
            <StatTile
              label="Average fare"
              value={data.average_fare.value === null ? '—' : formatMoney(data.average_fare.value)}
              previous={
                data.average_fare.previous === null ? '—' : formatMoney(data.average_fare.previous)
              }
            />
            <StatTile
              label="Failed payments"
              value={
                data.failed_payment_rate.value === null
                  ? '—'
                  : formatPercent(data.failed_payment_rate.value)
              }
              previous={
                data.failed_payment_rate.previous === null
                  ? '—'
                  : formatPercent(data.failed_payment_rate.previous)
              }
              note="Of the booking payments started"
            />
            <StatTile
              label="Payouts waiting"
              value={formatMoney(data.pending_withdrawals.amount)}
              note={`${formatNumber(data.pending_withdrawals.count)} requests, now`}
            />
          </div>
          <SeriesChart
            title="Money in and out"
            description="Day by day"
            unit="money"
            isFetching={revenue.isFetching}
            csvName={`revenue-${period.from}-${period.to}`}
            series={[
              {
                key: 'gross',
                label: 'Gross',
                points: data.gross.series.map((point) => ({
                  date: point.date,
                  value: Number(point.value),
                })),
              },
              {
                key: 'refunds',
                label: 'Refunds',
                points: data.refunds.series.map((point) => ({
                  date: point.date,
                  value: Number(point.value),
                })),
              },
              {
                key: 'net',
                label: 'Net',
                points: data.net.series.map((point) => ({
                  date: point.date,
                  value: Number(point.value),
                })),
              },
            ]}
          />
          <div className="grid gap-6 xl:grid-cols-2">
            <BarList
              title="By payment method"
              unit="money"
              valueLabel="Collected"
              isFetching={revenue.isFetching}
              csvName={`revenue-by-method-${period.from}`}
              rows={[...data.by_method]
                .sort((a, b) => Number(b.value) - Number(a.value))
                .map((row) => ({
                  key: row.method,
                  label: CHANNEL_LABELS[row.method as Channel] ?? row.method,
                  value: Number(row.value),
                  hint:
                    row.change_percent === null
                      ? undefined
                      : `${Number(row.change_percent) > 0 ? '+' : ''}${row.change_percent}% on the period before`,
                }))}
            />
            <BarList
              title="By hour of the day"
              description="Ghana time"
              unit="money"
              valueLabel="Collected"
              isFetching={revenue.isFetching}
              csvName={`revenue-by-hour-${period.from}`}
              rows={data.by_hour
                .filter((row) => Number(row.amount) > 0)
                .map((row) => ({
                  key: row.key,
                  label: row.label ?? `${row.key}:00`,
                  value: Number(row.amount),
                  hint: `${formatNumber(row.payments)} payments`,
                }))}
            />
            <BarList
              title="By route"
              description="Top 20"
              unit="money"
              valueLabel="Collected"
              isFetching={revenue.isFetching}
              csvName={`revenue-by-route-${period.from}`}
              rows={data.by_route.map((row) => ({
                key: row.key,
                label: row.label ?? 'Retired route',
                value: Number(row.amount),
                hint: `${formatNumber(row.payments)} payments`,
              }))}
            />
            <BarList
              title="By fleet"
              description="Top 20"
              unit="money"
              valueLabel="Collected"
              isFetching={revenue.isFetching}
              csvName={`revenue-by-fleet-${period.from}`}
              rows={data.by_fleet.map((row) => ({
                key: row.key,
                label: row.label ?? 'Fleet',
                value: Number(row.amount),
                hint: `${formatNumber(row.payments)} payments`,
              }))}
            />
          </div>
        </div>
      ) : null}
      <div className="mt-8">
        <Transactions period={period} />
      </div>
    </>
  )
}
