import { keepPreviousData, useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { type ColumnDef } from '@tanstack/react-table'
import { ArrowLeft, Lock, Search, Wallet } from 'lucide-react'
import { useId, useState } from 'react'
import { Link, Route, Routes, useNavigate, useParams } from 'react-router'
import { toast } from 'sonner'

import { api, unwrap } from '@/api/client'
import { fieldErrors, isApiError } from '@/api/errors'
import type { Schemas } from '@/api/types'
import { useSession } from '@/app/auth/auth-context'
import { StatTile } from '@/components/charts/StatTile'
import { ConfirmDialog, ConfirmFacts } from '@/components/confirm/ConfirmDialog'
import { DataTable } from '@/components/data-table/DataTable'
import { EmptyState, ErrorState, PageSkeleton } from '@/components/feedback/states'
import { PageHeader, Section } from '@/components/layout/PageHeader'
import { NotFoundPage } from '@/app/pages/StatusPages'
import { StatusBadge } from '@/components/status/StatusBadge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { ToggleGroup, ToggleGroupItem } from '@/components/ui/toggle-group'
import { useAccounts } from '@/features/accounts/api'
import { formatDateTime, formatMoney, maskPhone } from '@/lib/format'
import { usePage } from '@/lib/url-state'
import { useDebounced } from '@/lib/use-debounced'
import { cn } from '@/lib/utils'

type Transaction = Schemas['WalletTransactionResponse']

const REFERENCE: Record<Schemas['WalletReferenceType'], string> = {
  booking_payment: 'Paid for a booking',
  wallet_topup: 'Top-up',
  refund: 'Refund',
  admin_adjustment: 'Adjusted by an admin',
  trip_earning: 'Trip earnings',
  withdrawal: 'Payout',
}

function useWallet(userId: string, page: number, limit: number) {
  return useQuery({
    queryKey: ['wallets', userId, page, limit],
    queryFn: () =>
      unwrap(
        api.GET('/api/v1/admin/wallets/{user_id}', {
          params: { path: { user_id: userId }, query: { limit, offset: (page - 1) * limit } },
        }),
      ),
    placeholderData: keepPreviousData,
  })
}

function Adjust({ wallet }: { wallet: Schemas['AdminWalletResponse'] }) {
  const queryClient = useQueryClient()
  const id = useId()
  const [direction, setDirection] = useState<'credit' | 'debit'>('credit')
  const [amount, setAmount] = useState('')
  const [reason, setReason] = useState('')
  const [reference, setReference] = useState('')
  const [problem, setProblem] = useState<string | null>(null)
  const [confirming, setConfirming] = useState(false)
  const adjust = useMutation({
    mutationFn: (body: Schemas['WalletAdjustmentRequest']) =>
      unwrap(
        api.POST('/api/v1/admin/wallets/{user_id}/adjustments', {
          params: { path: { user_id: wallet.user.id } },
          body,
        }),
      ),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['wallets', wallet.user.id] })
      void queryClient.invalidateQueries({ queryKey: ['accounts'] })
    },
  })
  const name = wallet.user.full_name ?? maskPhone(wallet.user.phone_number)

  function review() {
    if (!/^\d{1,10}(\.\d{1,2})?$/.test(amount.trim()) || Number(amount) <= 0) {
      return setProblem('Enter an amount in cedis above 0, like 25.00.')
    }
    if (reason.trim().length < 5) return setProblem('Say why, in at least 5 characters.')
    if (direction === 'debit' && Number(amount) > Number(wallet.balance)) {
      return setProblem(`The wallet holds only ${formatMoney(wallet.balance)}.`)
    }
    setProblem(null)
    setConfirming(true)
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-base">Adjust the balance</CardTitle>
      </CardHeader>
      <CardContent className="space-y-3">
        <ToggleGroup
          type="single"
          variant="outline"
          value={direction}
          onValueChange={(value) => value && setDirection(value as 'credit' | 'debit')}
          aria-label="Direction"
        >
          <ToggleGroupItem value="credit">Add money</ToggleGroupItem>
          <ToggleGroupItem value="debit">Take money</ToggleGroupItem>
        </ToggleGroup>
        <div className="grid gap-1.5">
          <Label htmlFor={`${id}-amount`}>Amount (GH₵)</Label>
          <Input
            id={`${id}-amount`}
            inputMode="decimal"
            value={amount}
            placeholder="25.00"
            onChange={(event) => setAmount(event.target.value)}
          />
        </div>
        <div className="grid gap-1.5">
          <Label htmlFor={`${id}-reason`}>Why (kept on the transaction)</Label>
          <Input
            id={`${id}-reason`}
            value={reason}
            maxLength={500}
            placeholder="e.g. Goodwill for a broken-down bus"
            onChange={(event) => setReason(event.target.value)}
          />
        </div>
        <div className="grid gap-1.5">
          <Label htmlFor={`${id}-reference`}>Case or ticket number (optional)</Label>
          <Input
            id={`${id}-reference`}
            value={reference}
            maxLength={100}
            onChange={(event) => setReference(event.target.value)}
          />
        </div>
        {problem ? (
          <p role="alert" className="text-sm text-danger-text">
            {problem}
          </p>
        ) : null}
        <Button onClick={review}>{direction === 'credit' ? 'Add money' : 'Take money'}</Button>
      </CardContent>
      <ConfirmDialog
        open={confirming}
        onOpenChange={setConfirming}
        title={`${direction === 'credit' ? 'Add' : 'Take'} ${formatMoney(amount || 0)} ${direction === 'credit' ? 'to' : 'from'} ${name}’s wallet?`}
        description={
          direction === 'credit'
            ? 'They can spend it on bookings or, if they drive, ask for it as a payout.'
            : 'It leaves their wallet now. This can’t be undone except by another adjustment.'
        }
        details={
          <ConfirmFacts
            rows={[
              ['Amount', formatMoney(amount || 0)],
              ['Wallet of', `${name} (${maskPhone(wallet.user.phone_number)})`],
              ['Balance now', formatMoney(wallet.balance)],
              [
                'Balance after',
                formatMoney(
                  Number(wallet.balance) + (direction === 'credit' ? 1 : -1) * Number(amount || 0),
                ),
              ],
              ['Why', reason],
            ]}
          />
        }
        confirmLabel={direction === 'credit' ? 'Add money' : 'Take money'}
        destructive={direction === 'debit'}
        onConfirm={async () => {
          try {
            const result = await adjust.mutateAsync({
              direction,
              amount: amount.trim(),
              reason: reason.trim(),
              reference: reference.trim() || null,
            })
            toast.success(`Done. The balance is now ${formatMoney(result.balance)}.`)
            setAmount('')
            setReason('')
            setReference('')
          } catch (error) {
            const fields = fieldErrors(error)
            throw new Error(
              Object.values(fields)[0] ??
                (error instanceof Error ? error.message : 'Could not adjust it.'),
            )
          }
        }}
      />
    </Card>
  )
}

