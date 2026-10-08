import {
  ArrowLeft,
  ArrowRight,
  Ban,
  CircleCheck,
  Download,
  MapPinned,
  ThumbsDown,
  ThumbsUp,
  TriangleAlert,
} from 'lucide-react'
import { lazy, Suspense, useId, useMemo, useState, type ReactNode } from 'react'
import { Link, useParams } from 'react-router'
import { toast } from 'sonner'

import { downloadFile } from '@/api/client'
import { errorMessage, isApiError } from '@/api/errors'
import type { Schemas } from '@/api/types'
import { useSession } from '@/app/auth/auth-context'
import { ConfirmButton } from '@/components/confirm/ConfirmButton'
import { ConfirmDialog, ConfirmFacts } from '@/components/confirm/ConfirmDialog'
import { EmptyState, ErrorState, PageSkeleton } from '@/components/feedback/states'
import { PageHeader, Section } from '@/components/layout/PageHeader'
import { DriverPicker, VehiclePicker } from '@/components/pickers/pickers'
import type { PickerOption } from '@/components/pickers/SearchPicker'
import { StatusBadge } from '@/components/status/StatusBadge'
import { Button } from '@/components/ui/button'
import { Card, CardAction, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Label } from '@/components/ui/label'
import { Skeleton } from '@/components/ui/skeleton'
import { useDriverActions } from '@/features/dispatch/api'
import { BookingRequests, DriverActionsTable } from '@/features/dispatch/components'
import { useTrip, useTripEta, useTripLocation } from '@/features/live-map/api'
import { useRoute } from '@/features/shared/reference'
import {
  formatClock,
  formatDateTime,
  formatMinutes,
  formatMoney,
  formatNumber,
  formatRelative,
  formatTime,
  humanize,
} from '@/lib/format'
import { useNow } from '@/lib/use-now'

import {
  useAnswerForDriver,
  useAssignDriver,
  useAssignVehicle,
  useCancelTrip,
  useTripSummary,
  useTripTrack,
} from './api'
import { DriverAnswer } from './DriverAnswer'
import { positionAt, timeline, useReplay } from './replay'
import { ReplayControls } from './ReplayControls'
import { tripStatusTone } from './status'

const RouteMap = lazy(() => import('@/components/map/RouteMap'))

type Trip = Schemas['TripDetailResponse']
type Summary = Schemas['AdminTripSummaryResponse']
type Cancellation = Schemas['TripCancellationResponse']
type Action = Schemas['DriverActionResponse']

const BEFORE_DEPARTURE = new Set(['scheduled', 'boarding'])
const ON_THE_ROAD = new Set(['boarding', 'in_progress', 'paused'])
const FINISHED = new Set(['completed', 'cancelled'])

function Fact({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div className="space-y-0.5">
      <dt className="text-xs text-muted-foreground">{label}</dt>
      <dd className="text-sm">{children}</dd>
    </div>
  )
}

function TripFacts({ trip, summary }: { trip: Trip; summary: Summary | null | undefined }) {
  return (
    <dl className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
      <Fact label="Route">
        {trip.origin_stop_name} <ArrowRight className="inline size-3" aria-label="to" />{' '}
        {trip.destination_stop_name}
      </Fact>
      <Fact label="Departs">
        <span className="figure">{formatDateTime(trip.scheduled_departure_at)}</span>
        {trip.actual_departure_at ? (
          <span className="block text-xs text-muted-foreground">
            Left at {formatTime(trip.actual_departure_at)}
          </span>
        ) : null}
      </Fact>
      <Fact label="Arrives">
        {trip.scheduled_arrival_at ? (
          <span className="figure">{formatTime(trip.scheduled_arrival_at)}</span>
        ) : (
          'Not set'
        )}
        {trip.actual_arrival_at ? (
          <span className="block text-xs text-muted-foreground">
            Arrived at {formatTime(trip.actual_arrival_at)}
          </span>
        ) : null}
      </Fact>
      <Fact label="Fare, whole route">{formatMoney(trip.fare_amount)}</Fact>
      <Fact label="Seats">
        {summary ? (
          <>
            <span className="figure">
              {formatNumber(summary.seats_booked)} paid of {formatNumber(trip.seats_total)}
            </span>
            <span className="block text-xs text-muted-foreground">
              {formatNumber(trip.available_seats)} free · {formatNumber(summary.boarded_count)}{' '}
              boarded
            </span>
          </>
        ) : (
          <span className="figure">
            {formatNumber(trip.available_seats)} free of {formatNumber(trip.seats_total)}
          </span>
        )}
      </Fact>
      <Fact label="Made from">{trip.route_schedule_id ? 'The timetable' : 'A one-off trip'}</Fact>
    </dl>
  )
}

