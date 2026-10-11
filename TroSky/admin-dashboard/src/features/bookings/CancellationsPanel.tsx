import { type ColumnDef } from '@tanstack/react-table'
import { Check, TicketX, X } from 'lucide-react'
import { useId, useState } from 'react'
import { toast } from 'sonner'

import type { Schemas } from '@/api/types'
import { ConfirmDialog, ConfirmFacts } from '@/components/confirm/ConfirmDialog'
import { DataTable } from '@/components/data-table/DataTable'
import { EmptyState } from '@/components/feedback/states'
import { StatusBadge } from '@/components/status/StatusBadge'
import { Button } from '@/components/ui/button'
import { Checkbox } from '@/components/ui/checkbox'
import { Label } from '@/components/ui/label'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import { CANCELLATION_STATUS } from '@/features/shared/money'
import { formatDateTime, formatMoney, formatRelative } from '@/lib/format'
import { usePage, useUrlState } from '@/lib/url-state'
import { useNow } from '@/lib/use-now'

import {
  useBookingsById,
  useCancellations,
  useReviewCancellation,
  type CancellationStatus,
} from './api'

type Request = Schemas['CancellationRequestResponse']

const FILTERS: { value: CancellationStatus | 'all'; label: string }[] = [
  { value: 'pending', label: 'Waiting for a decision' },
  { value: 'approved', label: 'Approved' },
  { value: 'rejected', label: 'Turned down' },
  { value: 'all', label: 'All' },
]

function Decision({
  request,
  booking,
  approve,
  onClose,
}: {
  request: Request
  booking: Schemas['BookingResponse'] | undefined
  approve: boolean
  onClose: () => void
}) {
  const review = useReviewCancellation()
  const [refund, setRefund] = useState(false)
  const refundId = useId()
  const paid = booking?.status === 'confirmed'
  return (
    <ConfirmDialog
      open
      onOpenChange={(open) => !open && onClose()}
      title={approve ? 'Approve this cancellation?' : 'Turn this cancellation down?'}
      description={
        approve
          ? 'The booking is cancelled and its seat freed for the rest of the trip.'
          : 'The booking stays as it is. The passenger is told.'
      }
      details={
        <div className="space-y-3">
          <ConfirmFacts
            rows={[
              ['Booking', booking?.booking_reference ?? '—'],
              ['Passenger', booking?.passengers[0]?.full_name ?? '—'],
              ['Paid', paid ? formatMoney(booking.total_amount) : 'Nothing'],
              ['Why', request.reason ?? '—'],
            ]}
          />
          {approve && paid ? (
            <div className="flex items-start gap-2">
              <Checkbox
                id={refundId}
                checked={refund}
                onCheckedChange={(checked) => setRefund(checked === true)}
              />
              <Label htmlFor={refundId} className="grid gap-0.5 font-normal">
                <span>Refund the passenger</span>
                <span className="text-xs text-muted-foreground">
                  {formatMoney(booking.total_amount)} goes to the refund queue for approval.
                </span>
              </Label>
            </div>
          ) : null}
        </div>
      }
      confirmLabel={approve ? 'Approve cancellation' : 'Turn down'}
      destructive={!approve}
      reason={
        approve
          ? { label: 'Note for the record', maxLength: 1000 }
          : {
              label: 'Reason (the passenger sees it)',
              required: true,
              maxLength: 1000,
              placeholder: 'e.g. The trip was nearly over when this was asked.',
            }
      }
      onConfirm={async (notes) => {
        await review.mutateAsync({
          id: request.id,
          approve,
          refund_eligible: approve && paid ? refund : false,
          notes: notes || null,
        })
        toast.success(
          !approve
            ? 'Turned down. The booking stays as it is.'
            : refund
              ? 'Approved. The refund is waiting in Refunds.'
              : 'Approved. The booking is cancelled.',
        )
        onClose()
      }}
    />
  )
}

