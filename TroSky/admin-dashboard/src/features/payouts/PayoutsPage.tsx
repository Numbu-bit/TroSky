import { type ColumnDef } from '@tanstack/react-table'
import {
  Banknote,
  Check,
  CircleCheck,
  CircleX,
  Clock,
  Download,
  Send,
  Undo2,
  Wallet,
  X,
  type LucideIcon,
} from 'lucide-react'
import { useId, useState, type ReactNode } from 'react'
import { Link } from 'react-router'
import { toast } from 'sonner'

import { downloadFile } from '@/api/client'
import { errorMessage } from '@/api/errors'
import type { Schemas } from '@/api/types'
import { useSession } from '@/app/auth/auth-context'
import { ConfirmButton } from '@/components/confirm/ConfirmButton'
import { ConfirmFacts } from '@/components/confirm/ConfirmDialog'
import { DataTable } from '@/components/data-table/DataTable'
import { EmptyState, ErrorState } from '@/components/feedback/states'
import { PageHeader } from '@/components/layout/PageHeader'
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
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetHeader,
  SheetTitle,
} from '@/components/ui/sheet'
import { Skeleton } from '@/components/ui/skeleton'
import { useQueueCounts } from '@/features/overview/api'
import { CHANNEL_LABELS, PAYOUT_STATUS } from '@/features/shared/money'
import { formatDateTime, formatMoney, formatPhone, formatRelative, maskPhone } from '@/lib/format'
import { isModuleEnabled } from '@/lib/modules'
import { usePage, useUrlState } from '@/lib/url-state'
import { useNow } from '@/lib/use-now'
import { cn } from '@/lib/utils'

import {
  usePayout,
  usePayoutAction,
  usePayoutOwners,
  usePayouts,
  type Payout,
  type PayoutStatus,
} from './api'

type Owner = Schemas['AdminUserDetailResponse'] | undefined

const FILTERS: { value: PayoutStatus | 'all'; label: string }[] = [
  { value: 'pending', label: 'Waiting for a decision' },
  { value: 'approved', label: 'Approved, to send' },
  { value: 'completed', label: 'Sent' },
  { value: 'failed', label: 'Failed' },
  { value: 'rejected', label: 'Rejected' },
  { value: 'all', label: 'All' },
]

const ownerName = (owner: Owner) => owner?.full_name ?? 'The driver'

/** What happened to a payout, from its own fields (oldest first). */
function timeline(payout: Payout, me: string) {
  const who = payout.reviewed_by === me ? 'you' : 'an admin'
  const steps: {
    icon: LucideIcon
    tone: string
    title: string
    when?: string
    note?: ReactNode
  }[] = [
    { icon: Clock, tone: 'text-muted-foreground', title: 'Asked for', when: payout.created_at },
  ]
  if (payout.status === 'rejected') {
    steps.push({
      icon: CircleX,
      tone: 'text-muted-foreground',
      title: `Rejected by ${who}; the money stayed in the wallet`,
      when: payout.reviewed_at ?? undefined,
      note: payout.decision_notes,
    })
  }
  if (['approved', 'completed', 'failed'].includes(payout.status)) {
    steps.push({
      icon: Check,
      tone: 'text-info-text',
      title: `Approved by ${who}; ${formatMoney(payout.amount)} left the wallet`,
      when: payout.reviewed_at ?? undefined,
      note: payout.decision_notes,
    })
  }
  if (payout.status === 'completed') {
    steps.push({
      icon: CircleCheck,
      tone: 'text-success-text',
      title: 'Marked sent',
      note: payout.provider_reference ? `Reference ${payout.provider_reference}` : null,
    })
  }
  if (payout.status === 'failed') {
    steps.push({
      icon: Undo2,
      tone: 'text-danger-text',
      title: `Marked failed; ${formatMoney(payout.amount)} went back to the wallet`,
      note: payout.failure_reason,
    })
  }
  return steps
}