/** Put a driver or a vehicle on the trip, asking first. */
function Assign({
  kind,
  trip,
  currentId,
  currentLabel,
}: {
  kind: 'driver' | 'vehicle'
  trip: Trip
  currentId: string | null
  currentLabel: string | null
}) {
  const [chosen, setChosen] = useState<PickerOption | null>(null)
  const assignDriver = useAssignDriver(trip.id)
  const assignVehicle = useAssignVehicle(trip.id)
  const pickerId = useId()
  const Picker = kind === 'driver' ? DriverPicker : VehiclePicker
  return (
    <>
      <Label htmlFor={pickerId} className="sr-only">
        {currentId ? `Change the ${kind}` : `Choose the ${kind}`}
      </Label>
      <Picker
        id={pickerId}
        value={currentId}
        selectedLabel={currentLabel ?? undefined}
        onChange={(option) => option && option.value !== currentId && setChosen(option)}
        placeholder={currentId ? `Change the ${kind}` : `Choose a ${kind}`}
      />
      <ConfirmDialog
        open={chosen !== null}
        onOpenChange={(open) => !open && setChosen(null)}
        title={`Put ${chosen?.label ?? ''} on this trip?`}
        description={
          kind === 'driver'
            ? currentId
              ? `${currentLabel ?? 'The current driver'} comes off it. ${chosen?.label ?? 'The new driver'} is asked to accept the trip.`
              : `${chosen?.label ?? 'The driver'} is asked to accept the trip.`
            : currentId
              ? `${currentLabel ?? 'The current vehicle'} comes off it.`
              : undefined
        }
        confirmLabel={`Assign ${kind}`}
        onConfirm={async () => {
          if (!chosen) return
          if (kind === 'driver') await assignDriver.mutateAsync(chosen.value)
          else await assignVehicle.mutateAsync(chosen.value)
          toast.success(
            kind === 'driver'
              ? `${chosen.label} is on the trip and has been asked to accept it.`
              : `${chosen.label} is on the trip.`,
          )
          setChosen(null)
        }}
      />
    </>
  )
}

function DriverCard({
  trip,
  summary,
  manages,
  lastDecline,
}: {
  trip: Trip
  summary: Summary | null | undefined
  manages: boolean
  /** The latest answer to this trip, when it was a no (the driver then comes off it). */
  lastDecline: Action | null
}) {
  const { can } = useSession()
  const answer = useAnswerForDriver(trip.id)
  const name = trip.driver?.full_name ?? summary?.driver_name ?? null
  const response = summary?.driver_response ?? null
  const open = BEFORE_DEPARTURE.has(trip.status)
  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-base">Driver</CardTitle>
      </CardHeader>
      <CardContent className="space-y-3">
        {trip.driver ? (
          <div className="space-y-1">
            <p className="font-medium">{name ?? 'Unnamed driver'}</p>
            <p className="text-sm text-muted-foreground">
              {trip.driver.average_rating
                ? `★ ${trip.driver.average_rating} from ${formatNumber(trip.driver.rating_count)} ratings`
                : 'No ratings yet'}
              {can('drivers:approve') && trip.driver.rating_count ? (
                <>
                  {' · '}
                  <Link to={`/driver-ratings?driver=${trip.driver.id}`} className="link-inline">
                    See ratings
                  </Link>
                </>
              ) : null}
            </p>
            <DriverAnswer response={response} />
          </div>
        ) : (
          <p className="text-sm text-muted-foreground">No driver on this trip yet.</p>
        )}
        {!trip.driver && lastDecline && open ? (
          <p className="flex items-start gap-1.5 text-sm text-warning-text">
            <TriangleAlert className="mt-0.5 size-4 shrink-0" aria-hidden />
            <span>
              {lastDecline.driver_name ?? 'The driver'} declined
              {lastDecline.acted_as === 'admin' ? ' (answered by an admin)' : ''}
              {lastDecline.reason ? `: “${lastDecline.reason}”` : '.'} Put another driver on the
              trip.
            </span>
          </p>
        ) : null}
        {manages && response === 'pending' && !FINISHED.has(trip.status) ? (
          <div className="flex flex-wrap gap-2">
            <ConfirmButton
              label="Accept for the driver"
              icon={ThumbsUp}
              size="sm"
              title={`Accept the trip for ${name ?? 'the driver'}?`}
              description="When they have agreed another way, such as by phone. It is logged as done by you for them."
              confirmLabel="Accept"
              onConfirm={async () => {
                await answer.mutateAsync({ accept: true })
                toast.success('Accepted for the driver.')
              }}
            />
            <ConfirmButton
              label="Decline for the driver"
              icon={ThumbsDown}
              size="sm"
              variant="outline"
              title={`Decline the trip for ${name ?? 'the driver'}?`}
              description="The trip then needs another driver."
              confirmLabel="Decline"
              destructive
              reason={{ label: 'Reason', required: true, placeholder: 'e.g. Called in sick.' }}
              onConfirm={async (reason) => {
                await answer.mutateAsync({ accept: false, reason })
                toast.success('Declined for the driver. Put another driver on the trip.')
              }}
            />
          </div>
        ) : null}
        {manages && open ? (
          can('drivers:approve', 'trips:monitor_live') ? (
            <Assign
              kind="driver"
              trip={trip}
              currentId={trip.driver?.id ?? null}
              currentLabel={name}
            />
          ) : (
            <p className="text-xs text-muted-foreground">
              Choosing a driver needs permission to see drivers.
            </p>
          )
        ) : null}
      </CardContent>
    </Card>
  )
}

