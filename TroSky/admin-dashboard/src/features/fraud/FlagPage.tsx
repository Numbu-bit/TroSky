import {
  ArrowLeft,
  Ban,
  CircleCheck,
  CircleSlash,
  Lock,
  LockOpen,
  RotateCcw,
  Search,
  Smartphone,
  UserCheck,
  UserMinus,
} from 'lucide-react'
import { useId, useState, type ReactNode } from 'react'
import { Link, useParams } from 'react-router'
import { toast } from 'sonner'

import { errorMessage, isApiError } from '@/api/errors'
import { useSession } from '@/app/auth/auth-context'
import { ConfirmButton } from '@/components/confirm/ConfirmButton'
import { ConfirmFacts } from '@/components/confirm/ConfirmDialog'
import { EmptyState, ErrorState, PageSkeleton } from '@/components/feedback/states'
import { PageHeader, Section } from '@/components/layout/PageHeader'
import { StatusBadge } from '@/components/status/StatusBadge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Label } from '@/components/ui/label'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import { formatDateTime, formatMoney, humanize, maskPhone } from '@/lib/format'
import { isModuleEnabled } from '@/lib/modules'

import {
  useFlag,
  useFlagAction,
  useFraudTeam,
  useUpdateFlag,
  type FlagDetail,
  type FraudAction,
} from './api'
import { RiskBadge } from './FlagsPanel'
import { ACTIONS, FLAG_STATUS, SEVERITY } from './labels'

function BackLink() {
  return (
    <Button asChild variant="ghost" size="sm" className="mb-2 -ml-2">
      <Link to="/fraud">
        <ArrowLeft aria-hidden /> Fraud & risk
      </Link>
    </Button>
  )
}

/** Evidence values as text: never rendered as HTML. */
function evidenceValue(value: unknown): string {
  if (value === null || value === undefined) return '—'
  if (Array.isArray(value)) return value.map(evidenceValue).join(', ')
  if (typeof value === 'object') return JSON.stringify(value)
  return String(value)
}

function event(entry: FlagDetail['timeline'][number]): { title: string; note?: ReactNode } {
  const who = entry.actor_name ?? (entry.actor_id ? 'An admin' : 'The checks')
  const details = entry.details as Record<string, unknown>
  switch (entry.kind) {
    case 'detected':
      return {
        title: 'Found by the checks',
        note: details.observed ? `Seen: ${String(details.observed)}` : undefined,
      }
    case 'detected_again':
      return { title: 'Found again by the checks' }
    case 'assigned':
      return {
        title:
          details.assigned_to && details.assigned_to !== 'null'
            ? `${who} assigned it`
            : `${who} unassigned it`,
      }
    case 'status_changed': {
      const to = FLAG_STATUS[details.to as keyof typeof FLAG_STATUS]?.label ?? String(details.to)
      return {
        title: `${who} set it to “${to}”`,
        note: details.reason ? `“${String(details.reason)}”` : undefined,
      }
    }
    case 'action': {
      const action =
        ACTIONS[details.action as FraudAction]?.label ?? humanize(String(details.action))
      return {
        title: `${who}: ${action.toLowerCase()}`,
        note: details.reason ? `“${String(details.reason)}”` : undefined,
      }
    }
    default:
      return { title: `${who}: ${humanize(entry.kind)}` }
  }
}