function Actions({ payout, owner }: { payout: Payout; owner: Owner }) {
  const act = usePayoutAction()
  const name = ownerName(owner)
  const method = CHANNEL_LABELS[payout.channel]
  const facts = (
    <ConfirmFacts
      rows={[
        ['Amount', formatMoney(payout.amount)],
        ['To', `${name}, ${maskPhone(payout.destination_phone_number)}`],
        ['Method', method],
      ]}
    />
  )
  if (payout.status === 'pending') {
    return (
      <div className="flex flex-wrap gap-2">
        <ConfirmButton
          label="Approve payout"
          icon={Check}
          title={`Approve ${formatMoney(payout.amount)} for ${name}?`}
          description={`${formatMoney(payout.amount)} leaves their wallet now. Then send it by ${method} and mark it sent.`}
          details={facts}
          confirmLabel="Approve payout"
          reason={{ label: 'Note for the record', maxLength: 1000 }}
          onConfirm={async (notes) => {
            await act.mutateAsync({ id: payout.id, action: 'approve', notes })
            toast.success(
              `Approved. Send ${formatMoney(payout.amount)} by ${method}, then mark it sent.`,
            )
          }}
        />
        <ConfirmButton
          label="Reject"
          icon={X}
          variant="outline"
          title="Reject this payout?"
          description="No money moves: it stays in their wallet."
          details={facts}
          confirmLabel="Reject payout"
          destructive
          reason={{
            label: 'Reason (the driver sees it)',
            required: true,
            maxLength: 1000,
            placeholder: 'e.g. The number does not match the driver’s account.',
          }}
          onConfirm={async (notes) => {
            await act.mutateAsync({ id: payout.id, action: 'reject', notes })
            toast.success('Payout rejected.')
          }}
        />
      </div>
    )
  }
  if (payout.status === 'approved') {
    return (
      <div className="flex flex-wrap gap-2">
        <ConfirmButton
          label="Mark sent"
          icon={Send}
          title={`Mark ${formatMoney(payout.amount)} as sent?`}
          description={`Only once the money has reached ${maskPhone(payout.destination_phone_number)} by ${method}.`}
          details={facts}
          confirmLabel="Mark sent"
          reason={{
            label: `${method} transaction reference`,
            maxLength: 100,
            placeholder: 'e.g. MP2610041234',
          }}
          onConfirm={async (reference) => {
            await act.mutateAsync({ id: payout.id, action: 'complete', reference })
            toast.success('Marked sent.')
          }}
        />
        <ConfirmButton
          label="Mark failed"
          icon={Undo2}
          variant="outline"
          title="Mark this payout failed?"
          description={`${formatMoney(payout.amount)} goes back into their wallet.`}
          details={facts}
          confirmLabel="Mark failed"
          destructive
          reason={{
            label: 'What went wrong (the driver sees it)',
            required: true,
            maxLength: 500,
            placeholder: 'e.g. MTN MoMo rejected the transfer: wallet limit reached.',
          }}
          onConfirm={async (reason) => {
            await act.mutateAsync({ id: payout.id, action: 'fail', reason })
            toast.success(`Marked failed. ${formatMoney(payout.amount)} is back in the wallet.`)
          }}
        />
      </div>
    )
  }
  return null
}

function PayoutDrawer({
  payoutId,
  owners,
  onClose,
}: {
  payoutId: string | null
  owners: Map<string, NonNullable<Owner>>
  onClose: () => void
}) {
  const { me, can } = useSession()
  const payout = usePayout(payoutId)
  const [revealed, setRevealed] = useState(false)
  const data = payout.data
  const owner = data ? owners.get(data.user_id) : undefined
  return (
    <Sheet
      open={Boolean(payoutId)}
      onOpenChange={(open) => {
        if (!open) {
          setRevealed(false)
          onClose()
        }
      }}
    >
      <SheetContent className="w-full overflow-y-auto sm:max-w-md">
        <SheetHeader>
          <SheetTitle>{data ? `Payout of ${formatMoney(data.amount)}` : 'Payout'}</SheetTitle>
          <SheetDescription asChild>
            <div>
              {data ? (
                <StatusBadge
                  tone={PAYOUT_STATUS[data.status].tone}
                  label={PAYOUT_STATUS[data.status].label}
                />
              ) : (
                'Loading'
              )}
            </div>
          </SheetDescription>
        </SheetHeader>
        {payout.isPending ? (
          <div className="space-y-3 px-4">
            <Skeleton className="h-20" />
            <Skeleton className="h-32" />
          </div>
        ) : payout.isError ? (
          <ErrorState error={payout.error} onRetry={() => void payout.refetch()} />
        ) : data ? (
          <div className="space-y-5 px-4 pb-6">
            <ConfirmFacts
              rows={[
                ['To', ownerName(owner)],
                [
                  'Number',
                  revealed ? (
                    <span className="figure">{formatPhone(data.destination_phone_number)}</span>
                  ) : (
                    <button
                      type="button"
                      className="figure link-inline"
                      onClick={() => setRevealed(true)}
                      aria-label="Show the full number"
                    >
                      {maskPhone(data.destination_phone_number)}
                    </button>
                  ),
                ],
                ['Method', CHANNEL_LABELS[data.channel]],
                ['Amount', formatMoney(data.amount)],
              ]}
            />
            <section aria-label="What happened" className="space-y-2">
              <h3 className="text-sm font-semibold">What happened</h3>
              <ol className="space-y-3">
                {timeline(data, me.id).map((step, position) => (
                  <li key={position} className="flex gap-3 text-sm">
                    <step.icon className={cn('mt-0.5 size-4 shrink-0', step.tone)} aria-hidden />
                    <div>
                      <p>{step.title}</p>
                      {step.when ? (
                        <p className="text-xs text-muted-foreground">{formatDateTime(step.when)}</p>
                      ) : null}
                      {step.note ? (
                        <p className="text-xs text-muted-foreground">“{step.note}”</p>
                      ) : null}
                    </div>
                  </li>
                ))}
              </ol>
            </section>
            <Actions payout={data} owner={owner} />
            {isModuleEnabled('wallets') && can('wallet:adjust') ? (
              <Button asChild variant="outline" size="sm">
                <Link to={`/wallets/${data.user_id}`}>
                  <Wallet aria-hidden /> Open their wallet
                </Link>
              </Button>
            ) : null}
          </div>
        ) : null}
      </SheetContent>
    </Sheet>
  )
}