function VehicleCard({
  trip,
  summary,
  manages,
}: {
  trip: Trip
  summary: Summary | null | undefined
  manages: boolean
}) {
  const { can } = useSession()
  const registration =
    trip.vehicle?.registration_number ?? summary?.vehicle_registration_number ?? null
  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-base">Vehicle</CardTitle>
      </CardHeader>
      <CardContent className="space-y-3">
        {trip.vehicle ? (
          <div className="space-y-0.5">
            <p className="font-medium">{trip.vehicle.registration_number}</p>
            <p className="text-sm text-muted-foreground">
              {trip.vehicle.make_model ?? humanize(trip.vehicle.type)}
              {trip.vehicle.capacity ? ` · ${trip.vehicle.capacity} seats` : ''}
            </p>
          </div>
        ) : (
          <p className="text-sm text-muted-foreground">No vehicle on this trip yet.</p>
        )}
        {manages && BEFORE_DEPARTURE.has(trip.status) ? (
          can('vehicles:approve', 'trips:monitor_live') ? (
            <Assign
              kind="vehicle"
              trip={trip}
              currentId={summary?.vehicle_id ?? null}
              currentLabel={registration}
            />
          ) : (
            <p className="text-xs text-muted-foreground">
              Choosing a vehicle needs permission to see vehicles.
            </p>
          )
        ) : null}
      </CardContent>
    </Card>
  )
}

function LiveCard({ trip }: { trip: Trip }) {
  const location = useTripLocation(trip.id)
  const eta = useTripEta(trip.id, trip.status === 'in_progress')
  const now = useNow(5000)
  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-base">On the road</CardTitle>
        <CardAction>
          <Button asChild variant="ghost" size="sm" className="-my-1.5">
            <Link to={`/live?trip=${trip.id}`}>
              <MapPinned aria-hidden /> Live map
            </Link>
          </Button>
        </CardAction>
      </CardHeader>
      <CardContent className="space-y-3 text-sm">
        {location.isPending ? (
          <Skeleton className="h-10" />
        ) : location.data ? (
          <div>
            <p>
              Last reported {formatRelative(location.data.recorded_at, now)}
              {location.data.speed_kmh ? ` · ${formatNumber(location.data.speed_kmh)} km/h` : ''}
            </p>
            {location.data.is_stale ? (
              <p className="mt-1 flex items-center gap-1 text-warning-text">
                <TriangleAlert className="size-4" aria-hidden /> The driver’s phone has stopped
                reporting.
              </p>
            ) : null}
          </div>
        ) : (
          <p className="text-muted-foreground">
            The driver’s phone hasn’t reported a position yet.
          </p>
        )}
        {trip.status === 'in_progress' ? (
          eta.data ? (
            <p>
              Reaches {trip.destination_stop_name} at{' '}
              <span className="figure font-medium">{formatTime(eta.data.eta_at)}</span> (in{' '}
              {formatMinutes(eta.data.duration_minutes)})
            </p>
          ) : eta.isPending ? (
            <Skeleton className="h-5 w-48" />
          ) : null
        ) : null}
      </CardContent>
    </Card>
  )
}

