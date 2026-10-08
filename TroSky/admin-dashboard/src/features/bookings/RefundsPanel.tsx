import { type ColumnDef } from '@tanstack/react-table'
import { Check, HandCoins, X } from 'lucide-react'
import { useId, useState } from 'react'
import { toast } from 'sonner'

import type { Schemas } from '@/api/types'
import { ConfirmDialog, ConfirmFacts } from '@/components/confirm/ConfirmDialog'
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
import { Skeleton } from '@/components/ui/skeleton'
import { CHANNEL_LABELS, REFUND_STATUS } from '@/features/shared/money'
import { formatDateTime, formatMoney, formatRelative, maskPhone } from '@/lib/format'
import { usePage, useUrlState } from '@/lib/url-state'
import { useNow } from '@/lib/use-now'

import {
  useBookingsById,
  useDecideRefund,
  useRefundContext,
  useRefunds,
  type RefundStatus,
} from './api'

type Refund = Schemas['RefundRequestResponse']

const FILTERS: { value: RefundStatus | 'all'; label: string }[] = [
  { value: 'pending', label: 'Waiting for a decision' },
  { value: 'completed', label: 'Paid back' },
  { value: 'failed', label: 'Payout failed' },
  { value: 'rejected', label: 'Rejected' },
  { value: 'all', label: 'All' },
]

/**
 * Approving pays the money back at once (rule 3.3.4): the dialog shows the
 * amount, who gets it, how, and that it can't be undone.
 */
function RefundDecision({
  refund,
  approve,
  onClose,
}: {
  refund: Refund | null
  approve: boolean
  onClose: () => void
}) {
  const context = useRefundContext(refund)
  const decide = useDecideRefund()
  if (!refund) return null
  const payer = context.payment?.payer
  const method = context.payment ? CHANNEL_LABELS[context.payment.method] : null
  const recipient = payer
    ? `${payer.name ?? 'The passenger'} (${maskPhone(payer.phone_number)})`
    : (context.booking?.passengers[0]?.full_name ?? 'The passenger who paid')
  return (
    <ConfirmDialog
      open
      onOpenChange={(open) => !open && onClose()}
      title={approve ? `Pay back ${formatMoney(refund.amount)}?` : 'Reject this refund?'}
      description={
        approve
          ? `The money goes back ${method ? `to their ${method}` : 'the way it was paid'} straight away. This can’t be undone.`
          : 'No money moves. The passenger is told it was turned down.'
      }
      details={
        context.loading ? (
          <Skeleton className="h-16" />
        ) : (
          <ConfirmFacts
            rows={[
              ['Amount', formatMoney(refund.amount)],
              ['To', recipient],
              ['Method', method ?? 'As paid'],
              ['Booking', context.booking?.booking_reference ?? '—'],
              ['Why', refund.reason ?? '—'],
            ]}
          />
        )
      }
      confirmLabel={approve ? `Pay back ${formatMoney(refund.amount)}` : 'Reject refund'}
      destructive={!approve}
      reason={
        approve
          ? { label: 'Note for the record', maxLength: 1000 }
          : {
              label: 'Reason (kept with the refund)',
              required: true,
              maxLength: 1000,
              placeholder: 'e.g. The trip was completed as booked.',
            }
      }
      onConfirm={async (notes) => {
        const result = await decide.mutateAsync({ id: refund.id, approve, notes })
        if (!approve) toast.success('Refund rejected.')
        else if (result.status === 'completed') {
          toast.success(`Paid back ${formatMoney(result.amount)}.`)
        } else if (result.status === 'failed') {
          toast.error(`The payout failed: ${result.failure_reason ?? 'no reason given'}.`)
        } else toast.success('Refund approved.')
        onClose()
      }}
    />
  )
}

/** Refund requests, newest first; approving one pays it out. */
export function RefundsPanel() {
  const [{ status }, update] = useUrlState({ status: 'pending' })
  const { page, limit, setPage } = usePage()
  const filter = (FILTERS.find((option) => option.value === status)?.value ?? 'pending') as
    RefundStatus | 'all'
  const refunds = useRefunds(filter === 'all' ? '' : filter, page, limit)
  const bookings = useBookingsById((refunds.data?.items ?? []).map((refund) => refund.booking_id))
  const now = useNow(30_000)
  const [deciding, setDeciding] = useState<{ refund: Refund; approve: boolean } | null>(null)
  const statusId = useId()

  const columns: ColumnDef<Refund, unknown>[] = [
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
      header: 'Amount',
      meta: { align: 'right' },
      cell: ({ row }) => <span className="font-medium">{formatMoney(row.original.amount)}</span>,
    },
    {
      header: 'Booking',
      cell: ({ row }) => {
        const booking = row.original.booking_id ? bookings.get(row.original.booking_id) : undefined
        return booking ? (
          <div>
            <p className="figure">{booking.booking_reference}</p>
            <p className="text-xs text-muted-foreground">{booking.passengers[0]?.full_name}</p>
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
        const style = REFUND_STATUS[row.original.status]
        return (
          <div className="space-y-1">
            <StatusBadge tone={style.tone} label={style.label} />
            {row.original.failure_reason ? (
              <p className="max-w-56 text-xs text-danger-text">{row.original.failure_reason}</p>
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
            <Button
              size="sm"
              onClick={() => setDeciding({ refund: row.original, approve: true })}
              aria-label={`Approve the refund of ${formatMoney(row.original.amount)}`}
            >
              <Check aria-hidden /> Approve
            </Button>
            <Button
              size="sm"
              variant="outline"
              onClick={() => setDeciding({ refund: row.original, approve: false })}
              aria-label={`Reject the refund of ${formatMoney(row.original.amount)}`}
            >
              <X aria-hidden /> Reject
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
        rows={refunds.data?.items}
        total={refunds.data?.total}
        getRowId={(row) => row.id}
        caption="Refund requests"
        isPending={refunds.isPending}
        isError={refunds.isError}
        error={refunds.error}
        onRetry={() => void refunds.refetch()}
        isFetching={refunds.isFetching && !refunds.isPending}
        page={page}
        pageSize={limit}
        onPageChange={setPage}
        empty={
          <EmptyState
            icon={HandCoins}
            title={filter === 'pending' ? 'No refund is waiting' : 'No refunds here'}
            description="Refunds appear when paid bookings are cancelled before departure."
          />
        }
      />
      {deciding ? (
        <RefundDecision
          key={`${deciding.refund.id}-${deciding.approve}`}
          refund={deciding.refund}
          approve={deciding.approve}
          onClose={() => setDeciding(null)}
        />
      ) : null}
    </>
  )
}
