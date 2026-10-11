import { type ColumnDef } from '@tanstack/react-table'
import { ArrowRightLeft, Check, Clock, Inbox, X } from 'lucide-react'
import { useId, useState } from 'react'
import { Link } from 'react-router'
import { toast } from 'sonner'

import { errorMessage } from '@/api/errors'
import type { Schemas } from '@/api/types'
import { useSession } from '@/app/auth/auth-context'
import { ConfirmDialog } from '@/components/confirm/ConfirmDialog'
import { DataTable } from '@/components/data-table/DataTable'
import { EmptyState, QueryState } from '@/components/feedback/states'
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
import { useTrip } from '@/features/live-map/api'
import { useTrips } from '@/features/trips/api'
import { formatDateTime, formatMoney, formatTime } from '@/lib/format'
import { useNow } from '@/lib/use-now'
import { cn } from '@/lib/utils'

import { useAcceptBooking, useBookingRequests, useDeclineBooking, useMoveBooking } from './api'
import { ACTED_AS, ACTION_KINDS } from './labels'

type BookingRequest = Schemas['BookingRequestResponse']

/** Another trip on the same route that day, chosen from a list. */
function MoveDialog({
  request,
  onClose,
  onMove,
}: {
  request: BookingRequest | null
  onClose: () => void
  onMove: (tripId: string) => Promise<void>
}) {
  const current = useTrip(request?.trip_id ?? null)
  const [target, setTarget] = useState('')
  const options = useTrips(
    {
      status: 'scheduled,boarding,in_progress',
      date: request?.trip_departure_at.slice(0, 10) ?? '',
      route: current.data?.route_id ?? '',
      driver: '',
    },
    1,
    50,
  )
  const choices = (options.data?.items ?? []).filter((trip) => trip.trip_id !== request?.trip_id)
  const targetId = useId()
  return (
    <ConfirmDialog
      open={request !== null}
      onOpenChange={(open) => {
        if (!open) {
          onClose()
          setTarget('')
        }
      }}
      title={`Move ${request?.booking_reference ?? 'this booking'}`}
      description="To another trip on the same route that day. It then waits for that trip’s driver."
      confirmLabel="Move"
      details={
        <div className="grid gap-1">
          <Label htmlFor={targetId}>Trip</Label>
          <Select value={target} onValueChange={setTarget}>
            <SelectTrigger id={targetId}>
              <SelectValue
                placeholder={
                  options.isPending || current.isPending ? 'Loading trips…' : 'Choose a trip'
                }
              />
            </SelectTrigger>
            <SelectContent>
              {choices.map((trip) => (
                <SelectItem key={trip.trip_id} value={trip.trip_id}>
                  {formatTime(trip.scheduled_departure_at)} · {trip.driver_name ?? 'no driver'} ·{' '}
                  {trip.available_seats} free
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
          {!options.isPending && choices.length === 0 ? (
            <p className="text-xs text-muted-foreground">No other trip on this route that day.</p>
          ) : null}
        </div>
      }
      onConfirm={async () => {
        if (!target) throw new Error('Choose the trip to move it to.')
        await onMove(target)
        setTarget('')
      }}
    />
  )
}

function Countdown({ until, now }: { until: string; now: number }) {
  const left = Math.max(0, Math.round((Date.parse(until) - now) / 1000))
  const urgent = left <= 30
  return (
    <span
      className={cn('figure inline-flex items-center gap-1 text-sm', urgent && 'text-danger-text')}
      aria-label={left ? `${left} seconds left to answer` : 'Time is up'}
    >
      <Clock className="size-3.5" aria-hidden />
      {left ? `${Math.floor(left / 60)}:${String(left % 60).padStart(2, '0')}` : 'moving on'}
    </span>
  )
}

/** Bookings waiting for a driver's answer, with an admin's answer for them. */
export function BookingRequests({ tripId, driverId }: { tripId?: string; driverId?: string }) {
  const { can } = useSession()
  const requests = useBookingRequests({ tripId, driverId })
  const accept = useAcceptBooking()
  const decline = useDeclineBooking()
  const move = useMoveBooking()
  const now = useNow(1000)
  const [declining, setDeclining] = useState<BookingRequest | null>(null)
  const [moving, setMoving] = useState<BookingRequest | null>(null)
  const [moveOn, setMoveOn] = useState(true)
  const moveOnId = useId()
  const acts = can('trips:manage')

  return (
    <>
      <QueryState
        query={requests}
        isEmpty={(page) => page.items.length === 0}
        empty={
          <EmptyState
            icon={Inbox}
            title="No booking is waiting for a driver"
            description="New requests appear here as passengers book. Unanswered ones move to another vehicle on their own."
          />
        }
      >
        {(page) => (
          <ul className="space-y-2" aria-label="Bookings waiting for a driver">
            {page.items.map((request) => (
              <li
                key={request.offer_id}
                className="flex flex-wrap items-center gap-3 rounded-lg border bg-card p-3"
              >
                <div className="min-w-0 flex-1 space-y-0.5">
                  <p className="font-medium">
                    {request.passenger_name ?? 'A passenger'} · {request.passenger_count} seat
                    {request.passenger_count > 1 ? 's' : ''} ({request.seat_numbers.join(', ')})
                    {request.attempt > 1 ? (
                      <StatusBadge
                        tone="warning"
                        label={`Moved · try ${request.attempt}`}
                        className="ml-2"
                      />
                    ) : null}
                  </p>
                  <p className="text-sm text-muted-foreground">
                    {request.origin_stop_name ?? 'From the start'} →{' '}
                    {request.destination_stop_name ?? 'to the end'} ·{' '}
                    {formatMoney(request.fare_amount)} · leaves{' '}
                    {formatTime(request.trip_departure_at)} ·{' '}
                    <Link to={`/trips/${request.trip_id}`} className="link-inline">
                      trip
                    </Link>{' '}
                    · {request.booking_reference}
                  </p>
                </div>
                <Countdown until={request.expires_at} now={now} />
                {acts ? (
                  <div className="flex gap-1">
                    <Button
                      size="sm"
                      disabled={accept.isPending}
                      onClick={async () => {
                        try {
                          await accept.mutateAsync(request.booking_id)
                          toast.success(
                            `Accepted ${request.booking_reference}. The passenger is asked to pay.`,
                          )
                        } catch (error) {
                          toast.error(errorMessage(error))
                        }
                      }}
                    >
                      <Check aria-hidden /> Accept
                    </Button>
                    <Button size="sm" variant="outline" onClick={() => setDeclining(request)}>
                      <X aria-hidden /> Decline
                    </Button>
                    <Button
                      size="sm"
                      variant="ghost"
                      onClick={() => setMoving(request)}
                      aria-label={`Move ${request.booking_reference} to another trip`}
                    >
                      <ArrowRightLeft aria-hidden />
                    </Button>
                  </div>
                ) : null}
              </li>
            ))}
          </ul>
        )}
      </QueryState>
      <ConfirmDialog
        open={declining !== null}
        onOpenChange={(open) => !open && setDeclining(null)}
        title={`Decline ${declining?.booking_reference ?? 'this booking'}?`}
        description="For the driver. The passenger has not paid anything yet."
        confirmLabel="Decline"
        destructive
        reason={{
          label: 'Reason',
          required: true,
          placeholder: 'e.g. The minibus is already full.',
        }}
        details={
          <div className="flex items-start gap-2">
            <Checkbox
              id={moveOnId}
              checked={moveOn}
              onCheckedChange={(checked) => setMoveOn(checked === true)}
            />
            <Label htmlFor={moveOnId} className="grid gap-0.5 font-normal">
              <span>Move it to another vehicle going the same way</span>
              <span className="text-xs text-muted-foreground">Untick to end the booking here.</span>
            </Label>
          </div>
        }
        onConfirm={async (reason) => {
          await decline.mutateAsync({
            bookingId: declining!.booking_id,
            reason,
            move_to_another_trip: moveOn,
          })
          toast.success(
            moveOn ? 'Declined. It is offered to another vehicle if one has seats.' : 'Declined.',
          )
          setDeclining(null)
        }}
      />
      <MoveDialog
        request={moving}
        onClose={() => setMoving(null)}
        onMove={async (tripId) => {
          await move.mutateAsync({ bookingId: moving!.booking_id, tripId })
          toast.success('Moved. It is waiting for that driver now.')
          setMoving(null)
        }}
      />
    </>
  )
}

type Action = Schemas['DriverActionResponse']

function driverActionColumns(showTrip: boolean): ColumnDef<Action, unknown>[] {
  return [
    {
      header: 'When',
      cell: ({ row }) => (
        <span className="whitespace-nowrap">{formatDateTime(row.original.created_at)}</span>
      ),
    },
    {
      header: 'What',
      cell: ({ row }) => {
        const kind = ACTION_KINDS[row.original.kind]
        return <StatusBadge tone={kind.tone} label={kind.label} icon={kind.icon} />
      },
    },
    {
      header: 'Driver',
      cell: ({ row }) => row.original.driver_name ?? '—',
    },
    {
      header: 'Done by',
      cell: ({ row }) => (
        <span className={cn(row.original.acted_as !== 'driver' && 'font-medium')}>
          {ACTED_AS[row.original.acted_as]}
          {row.original.acted_as === 'admin' && row.original.actor_name
            ? ` (${row.original.actor_name})`
            : ''}
        </span>
      ),
    },
    {
      header: 'Reason',
      cell: ({ row }) => (
        <span className="line-clamp-2 max-w-64 text-sm text-muted-foreground">
          {row.original.reason ?? '—'}
        </span>
      ),
    },
    ...(showTrip
      ? [
          {
            id: 'trip',
            header: 'Trip',
            cell: ({ row }: { row: { original: Action } }) => (
              <Link to={`/trips/${row.original.trip_id}`} className="link-inline">
                Open
              </Link>
            ),
          } satisfies ColumnDef<Action, unknown>,
        ]
      : []),
  ]
}

export function DriverActionsTable({
  rows,
  total,
  page,
  pageSize,
  onPageChange,
  query,
  showTrip = true,
}: {
  rows: Action[] | undefined
  total?: number
  page?: number
  pageSize?: number
  onPageChange?: (page: number) => void
  query: {
    isPending: boolean
    isError: boolean
    isFetching: boolean
    error: unknown
    refetch: () => unknown
  }
  showTrip?: boolean
}) {
  return (
    <DataTable
      columns={driverActionColumns(showTrip)}
      rows={rows}
      total={total}
      getRowId={(row) => row.id}
      caption="What drivers did"
      isPending={query.isPending}
      isError={query.isError}
      error={query.error}
      onRetry={() => void query.refetch()}
      isFetching={query.isFetching && !query.isPending}
      page={page}
      pageSize={pageSize}
      onPageChange={onPageChange}
      empty={
        <EmptyState
          title="No driver actions"
          description={
            showTrip
              ? 'Nothing matches these filters.'
              : 'Answers, ticket scans and trip updates from the driver show here.'
          }
        />
      }
    />
  )
}