/** Payouts (wallet withdrawals) by status: approve, send, fail or reject. */
export default function PayoutsPage() {
  const [{ status, payout }, update] = useUrlState({ status: 'pending', payout: '' })
  const { page, limit, setPage } = usePage()
  const filter = (FILTERS.find((option) => option.value === status)?.value ?? 'pending') as
    PayoutStatus | 'all'
  const payouts = usePayouts(filter === 'all' ? '' : filter, page, limit)
  const owners = usePayoutOwners((payouts.data?.items ?? []).map((row) => row.user_id))
  const counts = new Map(
    useQueueCounts(['payouts', 'payouts-to-send']).map(({ queue, result }) => [
      queue.key,
      result.data,
    ]),
  )
  const now = useNow(30_000)
  const [downloading, setDownloading] = useState(false)
  const statusId = useId()

  const columns: ColumnDef<Payout, unknown>[] = [
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
      header: 'To',
      cell: ({ row }) => (
        <div>
          <p>{owners.get(row.original.user_id)?.full_name ?? 'Driver'}</p>
          <p className="figure text-xs text-muted-foreground">
            {maskPhone(row.original.destination_phone_number)}
          </p>
        </div>
      ),
    },
    {
      header: 'Method',
      cell: ({ row }) => CHANNEL_LABELS[row.original.channel],
    },
    {
      header: 'Amount',
      meta: { align: 'right' },
      cell: ({ row }) => <span className="font-medium">{formatMoney(row.original.amount)}</span>,
    },
    {
      header: 'Status',
      cell: ({ row }) => {
        const style = PAYOUT_STATUS[row.original.status]
        return <StatusBadge tone={style.tone} label={style.label} />
      },
    },
  ]

  async function download() {
    setDownloading(true)
    try {
      await downloadFile(
        '/api/v1/admin/withdrawals',
        { format: 'csv', withdrawal_status: filter === 'all' ? '' : filter },
        `payouts-${filter}.csv`,
      )
    } catch (error) {
      toast.error(errorMessage(error))
    } finally {
      setDownloading(false)
    }
  }

  return (
    <>
      <PageHeader
        title="Payouts"
        description="Drivers’ wallet withdrawals. Approving takes the money out of the wallet; mark it sent once it has reached them."
      />
      <div
        className="mb-4 flex flex-wrap items-end justify-between gap-3"
        role="group"
        aria-label="Filters"
      >
        <div className="grid w-full max-w-xs gap-1.5">
          <Label htmlFor={statusId}>Status</Label>
          <Select value={filter} onValueChange={(next) => update({ status: next })}>
            <SelectTrigger id={statusId}>
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              {FILTERS.map((option) => {
                const count =
                  option.value === 'pending'
                    ? counts.get('payouts')
                    : option.value === 'approved'
                      ? counts.get('payouts-to-send')
                      : undefined
                return (
                  <SelectItem key={option.value} value={option.value}>
                    {option.label}
                    {count ? ` (${count})` : ''}
                  </SelectItem>
                )
              })}
            </SelectContent>
          </Select>
        </div>
        <Button variant="outline" onClick={() => void download()} disabled={downloading}>
          <Download aria-hidden /> CSV
        </Button>
      </div>
      <DataTable
        columns={columns}
        rows={payouts.data?.items}
        total={payouts.data?.total}
        getRowId={(row) => row.id}
        caption="Payouts"
        isPending={payouts.isPending}
        isError={payouts.isError}
        error={payouts.error}
        onRetry={() => void payouts.refetch()}
        isFetching={payouts.isFetching && !payouts.isPending}
        page={page}
        pageSize={limit}
        onPageChange={setPage}
        onRowClick={(row) => update({ payout: row.id }, { keepPage: true })}
        selectedId={payout || null}
        empty={
          <EmptyState
            icon={Banknote}
            title={filter === 'pending' ? 'No payout is waiting' : 'No payouts here'}
            description="Drivers ask for payouts from their wallets in the driver app."
          />
        }
      />
      <PayoutDrawer
        payoutId={payout || null}
        owners={owners}
        onClose={() => update({ payout: null }, { keepPage: true })}
      />
    </>
  )
}