function Review({ flag }: { flag: FlagDetail }) {
  const { me } = useSession()
  const update = useUpdateFlag(flag.id)
  const team = useFraudTeam()
  const assigneeId = useId()
  const open = flag.status === 'open' || flag.status === 'investigating'
  const change = async (body: Parameters<typeof update.mutateAsync>[0], done: string) => {
    try {
      await update.mutateAsync(body)
      toast.success(done)
    } catch (error) {
      toast.error(errorMessage(error))
    }
  }
  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-base">Review</CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        {team.data?.length ? (
          <div className="grid gap-1.5">
            <Label htmlFor={assigneeId}>With</Label>
            <Select
              value={flag.assigned_to ?? 'nobody'}
              onValueChange={(value) =>
                void change(
                  { assigned_to: value === 'nobody' ? null : value },
                  value === 'nobody' ? 'Unassigned.' : 'Assigned.',
                )
              }
            >
              <SelectTrigger id={assigneeId}>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="nobody">Nobody yet</SelectItem>
                {team.data.map((member) => (
                  <SelectItem key={member.id} value={member.id}>
                    {member.full_name ?? member.phone_number}
                    {member.id === me.id ? ' (you)' : ''}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
        ) : (
          <div className="space-y-2">
            <p className="text-sm">
              <span className="text-muted-foreground">With: </span>
              {flag.assigned_to === me.id ? 'You' : (flag.assignee_name ?? 'Nobody yet')}
            </p>
            {flag.assigned_to === me.id ? (
              <Button
                size="sm"
                variant="outline"
                onClick={() => void change({ assigned_to: null }, 'Unassigned.')}
              >
                <UserMinus aria-hidden /> Give it back
              </Button>
            ) : (
              <Button
                size="sm"
                variant="outline"
                onClick={() => void change({ assigned_to: me.id }, 'It’s yours.')}
              >
                <UserCheck aria-hidden /> Take it
              </Button>
            )}
          </div>
        )}
        <div className="flex flex-wrap gap-2">
          {flag.status === 'open' ? (
            <Button
              size="sm"
              variant="outline"
              onClick={() =>
                void change({ status: 'investigating' }, 'Marked as being looked into.')
              }
            >
              <Search aria-hidden /> Start looking into it
            </Button>
          ) : null}
          {open ? (
            <>
              <ConfirmButton
                size="sm"
                label="Confirm fraud"
                icon={CircleCheck}
                title="Confirm this is fraud?"
                description="It closes as confirmed. Act on the account below as well, if you haven't."
                confirmLabel="Confirm fraud"
                destructive
                reason={{
                  label: 'Why (kept with the flag)',
                  required: true,
                  minLength: 5,
                  maxLength: 1000,
                }}
                onConfirm={async (reason) => {
                  await update.mutateAsync({ status: 'confirmed', reason })
                  toast.success('Confirmed as fraud.')
                }}
              />
              <ConfirmButton
                size="sm"
                variant="outline"
                label="False alarm"
                icon={CircleSlash}
                title="Close this as a false alarm?"
                description="It closes; the rule's precision counts it."
                confirmLabel="False alarm"
                reason={{
                  label: 'Why (kept with the flag)',
                  required: true,
                  minLength: 5,
                  maxLength: 1000,
                }}
                onConfirm={async (reason) => {
                  await update.mutateAsync({ status: 'false_positive', reason })
                  toast.success('Closed as a false alarm.')
                }}
              />
            </>
          ) : (
            <ConfirmButton
              size="sm"
              variant="outline"
              label="Reopen"
              icon={RotateCcw}
              title="Reopen this flag?"
              description="Its review is cleared and it goes back to open."
              confirmLabel="Reopen"
              onConfirm={async () => {
                await update.mutateAsync({ status: 'open' })
                toast.success('Reopened.')
              }}
            />
          )}
        </div>
        {flag.review_reason ? (
          <p className="text-sm text-muted-foreground">
            Reviewed {flag.reviewed_at ? formatDateTime(flag.reviewed_at) : ''}: “
            {flag.review_reason}”
          </p>
        ) : null}
      </CardContent>
    </Card>
  )
}

