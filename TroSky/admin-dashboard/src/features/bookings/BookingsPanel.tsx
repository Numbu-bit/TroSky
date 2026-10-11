import { type ColumnDef } from '@tanstack/react-table'
import { Download, Ticket } from 'lucide-react'
import { useId, useState } from 'react'
import { toast } from 'sonner'

import { downloadFile } from '@/api/client'
import { errorMessage } from '@/api/errors'
import type { Schemas } from '@/api/types'
import { DataTable } from '@/components/data-table/DataTable'
import { EmptyState } from '@/components/feedback/states'
import { StatusBadge } from '@/components/status/StatusBadge'
import { Button } from '@/components/ui/button'
import { Label } from '@/components/ui/label'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import { BOOKING_STATUS } from '@/features/shared/money'
import { formatDateTime, formatDayMonth, formatMoney, formatTime } from '@/lib/format'
import { usePage, useUrlState } from '@/lib/url-state'

import { useBookings, type BookingStatus } from './api'
import { BookingDrawer } from './BookingDrawer'

type Booking = Schemas['BookingResponse']
const ANY = 'any'

/** Every booking on the platform, newest first, one status at a time. */
export function BookingsPanel() {
  const [{ status, booking }, update] = useUrlState({ status: ANY, booking: '' })
  const { page, limit, setPage } = usePage()
  const filter = (status in BOOKING_STATUS ? status : '') as BookingStatus | ''
  const bookings = useBookings(filter, page, limit)
  const [downloading, setDownloading] = useState(false)
  const statusId = useId()

  const columns: ColumnDef<Booking, unknown>[] = [
    {
      header: 'Booked',
      cell: ({ row }) => (
        <span className="whitespace-nowrap">{formatDateTime(row.original.created_at)}</span>
      ),
    },
    {
      header: 'Reference',
      cell: ({ row }) => (
        <button
          type="button"
          className="figure link-inline font-medium"
          onClick={(event) => {
            event.stopPropagation()
            update({ booking: row.original.id }, { keepPage: true })
          }}
        >
          {row.original.booking_reference}
        </button>
      ),
    },
    {
      header: 'Trip',
      cell: ({ row }) =>
        row.original.trip ? (
          <div className="min-w-44">
            <p>{row.original.trip.route_name}</p>
            <p className="text-xs text-muted-foreground">
              {formatDayMonth(row.original.trip.scheduled_departure_at)},{' '}
              {formatTime(row.original.trip.scheduled_departure_at)}
            </p>
          </div>
        ) : (
          '—'
        ),
    },
    {
      header: 'Passenger',
      cell: ({ row }) => (
        <span>
          {row.original.passengers[0]?.full_name ?? '—'}
          {row.original.passenger_count > 1 ? (
            <span className="text-muted-foreground"> +{row.original.passenger_count - 1}</span>
          ) : null}
        </span>
      ),
    },
    {
      header: 'Total',
      meta: { align: 'right' },
      cell: ({ row }) => formatMoney(row.original.total_amount),
    },
    {
      header: 'Status',
      cell: ({ row }) => {
        const style = BOOKING_STATUS[row.original.status]
        return <StatusBadge tone={style.tone} label={style.label} />
      },
    },
  ]

  async function download() {
    setDownloading(true)
    try {
      await downloadFile(
        '/api/v1/admin/bookings',
        { format: 'csv', booking_status: filter },
        `bookings${filter ? `-${filter}` : ''}.csv`,
      )
    } catch (error) {
      toast.error(errorMessage(error))
    } finally {
      setDownloading(false)
    }
  }

  return (
    <>
      <div
        className="mb-4 flex flex-wrap items-end justify-between gap-3"
        role="group"
        aria-label="Filters"
      >
        <div className="grid w-full max-w-xs gap-1.5">
          <Label htmlFor={statusId}>Status</Label>
          <Select value={filter || ANY} onValueChange={(next) => update({ status: next })}>
            <SelectTrigger id={statusId}>
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value={ANY}>Any status</SelectItem>
              {(Object.keys(BOOKING_STATUS) as BookingStatus[]).map((value) => (
                <SelectItem key={value} value={value}>
                  {BOOKING_STATUS[value].label}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
        <Button variant="outline" onClick={() => void download()} disabled={downloading}>
          <Download aria-hidden /> CSV
        </Button>
      </div>
      <DataTable
        columns={columns}
        rows={bookings.data?.items}
        total={bookings.data?.total}
        getRowId={(row) => row.id}
        caption="Bookings"
        isPending={bookings.isPending}
        isError={bookings.isError}
        error={bookings.error}
        onRetry={() => void bookings.refetch()}
        isFetching={bookings.isFetching && !bookings.isPending}
        page={page}
        pageSize={limit}
        onPageChange={setPage}
        onRowClick={(row) => update({ booking: row.id }, { keepPage: true })}
        selectedId={booking || null}
        empty={<EmptyState icon={Ticket} title="No bookings" description="None has this status." />}
      />
      <BookingDrawer
        bookingId={booking || null}
        onClose={() => update({ booking: null }, { keepPage: true })}
      />
    </>
  )
}
