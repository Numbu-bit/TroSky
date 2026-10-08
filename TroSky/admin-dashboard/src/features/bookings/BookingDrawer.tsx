import { ArrowRight, Ban, Eye, LogOut } from 'lucide-react'
import { useState, type ReactNode } from 'react'
import { Link } from 'react-router'
import { toast } from 'sonner'

import type { Schemas } from '@/api/types'
import { useSession } from '@/app/auth/auth-context'
import { ConfirmButton } from '@/components/confirm/ConfirmButton'
import { ConfirmFacts } from '@/components/confirm/ConfirmDialog'
import { ErrorState } from '@/components/feedback/states'
import { StatusBadge } from '@/components/status/StatusBadge'
import { Button } from '@/components/ui/button'
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetHeader,
  SheetTitle,
} from '@/components/ui/sheet'
import { Skeleton } from '@/components/ui/skeleton'
import { useDriverActions, useMarkOff } from '@/features/dispatch/api'
import { ACTION_KINDS } from '@/features/dispatch/labels'
import { BOOKING_STATUS, CHANNEL_LABELS, PAYMENT_STATUS } from '@/features/shared/money'
import { tripStatusTone } from '@/features/trips/status'
import { formatDateTime, formatMoney, formatPhone, humanize, maskPhone } from '@/lib/format'

import { useBooking, useBookingPayments, useBookingTickets, useCancelBooking } from './api'

type Booking = Schemas['BookingResponse']

const NOT_CANCELLABLE = new Set(['cancelled', 'expired', 'completed', 'refunded', 'refund_pending'])
const TICKET_STATUS: Record<
  Schemas['TicketStatus'],
  { tone: 'success' | 'info' | 'neutral' | 'danger'; label: string }
> = {
  issued: { tone: 'info', label: 'Issued' },
  validated: { tone: 'success', label: 'Scanned on board' },
  expired: { tone: 'neutral', label: 'Expired' },
  revoked: { tone: 'danger', label: 'Revoked' },
}

function Block({ title, children }: { title: string; children: ReactNode }) {
  return (
    <section className="space-y-2 py-3" aria-label={title}>
      <h3 className="text-sm font-semibold">{title}</h3>
      {children}
    </section>
  )
}

/** A phone number shown masked until the admin asks to see it. */
function Phone({ number }: { number: string | null }) {
  const [shown, setShown] = useState(false)
  if (!number) return <span className="text-muted-foreground">No phone</span>
  return shown ? (
    <a className="figure link-inline" href={`tel:${number}`}>
      {formatPhone(number)}
    </a>
  ) : (
    <span className="inline-flex items-center gap-1">
      <span className="figure">{maskPhone(number)}</span>
      <Button
        size="icon"
        variant="ghost"
        className="size-6"
        onClick={() => setShown(true)}
        aria-label="Show the full number"
      >
        <Eye className="size-3.5" aria-hidden />
      </Button>
    </span>
  )
}

/** What cancelling does now, by the trip's state and whether it was paid. */
function cancelConsequence(booking: Booking): string {
  const trip = booking.trip?.status
  if (booking.status === 'awaiting_acceptance') {
    return 'No driver has accepted it yet and nothing was paid: it is cancelled at once.'
  }
  if (trip === 'scheduled') {
    return booking.status === 'confirmed'
      ? `It is cancelled at once, and a refund of ${formatMoney(booking.total_amount)} goes to the refund queue for approval.`
      : 'It is cancelled at once. Nothing was paid, so there is nothing to refund.'
  }
  return 'The trip has started, so the cancellation goes to the queue for a decision. The booking stays as it is until then.'
}

function Passengers({ booking, onTheRoad }: { booking: Booking; onTheRoad: boolean }) {
  const { can } = useSession()
  const markOff = useMarkOff()
  const actions = useDriverActions(
    { trip: booking.trip_id, kind: 'passenger_alighted' },
    1,
    100,
    can('trips:manage', 'trips:monitor_live'),
  )
  const off = new Set(
    (actions.data?.items ?? [])
      .filter((action) => action.booking_id === booking.id)
      .flatMap((action) => {
        const ids = (action.details as { passenger_ids?: string[] } | null)?.passenger_ids
        return Array.isArray(ids) ? ids : []
      }),
  )
  const canMark = can('trips:manage') && onTheRoad && booking.status === 'confirmed'
  return (
    <ul className="divide-y rounded-md border">
      {booking.passengers.map((passenger) => (
        <li key={passenger.id} className="flex flex-wrap items-center gap-2 px-3 py-2 text-sm">
          <div className="min-w-0 flex-1">
            <p className="font-medium">{passenger.full_name}</p>
            <Phone number={passenger.phone_number} />
          </div>
          {off.has(passenger.id) ? (
            <StatusBadge tone="neutral" icon={LogOut} label="Got off" />
          ) : canMark ? (
            <ConfirmButton
              size="sm"
              variant="outline"
              icon={LogOut}
              label="Got off"
              title={`Mark ${passenger.full_name} off the bus?`}
              description="Their seat is free for the rest of the trip, so another passenger can book it."
              confirmLabel="Mark off"
              onConfirm={async () => {
                await markOff.mutateAsync({ tripId: booking.trip_id, passengerId: passenger.id })
                toast.success(`${passenger.full_name} is marked off. The seat is free again.`)
              }}
            />
          ) : null}
        </li>
      ))}
    </ul>
  )
}

