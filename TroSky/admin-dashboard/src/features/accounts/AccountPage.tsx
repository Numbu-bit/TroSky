import {
  ArrowLeft,
  BadgeCheck,
  CircleSlash,
  LogOut,
  MonitorSmartphone,
  RotateCcw,
  ShieldAlert,
  Star,
} from 'lucide-react'
import { useState, type ReactNode } from 'react'
import { Link, useParams } from 'react-router'
import { toast } from 'sonner'

import { isApiError } from '@/api/errors'
import { useSession } from '@/app/auth/auth-context'
import { ConfirmButton } from '@/components/confirm/ConfirmButton'
import { ConfirmFacts } from '@/components/confirm/ConfirmDialog'
import { EmptyState, ErrorState, PageSkeleton } from '@/components/feedback/states'
import { PageHeader, Section } from '@/components/layout/PageHeader'
import { StatusBadge } from '@/components/status/StatusBadge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Skeleton } from '@/components/ui/skeleton'
import { CHANNEL_LABELS, type Channel } from '@/features/shared/money'
import {
  formatDate,
  formatDateTime,
  formatMoney,
  formatNumber,
  formatPhone,
  formatRelative,
  maskPhone,
} from '@/lib/format'
import { isModuleEnabled } from '@/lib/modules'
import { useNow } from '@/lib/use-now'

import {
  useAccount,
  useAccountSessions,
  useEndSession,
  useSuspension,
  type AccountDetail,
} from './api'
import { accountStatus, ROLE_NAMES } from './labels'

function Fact({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div className="flex justify-between gap-3 py-1.5 text-sm">
      <dt className="text-muted-foreground">{label}</dt>
      <dd className="min-w-0 text-right">{children}</dd>
    </div>
  )
}

function Count({ label, value }: { label: string; value: number | undefined }) {
  return (
    <div className="rounded-lg border bg-card p-3">
      <p className="text-xs text-muted-foreground">{label}</p>
      <p className="figure text-xl">{formatNumber(value ?? 0)}</p>
    </div>
  )
}

function Sessions({ account }: { account: AccountDetail }) {
  const sessions = useAccountSessions(account.id, true)
  const end = useEndSession(account.id)
  const now = useNow(60_000)
  return (
    <Section
      title="Signed in on"
      description="Each device the account is signed in with. Signing one out ends that session only."
    >
      {sessions.isPending ? (
        <Skeleton className="h-24" />
      ) : sessions.isError ? (
        <ErrorState error={sessions.error} onRetry={() => void sessions.refetch()} />
      ) : sessions.data.length ? (
        <ul className="divide-y rounded-lg border bg-card">
          {sessions.data.map((session) => (
            <li key={session.id} className="flex flex-wrap items-center gap-3 px-3 py-2 text-sm">
              <MonitorSmartphone className="size-4 shrink-0 text-muted-foreground" aria-hidden />
              <div className="min-w-0 flex-1">
                <p className="font-medium">{session.device_name ?? 'Unknown device'}</p>
                <p className="truncate text-xs text-muted-foreground">
                  {session.ip_address ?? 'No IP'} · signed in {formatDate(session.created_at)} ·
                  last seen {formatRelative(session.last_seen_at, now)}
                </p>
              </div>
              <ConfirmButton
                size="sm"
                variant="ghost"
                icon={LogOut}
                label="Sign out"
                title={`Sign ${session.device_name ?? 'this device'} out?`}
                description="They need to sign in again on it. Other devices stay signed in."
                confirmLabel="Sign out"
                onConfirm={async () => {
                  await end.mutateAsync(session.id)
                  toast.success('Signed out of that device.')
                }}
              />
            </li>
          ))}
        </ul>
      ) : (
        <p className="text-sm text-muted-foreground">Not signed in anywhere.</p>
      )}
    </Section>
  )
}