const NO_POINTS: Schemas['TrackPoint'][] = []

function TripMapSection({ trip }: { trip: Trip }) {
  const route = useRoute(trip.route_id)
  const onTheRoad = ON_THE_ROAD.has(trip.status)
  const departed = Boolean(trip.actual_departure_at)
  const track = useTripTrack(departed ? trip.id : null, onTheRoad)
  const location = useTripLocation(onTheRoad ? trip.id : null)
  const stops = route.data?.stops ?? []
  const points = track.data?.points ?? NO_POINTS
  const line = useMemo(() => timeline(points), [points])
  const replay = useReplay(line)
  const position = replay.at === null ? null : positionAt(points, line, replay.at)
  // The bold "so far" line changes only when the bus passes a point.
  const reached = position?.index
  const travelled = useMemo(
    () => (reached === undefined ? undefined : points.slice(0, reached + 1)),
    [points, reached],
  )
  const [downloading, setDownloading] = useState(false)

  async function download() {
    setDownloading(true)
    try {
      await downloadFile(
        `/api/v1/admin/trips/${trip.id}/track`,
        { format: 'csv' },
        `trip-${trip.id}-track.csv`,
      )
    } catch (error) {
      toast.error(errorMessage(error))
    } finally {
      setDownloading(false)
    }
  }

  return (
    <Section
      title="Map"
      description={
        track.data && track.data.point_count
          ? `Driven ${formatNumber(track.data.distance_km, { decimals: true })} km${
              track.data.max_speed_kmh
                ? ` · top speed ${formatNumber(track.data.max_speed_kmh)} km/h`
                : ''
            }${track.data.truncated ? ' · showing the latest points' : ''}`
          : 'The route’s stops. The bus’s path appears once it sets off.'
      }
      actions={
        points.length ? (
          <Button
            variant="outline"
            size="sm"
            onClick={() => void download()}
            disabled={downloading}
          >
            <Download aria-hidden /> Positions (CSV)
          </Button>
        ) : null
      }
    >
      {route.isPending ? (
        <Skeleton className="h-72" />
      ) : route.isError ? (
        <ErrorState error={route.error} onRetry={() => void route.refetch()} />
      ) : (
        <div className="space-y-3">
          <Suspense fallback={<Skeleton className="h-72" />}>
            <RouteMap
              label={`Map of ${trip.route_name}`}
              stops={stops}
              track={points}
              travelled={travelled}
              bus={position ?? (onTheRoad ? (location.data ?? null) : null)}
              busLabel={replay.at === null ? 'The bus now' : `The bus at ${formatClock(replay.at)}`}
            />
          </Suspense>
          {points.length > 1 ? (
            <ReplayControls line={line} replay={replay} position={position} live={onTheRoad} />
          ) : null}
        </div>
      )}
    </Section>
  )
}

function CancelledPanel({ result }: { result: Cancellation }) {
  const { can } = useSession()
  return (
    <div
      role="status"
      className="mb-4 flex flex-wrap items-start gap-3 rounded-lg border border-success/30 bg-success-soft p-4 text-success-text"
    >
      <CircleCheck className="mt-0.5 size-5 shrink-0" aria-hidden />
      <div className="min-w-0 flex-1 space-y-1">
        <p className="font-semibold">The trip is cancelled.</p>
        <p className="text-sm">
          {result.bookings_cancelled
            ? `${formatNumber(result.bookings_cancelled)} booking${result.bookings_cancelled === 1 ? '' : 's'} cancelled and the passengers told. `
            : 'No bookings were on it. '}
          {result.refunds_queued
            ? `${formatNumber(result.refunds_queued)} refund${result.refunds_queued === 1 ? '' : 's'} (${formatMoney(result.refund_amount)}) waiting for approval.`
            : 'No refunds were needed.'}
        </p>
      </div>
      {result.refunds_queued && can('refunds:approve') ? (
        <Button asChild size="sm" variant="outline">
          <Link to="/bookings/refunds">Review refunds</Link>
        </Button>
      ) : null}
    </div>
  )
}