function BookingBody({ booking }: { booking: Booking }) {
  const { can } = useSession()
  const tickets = useBookingTickets(booking.id, true)
  const payments = useBookingPayments(booking)
  const history = useDriverActions(
    { trip: booking.trip_id },
    1,
    100,
    can('trips:manage', 'trips:monitor_live'),
  )
  const cancel = useCancelBooking()
  const trip = booking.trip
  const onTheRoad = trip ? ['in_progress', 'paused'].includes(trip.status) : false
  const ofThisBooking = (history.data?.items ?? []).filter(
    (action) => action.booking_id === booking.id,
  )

  return (
    <div className="divide-y px-4">
      {trip ? (
        <Block title="Trip">
          <p className="text-sm">
            <span className="font-medium">{trip.route_name}</span>{' '}
            <StatusBadge tone={tripStatusTone(trip.status)} label={humanize(trip.status)} />
          </p>
          <p className="text-sm text-muted-foreground">
            {booking.boarding_stop_name ?? trip.origin_stop_name}{' '}
            <ArrowRight className="inline size-3" aria-label="to" />{' '}
            {booking.alighting_stop_name ?? trip.destination_stop_name} · leaves{' '}
            {formatDateTime(trip.scheduled_departure_at)}
            {trip.vehicle_registration_number ? ` · ${trip.vehicle_registration_number}` : ''}
          </p>
          {can('trips:manage', 'trips:monitor_live') ? (
            <Link to={`/trips/${booking.trip_id}`} className="link-inline text-sm">
              Open the trip
            </Link>
          ) : null}
        </Block>
      ) : null}

      <Block
        title={
          booking.passenger_count === 1 ? 'Passenger' : `${booking.passenger_count} passengers`
        }
      >
        <Passengers booking={booking} onTheRoad={onTheRoad} />
      </Block>

      <Block title="Money">
        <ConfirmFacts
          rows={[
            ['Fare', formatMoney(booking.fare_amount)],
            ['Platform fee', formatMoney(booking.platform_fee)],
            ['Total', formatMoney(booking.total_amount)],
          ]}
        />
        {can('payments:review', 'refunds:approve', 'reports:view') ? (
          payments.isPending ? (
            <Skeleton className="h-10" />
          ) : payments.isError ? (
            <ErrorState error={payments.error} onRetry={() => void payments.refetch()} />
          ) : payments.data.items.length ? (
            <ul className="space-y-1 text-sm" aria-label="Payments">
              {payments.data.items.map((payment) => (
                <li key={payment.id} className="flex flex-wrap items-center gap-2">
                  <StatusBadge
                    tone={PAYMENT_STATUS[payment.status].tone}
                    label={PAYMENT_STATUS[payment.status].label}
                  />
                  <span>
                    {formatMoney(payment.amount)} by {CHANNEL_LABELS[payment.method]}
                  </span>
                  <span className="figure text-xs text-muted-foreground">{payment.reference}</span>
                  {Number(payment.refunded_amount) > 0 ? (
                    <span className="text-xs text-muted-foreground">
                      {formatMoney(payment.refunded_amount)} refunded
                    </span>
                  ) : null}
                </li>
              ))}
            </ul>
          ) : (
            <p className="text-sm text-muted-foreground">No payment yet.</p>
          )
        ) : null}
      </Block>

      <Block title="Tickets">
        {tickets.isPending ? (
          <Skeleton className="h-10" />
        ) : tickets.isError ? (
          <ErrorState error={tickets.error} onRetry={() => void tickets.refetch()} />
        ) : tickets.data.length ? (
          <ul className="space-y-1 text-sm">
            {tickets.data.map((ticket) => (
              <li key={ticket.id} className="flex flex-wrap items-center gap-2">
                <span className="figure">{ticket.ticket_reference}</span>
                <StatusBadge
                  tone={TICKET_STATUS[ticket.status].tone}
                  label={TICKET_STATUS[ticket.status].label}
                />
                {ticket.validated_at ? (
                  <span className="text-xs text-muted-foreground">
                    {formatDateTime(ticket.validated_at)}
                  </span>
                ) : null}
              </li>
            ))}
          </ul>
        ) : (
          <p className="text-sm text-muted-foreground">Tickets are issued once it is paid.</p>
        )}
      </Block>

      {can('trips:manage', 'trips:monitor_live') && ofThisBooking.length ? (
        <Block title="What drivers did">
          <ol className="space-y-1 text-sm">
            {ofThisBooking.map((action) => (
              <li key={action.id} className="flex flex-wrap items-center gap-2">
                <StatusBadge
                  tone={ACTION_KINDS[action.kind].tone}
                  icon={ACTION_KINDS[action.kind].icon}
                  label={ACTION_KINDS[action.kind].label}
                />
                <span className="text-xs text-muted-foreground">
                  {formatDateTime(action.created_at)}
                  {action.acted_as !== 'driver'
                    ? ` · by ${action.actor_name ?? action.acted_as}`
                    : ''}
                </span>
              </li>
            ))}
          </ol>
        </Block>
      ) : null}

      {booking.status === 'awaiting_acceptance' && can('trips:manage') ? (
        <p className="py-3 text-sm text-muted-foreground">
          Waiting for the driver’s answer: answer it for them in{' '}
          <Link to="/dispatch" className="link-inline">
            Dispatch
          </Link>
          .
        </p>
      ) : null}

      {!NOT_CANCELLABLE.has(booking.status) ? (
        <div className="py-4">
          <ConfirmButton
            label="Cancel booking"
            icon={Ban}
            variant="outline"
            title={`Cancel ${booking.booking_reference}?`}
            description={cancelConsequence(booking)}
            details={
              <ConfirmFacts
                rows={[
                  ['Passenger', booking.passengers[0]?.full_name ?? '—'],
                  [
                    'Paid',
                    booking.status === 'confirmed'
                      ? formatMoney(booking.total_amount)
                      : 'Nothing yet',
                  ],
                  [
                    'Trip',
                    trip
                      ? `${trip.route_name}, ${formatDateTime(trip.scheduled_departure_at)}`
                      : '—',
                  ],
                ]}
              />
            }
            confirmLabel="Cancel booking"
            destructive
            reason={{
              label: 'Reason (the passenger sees it)',
              required: true,
              maxLength: 500,
              placeholder: 'e.g. Booked twice by mistake.',
            }}
            onConfirm={async (reason) => {
              const result = await cancel.mutateAsync({ id: booking.id, reason })
              toast.success(
                result.status === 'refund_pending'
                  ? `Cancelled. A refund of ${formatMoney(result.total_amount)} is waiting for approval.`
                  : result.status === 'cancelled'
                    ? 'Cancelled.'
                    : 'Sent for a decision: it is in Cancellations.',
              )
            }}
          />
        </div>
      ) : null}
    </div>
  )
}