function Actions({ flag }: { flag: FlagDetail }) {
  const act = useFlagAction(flag.id)
  const targetId = useId()
  const [target, setTarget] = useState(flag.subject_user_id ?? flag.users[0]?.id ?? '')
  const user = flag.users.find((candidate) => candidate.id === target)
  const name = user?.full_name ?? 'this account'
  const run = (action: FraudAction, icon: typeof Ban, warning: string) => (
    <ConfirmButton
      key={action}
      size="sm"
      variant={ACTIONS[action].destructive ? 'outline' : 'ghost'}
      label={ACTIONS[action].label}
      icon={icon}
      title={`${ACTIONS[action].label}${action.includes('device') ? '' : ` of ${name}`}?`}
      description={warning}
      details={
        action.includes('device') ? undefined : (
          <ConfirmFacts
            rows={[
              ['Account', name],
              ['Phone', maskPhone(user?.phone_number)],
            ]}
          />
        )
      }
      confirmLabel={ACTIONS[action].label}
      destructive={ACTIONS[action].destructive}
      reason={{
        label: 'Reason (kept with the flag and the account)',
        required: true,
        minLength: 5,
        maxLength: 500,
      }}
      onConfirm={async (reason) => {
        await act.mutateAsync({
          action,
          reason,
          user_id: action.includes('device') ? null : target || null,
          device_id: null,
        })
        toast.success(ACTIONS[action].done)
      }}
    />
  )
  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-base">Act</CardTitle>
      </CardHeader>
      <CardContent className="space-y-3">
        {flag.users.length ? (
          <>
            <div className="grid gap-1.5">
              <Label htmlFor={targetId}>Account</Label>
              <Select value={target} onValueChange={setTarget}>
                <SelectTrigger id={targetId}>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {flag.users.map((candidate) => (
                    <SelectItem key={candidate.id} value={candidate.id}>
                      {candidate.full_name ?? maskPhone(candidate.phone_number)}
                      {candidate.id === flag.subject_user_id ? ' (main)' : ''}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="flex flex-wrap gap-2">
              {user && !user.is_suspended
                ? run(
                    'suspend_account',
                    Ban,
                    'They are signed out of every device now and can’t sign in until reactivated.',
                  )
                : null}
              {user?.wallet_frozen
                ? run(
                    'unfreeze_wallet',
                    LockOpen,
                    'Payments and payouts can leave the wallet again.',
                  )
                : run(
                    'freeze_wallet',
                    Lock,
                    'No payments or payouts leave the wallet until it is unfrozen.',
                  )}
            </div>
            {user?.is_suspended ? (
              <p className="text-xs text-muted-foreground">This account is suspended.</p>
            ) : null}
          </>
        ) : null}
        {flag.entity_type === 'device' ? (
          <div className="flex flex-wrap gap-2">
            {flag.device_blocked
              ? run('unblock_device', Smartphone, 'Accounts can sign in on this device again.')
              : run('block_device', Smartphone, 'No account can sign in on this device.')}
          </div>
        ) : null}
      </CardContent>
    </Card>
  )
}

/** One flag: the evidence, what it is linked to, what happened, and the review. */
export function FlagPage() {
  const { flagId = '' } = useParams()
  const { can } = useSession()
  const flag = useFlag(flagId)
  if (flag.isPending) return <PageSkeleton />
  if (flag.isError) {
    return (
      <>
        <BackLink />
        {isApiError(flag.error, 404) ? (
          <EmptyState title="Flag not found" description="The link may be wrong or old." />
        ) : (
          <ErrorState error={flag.error} onRetry={() => void flag.refetch()} />
        )}
      </>
    )
  }
  const data = flag.data
  const status = FLAG_STATUS[data.status]
  const manages = can('fraud:manage')
  return (
    <>
      <BackLink />
      <PageHeader
        title={data.summary}
        description={
          <span className="inline-flex flex-wrap items-center gap-2">
            <RiskBadge score={data.risk_score} severity={data.severity} />
            <StatusBadge
              tone={SEVERITY[data.severity].tone}
              label={`${SEVERITY[data.severity].label} severity`}
            />
            <StatusBadge tone={status.tone} label={status.label} icon={status.icon} />
            <span>{data.rule_title}</span>
          </span>
        }
      />
      <div className="grid gap-6 lg:grid-cols-3">
        <div className="space-y-6 lg:col-span-2">
          <Section title="Evidence">
            <dl className="grid gap-x-6 gap-y-2 rounded-lg border bg-card p-4 text-sm sm:grid-cols-2">
              {Object.entries(data.evidence as Record<string, unknown>).map(([key, value]) => (
                <div key={key}>
                  <dt className="text-xs text-muted-foreground">{humanize(key)}</dt>
                  <dd className="figure wrap-break-word">{evidenceValue(value)}</dd>
                </div>
              ))}
              <div>
                <dt className="text-xs text-muted-foreground">Money at risk</dt>
                <dd className="figure">
                  {data.amount_at_risk === null ? '—' : formatMoney(data.amount_at_risk)}
                </dd>
              </div>
              <div>
                <dt className="text-xs text-muted-foreground">Found</dt>
                <dd>
                  {formatDateTime(data.first_detected_at)}
                  {data.occurrences > 1
                    ? ` · ${data.occurrences} times, last ${formatDateTime(data.last_detected_at)}`
                    : ''}
                </dd>
              </div>
            </dl>
          </Section>
          <Section title="Linked to">
            <div className="grid gap-4 sm:grid-cols-2">
              {data.users.length ? (
                <div>
                  <h3 className="mb-1 text-sm font-semibold">Accounts</h3>
                  <ul className="space-y-1 text-sm">
                    {data.users.map((user) => (
                      <li key={user.id} className="flex flex-wrap items-center gap-2">
                        {can('users:manage', 'users:suspend') ? (
                          <Link to={`/accounts/${user.id}`} className="link-inline">
                            {user.full_name ?? maskPhone(user.phone_number)}
                          </Link>
                        ) : (
                          <span>{user.full_name ?? maskPhone(user.phone_number)}</span>
                        )}
                        <span className="figure text-xs text-muted-foreground">
                          {maskPhone(user.phone_number)}
                        </span>
                        {user.is_suspended ? <StatusBadge tone="danger" label="Suspended" /> : null}
                        {user.wallet_frozen ? (
                          <StatusBadge tone="warning" icon={Lock} label="Wallet frozen" />
                        ) : null}
                        {isModuleEnabled('wallets') && can('wallet:adjust') ? (
                          <Link to={`/wallets/${user.id}`} className="link-inline text-xs">
                            Wallet
                          </Link>
                        ) : null}
                      </li>
                    ))}
                  </ul>
                </div>
              ) : null}
              {data.trips.length ? (
                <div>
                  <h3 className="mb-1 text-sm font-semibold">Trips</h3>
                  <ul className="space-y-1 text-sm">
                    {data.trips.map((trip) => (
                      <li key={trip.id}>
                        <Link to={`/trips/${trip.id}`} className="link-inline">
                          {trip.route_name ?? 'Trip'}
                        </Link>{' '}
                        <span className="text-xs text-muted-foreground">
                          {trip.scheduled_departure_at
                            ? formatDateTime(trip.scheduled_departure_at)
                            : ''}
                        </span>
                      </li>
                    ))}
                  </ul>
                </div>
              ) : null}
              {data.bookings.length ? (
                <div>
                  <h3 className="mb-1 text-sm font-semibold">Bookings</h3>
                  <ul className="space-y-1 text-sm">
                    {data.bookings.map((booking) => (
                      <li key={booking.id}>
                        <Link to={`/bookings?booking=${booking.id}`} className="figure link-inline">
                          {booking.booking_reference ?? booking.id.slice(0, 8)}
                        </Link>{' '}
                        <span className="text-xs text-muted-foreground">
                          {humanize(booking.status)}
                        </span>
                      </li>
                    ))}
                  </ul>
                </div>
              ) : null}
              {data.payments.length ? (
                <div>
                  <h3 className="mb-1 text-sm font-semibold">Payments</h3>
                  <ul className="space-y-1 text-sm">
                    {data.payments.map((payment) => (
                      <li key={payment.id} className="figure">
                        {payment.internal_reference} ·{' '}
                        {payment.amount ? formatMoney(payment.amount) : '—'} ·{' '}
                        {humanize(payment.status)}
                      </li>
                    ))}
                  </ul>
                </div>
              ) : null}
            </div>
          </Section>
          <Section title="What happened">
            <ol className="space-y-3 border-l pl-4">
              {data.timeline.map((entry) => {
                const described = event(entry)
                return (
                  <li key={entry.id} className="text-sm">
                    <p>{described.title}</p>
                    <p className="text-xs text-muted-foreground">
                      {formatDateTime(entry.created_at)}
                    </p>
                    {described.note ? (
                      <p className="text-xs text-muted-foreground">{described.note}</p>
                    ) : null}
                  </li>
                )
              })}
            </ol>
          </Section>
        </div>
        <div className="space-y-6">
          {manages ? (
            <>
              <Review flag={data} />
              <Actions flag={data} />
            </>
          ) : (
            <p className="text-sm text-muted-foreground">
              Reviewing and acting on flags needs fraud:manage.
            </p>
          )}
        </div>
      </div>
    </>
  )
}