/** One account: who they are, what they have done, and suspend or reactivate. */
export function AccountPage() {
  const { userId = '' } = useParams()
  const { can, me } = useSession()
  const account = useAccount(userId)
  const suspension = useSuspension(userId)
  const [revealed, setRevealed] = useState(false)

  if (account.isPending) return <PageSkeleton />
  if (account.isError) {
    return (
      <>
        <BackLink />
        {isApiError(account.error, 404) ? (
          <EmptyState title="Account not found" description="The link may be wrong or old." />
        ) : (
          <ErrorState error={account.error} onRetry={() => void account.refetch()} />
        )}
      </>
    )
  }
  const data = account.data
  const status = accountStatus(data)
  const name = data.full_name ?? formatPhone(data.phone_number)
  const isMe = data.id === me.id

  return (
    <>
      <BackLink />
      <PageHeader
        title={name}
        description={
          <span className="inline-flex flex-wrap items-center gap-2">
            <StatusBadge tone={status.tone} label={status.label} />
            <span>{data.roles.map((role) => ROLE_NAMES[role] ?? role).join(', ')}</span>
            <span>· joined {formatDate(data.created_at)}</span>
          </span>
        }
        actions={
          can('users:suspend') && !isMe ? (
            data.is_suspended ? (
              <ConfirmButton
                label="Reactivate"
                icon={RotateCcw}
                variant="outline"
                title={`Reactivate ${name}?`}
                description="They can sign in and use TroSky again."
                confirmLabel="Reactivate"
                onConfirm={async () => {
                  await suspension.mutateAsync({ suspend: false, reason: '' })
                  toast.success(`${name} can use TroSky again.`)
                }}
              />
            ) : (
              <ConfirmButton
                label="Suspend"
                icon={CircleSlash}
                variant="outline"
                title={`Suspend ${name}?`}
                description={`This signs them out of every device straight away (${formatNumber(data.active_sessions)} now), and they can’t sign in until reactivated.`}
                details={
                  <ConfirmFacts
                    rows={[
                      ['Account', name],
                      ['Roles', data.roles.map((role) => ROLE_NAMES[role] ?? role).join(', ')],
                      ['Signed in on', `${formatNumber(data.active_sessions)} devices`],
                    ]}
                  />
                }
                confirmLabel="Suspend account"
                destructive
                reason={{
                  label: 'Reason (kept on the account)',
                  required: true,
                  maxLength: 500,
                  placeholder: 'e.g. Repeated fare disputes under review.',
                }}
                onConfirm={async (reason) => {
                  await suspension.mutateAsync({ suspend: true, reason })
                  toast.success(`${name} is suspended and signed out everywhere.`)
                }}
              />
            )
          ) : null
        }
      />
      {data.is_suspended ? (
        <p
          role="status"
          className="mb-4 flex items-start gap-2 rounded-lg border border-danger/30 bg-danger-soft p-3 text-sm text-danger-text"
        >
          <ShieldAlert className="mt-0.5 size-4 shrink-0" aria-hidden />
          Suspended{data.suspended_reason ? `: “${data.suspended_reason}”` : '.'}
        </p>
      ) : null}
      <div className="grid gap-6 lg:grid-cols-3">
        <div className="space-y-6 lg:col-span-2">
          <Section title="Activity">
            <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
              <Count label="Bookings" value={data.bookings.total} />
              <Count label="Paid" value={data.bookings.paid} />
              <Count label="Travelled" value={data.bookings.completed} />
              <Count label="Cancelled" value={data.bookings.cancelled} />
              <Count label="Complaints" value={data.complaints.total} />
              <Count label="Still open" value={data.complaints.open} />
              <Count label="Signed in on" value={data.active_sessions} />
              <Count label="Fraud flags open" value={data.open_fraud_flags} />
            </div>
          </Section>
          {data.favourite_routes.length ? (
            <Section title="Rides most">
              <ul className="space-y-1 text-sm">
                {data.favourite_routes.map((route) => (
                  <li key={route.route_id}>
                    {route.route_name}{' '}
                    <span className="text-muted-foreground">
                      · {formatNumber(route.paid_bookings)} paid bookings
                    </span>
                  </li>
                ))}
              </ul>
            </Section>
          ) : null}
          {can('users:manage') ? <Sessions account={data} /> : null}
        </div>
        <div className="space-y-6">
          <Card>
            <CardHeader>
              <CardTitle className="text-base">Contact</CardTitle>
            </CardHeader>
            <CardContent>
              <dl className="divide-y">
                <Fact label="Phone">
                  {revealed ? (
                    <a className="figure link-inline" href={`tel:${data.phone_number}`}>
                      {formatPhone(data.phone_number)}
                    </a>
                  ) : (
                    <button
                      type="button"
                      className="figure link-inline"
                      onClick={() => setRevealed(true)}
                      aria-label="Show the full number"
                    >
                      {maskPhone(data.phone_number)}
                    </button>
                  )}
                  {data.phone_verified ? (
                    <BadgeCheck
                      className="ml-1 inline size-4 text-success-text"
                      aria-label="Verified"
                    />
                  ) : null}
                </Fact>
                <Fact label="Email">
                  {data.email ?? '—'}
                  {data.email && data.email_verified ? (
                    <BadgeCheck
                      className="ml-1 inline size-4 text-success-text"
                      aria-label="Verified"
                    />
                  ) : null}
                </Fact>
                <Fact label="Language">{data.preferred_language ?? '—'}</Fact>
                <Fact label="Last signed in">
                  {data.last_login_at ? formatDateTime(data.last_login_at) : 'Never'}
                </Fact>
              </dl>
            </CardContent>
          </Card>
          <Card>
            <CardHeader>
              <CardTitle className="text-base">Money</CardTitle>
            </CardHeader>
            <CardContent className="space-y-3">
              <dl className="divide-y">
                <Fact label="Wallet">
                  {formatMoney(data.wallet_balance)}
                  {data.wallet_frozen_at ? (
                    <StatusBadge tone="danger" label="Frozen" className="ml-2" />
                  ) : null}
                </Fact>
              </dl>
              {data.payment_methods.length ? (
                <ul className="space-y-1 text-sm">
                  {data.payment_methods.map((method) => (
                    <li key={method.id} className="flex justify-between gap-2">
                      <span>
                        {CHANNEL_LABELS[method.channel as Channel] ?? method.channel}
                        {method.is_default ? (
                          <span className="text-muted-foreground"> · default</span>
                        ) : null}
                      </span>
                      <span className="figure text-muted-foreground">{method.number}</span>
                    </li>
                  ))}
                </ul>
              ) : (
                <p className="text-sm text-muted-foreground">No saved payment methods.</p>
              )}
              {isModuleEnabled('wallets') && can('wallet:adjust') ? (
                <Button asChild size="sm" variant="outline">
                  <Link to={`/wallets/${data.id}`}>Open the wallet</Link>
                </Button>
              ) : null}
            </CardContent>
          </Card>
          {data.driver_id ? (
            <Card>
              <CardHeader>
                <CardTitle className="text-base">Driver</CardTitle>
              </CardHeader>
              <CardContent className="flex flex-wrap gap-2">
                {can('drivers:approve') ? (
                  <Button asChild size="sm" variant="outline">
                    <Link to={`/driver-ratings?driver=${data.driver_id}`}>
                      <Star aria-hidden /> Ratings
                    </Link>
                  </Button>
                ) : null}
                {isModuleEnabled('fleet') && can('drivers:approve', 'trips:monitor_live') ? (
                  <Button asChild size="sm" variant="outline">
                    <Link to={`/fleet/drivers/${data.driver_id}`}>Driver profile</Link>
                  </Button>
                ) : null}
              </CardContent>
            </Card>
          ) : null}
        </div>
      </div>
    </>
  )
}

function BackLink() {
  return (
    <Button asChild variant="ghost" size="sm" className="mb-2 -ml-2">
      <Link to="/accounts">
        <ArrowLeft aria-hidden /> Accounts
      </Link>
    </Button>
  )
}