/** One trip: who drives it, in what, where it is, and what drivers did on it. */
export function TripPage() {
  const { tripId = '' } = useParams()
  const { can } = useSession()
  const trip = useTrip(tripId)
  const summary = useTripSummary(trip.data)
  const [actionsPage, setActionsPage] = useState(1)
  const actions = useDriverActions({ trip: tripId }, actionsPage, 20)
  const cancel = useCancelTrip(tripId)
  const [cancelled, setCancelled] = useState<Cancellation | null>(null)
  const manages = can('trips:manage')

  if (trip.isPending) return <PageSkeleton />
  if (trip.isError || !trip.data) {
    return (
      <>
        <BackLink />
        {isApiError(trip.error, 404) ? (
          <EmptyState title="Trip not found" description="The link may be wrong or old." />
        ) : (
          <ErrorState error={trip.error} onRetry={() => void trip.refetch()} />
        )}
      </>
    )
  }

  const data = trip.data
  const finished = FINISHED.has(data.status)
  // Newest first: the latest yes or no a driver gave to this trip.
  const lastAnswer = actions.data?.items.find(
    (action) => action.kind === 'trip_accepted' || action.kind === 'trip_declined',
  )
  const paidSeats = summary.data?.seats_booked ?? 0

  return (
    <>
      <BackLink />
      <PageHeader
        title={data.route_name}
        description={
          <span className="inline-flex flex-wrap items-center gap-2">
            <span className="figure">{formatDateTime(data.scheduled_departure_at)}</span>
            <StatusBadge tone={tripStatusTone(data.status)} label={humanize(data.status)} />
          </span>
        }
        actions={
          manages && !finished ? (
            <ConfirmButton
              label="Cancel trip"
              icon={Ban}
              variant="outline"
              title="Cancel this trip?"
              description="Every booking on it is cancelled and the passengers are told. Paid fares go to the refunds queue for approval."
              details={
                <ConfirmFacts
                  rows={[
                    ['Departs', formatDateTime(data.scheduled_departure_at)],
                    ['Paid seats', formatNumber(paidSeats)],
                    ['Driver', data.driver?.full_name ?? 'None'],
                  ]}
                />
              }
              confirmLabel="Cancel trip"
              destructive
              reason={{
                label: 'Reason (passengers see it)',
                required: true,
                minLength: 5,
                placeholder: 'e.g. The vehicle broke down.',
              }}
              onConfirm={async (reason) => {
                const result = await cancel.mutateAsync(reason)
                setCancelled(result)
                toast.success('Trip cancelled.')
              }}
            />
          ) : null
        }
      />
      {cancelled ? <CancelledPanel result={cancelled} /> : null}
      <div className="grid gap-6 lg:grid-cols-3">
        <div className="space-y-6 lg:col-span-2">
          <Card>
            <CardContent>
              <TripFacts trip={data} summary={summary.data} />
            </CardContent>
          </Card>
          <TripMapSection trip={data} />
          {!finished ? (
            <Section
              title="Bookings waiting for the driver"
              description="Each booking needs the driver’s yes before the passenger pays."
            >
              <BookingRequests tripId={data.id} />
            </Section>
          ) : null}
          <Section title="What drivers did on this trip">
            <DriverActionsTable
              rows={actions.data?.items}
              total={actions.data?.total}
              page={actionsPage}
              pageSize={20}
              onPageChange={setActionsPage}
              query={actions}
              showTrip={false}
            />
          </Section>
        </div>
        <div className="space-y-6">
          <DriverCard
            trip={data}
            summary={summary.data}
            manages={manages}
            lastDecline={lastAnswer?.kind === 'trip_declined' ? lastAnswer : null}
          />
          <VehicleCard trip={data} summary={summary.data} manages={manages} />
          {ON_THE_ROAD.has(data.status) ? <LiveCard trip={data} /> : null}
        </div>
      </div>
    </>
  )
}

function BackLink() {
  return (
    <Button asChild variant="ghost" size="sm" className="mb-2 -ml-2">
      <Link to="/trips">
        <ArrowLeft aria-hidden /> Trips
      </Link>
    </Button>
  )
}