/** Cancellations asked for after a trip started: approve or turn down. */
export function CancellationsPanel() {
  const [{ status }, update] = useUrlState({ status: 'pending' })
  const { page, limit, setPage } = usePage()
  const filter = (FILTERS.find((option) => option.value === status)?.value ?? 'pending') as
    CancellationStatus | 'all'
  const requests = useCancellations(filter === 'all' ? '' : filter, page, limit)
  const bookings = useBookingsById(
    (requests.data?.items ?? []).map((request) => request.booking_id),
  )
  const now = useNow(30_000)
  const [deciding, setDeciding] = useState<{ request: Request; approve: boolean } | null>(null)
  const statusId = useId()

  const columns: ColumnDef<Request, unknown>[] = [
    {
      header: 'Asked',
      cell: ({ row }) => (
        <div className="whitespace-nowrap">
          <p>{formatRelative(row.original.created_at, now)}</p>
          <p className="text-xs text-muted-foreground">{formatDateTime(row.original.created_at)}</p>
        </div>
      ),
    },
    {
      header: 'Booking',
      cell: ({ row }) => {
        const booking = bookings.get(row.original.booking_id)
        return booking ? (
          <div>
            <p className="figure">{booking.booking_reference}</p>
            <p className="text-xs text-muted-foreground">
              {booking.passengers[0]?.full_name} · {booking.trip?.route_name}
            </p>
          </div>
        ) : (
          <span className="text-muted-foreground">—</span>
        )
      },
    },
    {
      header: 'Why',
      cell: ({ row }) => (
        <span className="line-clamp-2 max-w-72 text-sm">{row.original.reason ?? '—'}</span>
      ),
    },
    {
      header: 'Status',
      cell: ({ row }) => {
        const style = CANCELLATION_STATUS[row.original.status]
        return (
          <div className="space-y-1">
            <StatusBadge tone={style.tone} label={style.label} />
            {row.original.status === 'approved' ? (
              <p className="text-xs text-muted-foreground">
                {row.original.refund_eligible ? 'With a refund' : 'No refund'}
              </p>
            ) : null}
          </div>
        )
      },
    },
    {
      id: 'actions',
      header: () => <span className="sr-only">Actions</span>,
      cell: ({ row }) =>
        row.original.status === 'pending' ? (
          <div className="flex justify-end gap-1">
            <Button size="sm" onClick={() => setDeciding({ request: row.original, approve: true })}>
              <Check aria-hidden /> Approve
            </Button>
            <Button
              size="sm"
              variant="outline"
              onClick={() => setDeciding({ request: row.original, approve: false })}
            >
              <X aria-hidden /> Turn down
            </Button>
          </div>
        ) : null,
    },
  ]

  return (
    <>
      <div
        className="mb-4 grid gap-3 sm:grid-cols-2 lg:grid-cols-4"
        role="group"
        aria-label="Filters"
      >
        <div className="grid gap-1.5">
          <Label htmlFor={statusId}>Status</Label>
          <Select value={filter} onValueChange={(next) => update({ status: next })}>
            <SelectTrigger id={statusId}>
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              {FILTERS.map((option) => (
                <SelectItem key={option.value} value={option.value}>
                  {option.label}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
      </div>
      <DataTable
        columns={columns}
        rows={requests.data?.items}
        total={requests.data?.total}
        getRowId={(row) => row.id}
        caption="Cancellations after departure"
        isPending={requests.isPending}
        isError={requests.isError}
        error={requests.error}
        onRetry={() => void requests.refetch()}
        isFetching={requests.isFetching && !requests.isPending}
        page={page}
        pageSize={limit}
        onPageChange={setPage}
        empty={
          <EmptyState
            icon={TicketX}
            title={filter === 'pending' ? 'Nothing to decide' : 'No cancellations here'}
            description="Passengers who cancel after their trip has started appear here."
          />
        }
      />
      {deciding ? (
        <Decision
          key={`${deciding.request.id}-${deciding.approve}`}
          request={deciding.request}
          booking={bookings.get(deciding.request.booking_id)}
          approve={deciding.approve}
          onClose={() => setDeciding(null)}
        />
      ) : null}
    </>
  )
}