/** One booking: trip, passengers, money, tickets and what happened. */
export function BookingDrawer({
  bookingId,
  onClose,
}: {
  bookingId: string | null
  onClose: () => void
}) {
  const booking = useBooking(bookingId)
  const status = booking.data ? BOOKING_STATUS[booking.data.status] : null
  return (
    <Sheet open={Boolean(bookingId)} onOpenChange={(open) => !open && onClose()}>
      <SheetContent className="w-full overflow-y-auto sm:max-w-lg">
        <SheetHeader>
          <SheetTitle className="figure">{booking.data?.booking_reference ?? 'Booking'}</SheetTitle>
          <SheetDescription asChild>
            <div className="flex flex-wrap items-center gap-2">
              {status ? <StatusBadge tone={status.tone} label={status.label} /> : null}
              {booking.data ? (
                <span>
                  Booked {formatDateTime(booking.data.created_at)} ·{' '}
                  {booking.data.passengers.length} seat
                  {booking.data.passengers.length === 1 ? '' : 's'}
                </span>
              ) : null}
            </div>
          </SheetDescription>
        </SheetHeader>
        {booking.isPending ? (
          <div className="space-y-3 px-4">
            <Skeleton className="h-16" />
            <Skeleton className="h-24" />
          </div>
        ) : booking.isError ? (
          <ErrorState error={booking.error} onRetry={() => void booking.refetch()} />
        ) : (
          <BookingBody booking={booking.data} />
        )}
      </SheetContent>
    </Sheet>
  )
}