function WalletPage() {
  const { userId = '' } = useParams()
  const { can } = useSession()
  const { page, limit, setPage } = usePage()
  const wallet = useWallet(userId, page, limit)
  const back = (
    <Button asChild variant="ghost" size="sm" className="mb-2 -ml-2">
      <Link to="/wallets">
        <ArrowLeft aria-hidden /> Wallets
      </Link>
    </Button>
  )
  if (wallet.isPending) return <PageSkeleton />
  if (wallet.isError) {
    return (
      <>
        {back}
        {isApiError(wallet.error, 404) ? (
          <EmptyState title="No such account" description="The link may be wrong or old." />
        ) : (
          <ErrorState error={wallet.error} onRetry={() => void wallet.refetch()} />
        )}
      </>
    )
  }
  const data = wallet.data
  const name = data.user.full_name ?? maskPhone(data.user.phone_number)
  const columns: ColumnDef<Transaction, unknown>[] = [
    {
      header: 'When',
      cell: ({ row }) => (
        <span className="whitespace-nowrap">{formatDateTime(row.original.created_at)}</span>
      ),
    },
    { header: 'What', cell: ({ row }) => REFERENCE[row.original.reference_type] },
    {
      header: 'Details',
      cell: ({ row }) => (
        <span className="line-clamp-2 max-w-80 text-sm text-muted-foreground">
          {row.original.description}
        </span>
      ),
    },
    {
      header: 'Amount',
      meta: { align: 'right' },
      cell: ({ row }) => (
        <span
          className={cn(
            'font-medium',
            row.original.entry_type === 'credit' ? 'text-success-text' : 'text-danger-text',
          )}
        >
          {row.original.entry_type === 'credit' ? '+' : '−'}
          {formatMoney(row.original.amount)}
        </span>
      ),
    },
    {
      header: 'Balance after',
      meta: { align: 'right' },
      cell: ({ row }) => formatMoney(row.original.balance_after),
    },
  ]
  return (
    <>
      {back}
      <PageHeader
        title={`${name}’s wallet`}
        description={
          <span className="inline-flex flex-wrap items-center gap-2">
            <span className="figure">{maskPhone(data.user.phone_number)}</span>
            {data.frozen_at ? <StatusBadge tone="danger" icon={Lock} label="Frozen" /> : null}
            {can('users:manage', 'users:suspend') ? (
              <Link to={`/accounts/${data.user.id}`} className="link-inline">
                Account
              </Link>
            ) : null}
          </span>
        }
      />
      {data.frozen_at ? (
        <p
          role="status"
          className="mb-4 rounded-lg border border-danger/30 bg-danger-soft p-3 text-sm text-danger-text"
        >
          Frozen {formatDateTime(data.frozen_at)}
          {data.frozen_reason ? `: “${data.frozen_reason}”` : ''}. No payments or payouts leave it;
          admin adjustments still can.
        </p>
      ) : null}
      <div className="mb-6 grid gap-3 sm:grid-cols-3">
        <StatTile label="Balance" value={formatMoney(data.balance)} />
        <StatTile
          label="Held for payouts"
          value={formatMoney(data.held_for_withdrawals)}
          note="Asked for and not paid out yet"
        />
        <StatTile label="Transactions" value={String(data.transactions_total)} />
      </div>
      <div className="grid gap-6 xl:grid-cols-3">
        <Section title="Transactions" className="xl:col-span-2">
          <DataTable
            columns={columns}
            rows={data.transactions}
            total={data.transactions_total}
            getRowId={(row) => row.id}
            caption="Wallet transactions"
            isPending={false}
            isError={false}
            isFetching={wallet.isFetching}
            page={page}
            pageSize={limit}
            onPageChange={setPage}
            empty={<EmptyState icon={Wallet} title="No transactions yet" />}
          />
        </Section>
        <Adjust wallet={data} />
      </div>
    </>
  )
}

function FindWallet() {
  const { can } = useSession()
  const navigate = useNavigate()
  const searchId = useId()
  const idId = useId()
  const [text, setText] = useState('')
  const [userId, setUserId] = useState('')
  const search = useDebounced(text, 300)
  const finds = can('users:manage', 'users:suspend')
  const accounts = useAccounts(
    search,
    { role: '', status: '', sort: '' },
    1,
    8,
    finds && search.trim().length >= 3,
  )
  return (
    <>
      <PageHeader
        title="Wallets"
        description="Balances and transactions, and adjustments with a reason. Open a wallet from an account, a payout or a fraud flag, or find it here."
      />
      <div className="grid max-w-3xl gap-6">
        {finds ? (
          <div className="grid gap-1.5">
            <Label htmlFor={searchId}>Whose wallet</Label>
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
                placeholder="Name, phone or email (3 letters or more)"
                onChange={(event) => setText(event.target.value)}
              />
            </div>
            {accounts.data?.items.length ? (
              <ul className="divide-y rounded-lg border bg-card" aria-label="Accounts found">
                {accounts.data.items.map((account) => (
                  <li key={account.id}>
                    <Link
                      to={`/wallets/${account.id}`}
                      className="flex items-center justify-between gap-3 px-3 py-2 text-sm hover:bg-muted"
                    >
                      <span>{account.full_name ?? 'No name given'}</span>
                      <span className="figure text-xs text-muted-foreground">
                        {maskPhone(account.phone_number)}
                      </span>
                    </Link>
                  </li>
                ))}
              </ul>
            ) : search.trim().length >= 3 && accounts.data ? (
              <p className="text-sm text-muted-foreground">Nobody matches.</p>
            ) : null}
          </div>
        ) : null}
        <form
          className="grid gap-1.5"
          onSubmit={(event) => {
            event.preventDefault()
            if (/^[0-9a-f-]{36}$/i.test(userId.trim())) navigate(`/wallets/${userId.trim()}`)
            else toast.error('That isn’t an account id.')
          }}
        >
          <Label htmlFor={idId}>Or the account’s id</Label>
          <div className="flex gap-2">
            <Input
              id={idId}
              value={userId}
              placeholder="00000000-0000-0000-0000-000000000000"
              onChange={(event) => setUserId(event.target.value)}
            />
            <Button type="submit" variant="outline">
              Open
            </Button>
          </div>
        </form>
      </div>
    </>
  )
}

export default function WalletsPage() {
  return (
    <Routes>
      <Route index element={<FindWallet />} />
      <Route path=":userId" element={<WalletPage />} />
      <Route path="*" element={<NotFoundPage />} />
    </Routes>
  )
}
