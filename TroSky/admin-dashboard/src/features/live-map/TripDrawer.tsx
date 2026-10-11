import { ArrowRight, Clock, Gauge, MapPin, Navigation, Siren, TriangleAlert } from 'lucide-react'
import type { ReactNode } from 'react'
import { Link } from 'react-router'

import { useSession } from '@/app/auth/auth-context'
import { ErrorState } from '@/components/feedback/states'
import { StatusBadge } from '@/components/status/StatusBadge'
import { Button } from '@/components/ui/button'
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
} from '@/components/ui/sheet'
import { Skeleton } from '@/components/ui/skeleton'
import { tripStatusTone } from '@/features/trips/status'
import { formatMinutes, formatNumber, formatRelative, formatTime, humanize } from '@/lib/format'
import { useNow } from '@/lib/use-now'

import { useTrip, useTripEta, useTripLocation } from './api'

function Row({ icon, label, children }: { icon: ReactNode; label: string; children: ReactNode }) {
  return (
    <div className="flex gap-3 py-2">
      <span className="mt-0.5 text-muted-foreground">{icon}</span>
      <div className="min-w-0">
        <p className="text-xs text-muted-foreground">{label}</p>
        <div className="text-sm">{children}</div>
      </div>
    </div>
  )
}

/** A bus on the road: who, where, when it arrives. */
export function TripDrawer({
  tripId,
  sosAlertId,
  onClose,
}: {
  tripId: string | null
  sosAlertId?: string | null
  onClose: () => void
}) {
  const { can } = useSession()
  const trip = useTrip(tripId)
  const onTheRoad = ['in_progress', 'paused', 'boarding'].includes(trip.data?.status ?? '')
  const location = useTripLocation(onTheRoad ? tripId : null)
  const eta = useTripEta(tripId, trip.data?.status === 'in_progress')
  const now = useNow(1000)

  return (
    <Sheet open={Boolean(tripId)} onOpenChange={(open) => !open && onClose()}>
      <SheetContent className="w-full overflow-y-auto sm:max-w-md">
        <SheetHeader>
          <SheetTitle>{trip.data?.route_name ?? 'Trip'}</SheetTitle>
          <SheetDescription>
            {trip.data ? (
              <StatusBadge
                tone={tripStatusTone(trip.data.status)}
                label={humanize(trip.data.status)}
              />
            ) : (
              'Loading trip'
            )}
          </SheetDescription>
        </SheetHeader>
        <div className="space-y-1 px-4">
          {sosAlertId ? (
            <Link
              to={`/safety?status=open&alert=${sosAlertId}`}
              className="flex items-center gap-2 rounded-md bg-danger px-3 py-2 text-sm font-semibold text-danger-foreground"
            >
              <Siren className="size-4" aria-hidden /> SOS open on this bus — open it
            </Link>
          ) : null}
          {trip.isPending ? (
            <div className="space-y-3 py-2">
              <Skeleton className="h-12" />
              <Skeleton className="h-12" />
              <Skeleton className="h-12" />
            </div>
          ) : trip.isError ? (
            <ErrorState error={trip.error} onRetry={() => void trip.refetch()} />
          ) : trip.data ? (
            <div className="divide-y">
              <Row icon={<MapPin className="size-4" />} label="Route">
                {trip.data.origin_stop_name}{' '}
                <ArrowRight className="inline size-3" aria-label="to" />{' '}
                {trip.data.destination_stop_name}
                <p className="text-xs text-muted-foreground">
                  Scheduled {formatTime(trip.data.scheduled_departure_at)}
                  {trip.data.actual_departure_at
                    ? ` · left ${formatTime(trip.data.actual_departure_at)}`
                    : ''}
                </p>
              </Row>
              <Row icon={<Navigation className="size-4" />} label="Driver and vehicle">
                {trip.data.driver?.full_name ?? 'No driver assigned'}
                {trip.data.driver?.average_rating ? (
                  <span className="text-muted-foreground">
                    {' '}
                    · ★ {trip.data.driver.average_rating} ({trip.data.driver.rating_count})
                  </span>
                ) : null}
                <p className="text-xs text-muted-foreground">
                  {trip.data.vehicle
                    ? `${trip.data.vehicle.registration_number} · ${trip.data.vehicle.make_model ?? humanize(trip.data.vehicle.type)}`
                    : 'No vehicle assigned'}
                </p>
              </Row>
              <Row icon={<Gauge className="size-4" />} label="Live position">
                {!onTheRoad ? (
                  'Not on the road'
                ) : location.isPending ? (
                  <Skeleton className="h-5 w-40" />
                ) : location.data ? (
                  <>
                    <span className="figure">
                      {location.data.latitude.toFixed(5)}, {location.data.longitude.toFixed(5)}
                    </span>
                    <p className="text-xs text-muted-foreground">
                      {location.data.speed_kmh
                        ? `${formatNumber(location.data.speed_kmh)} km/h · `
                        : ''}
                      updated {formatRelative(location.data.recorded_at, now)}
                    </p>
                    {location.data.is_stale ? (
                      <p className="mt-1 flex items-center gap-1 text-xs text-warning-text">
                        <TriangleAlert className="size-3.5" aria-hidden /> The driver’s phone has
                        stopped reporting.
                      </p>
                    ) : null}
                  </>
                ) : (
                  'The driver’s phone hasn’t reported a position yet.'
                )}
              </Row>
              <Row icon={<Clock className="size-4" />} label="Arrival estimate">
                {trip.data.status !== 'in_progress' ? (
                  'Only while the trip is moving'
                ) : eta.isPending ? (
                  <Skeleton className="h-5 w-40" />
                ) : eta.data ? (
                  <>
                    {trip.data.destination_stop_name} at{' '}
                    <span className="figure">{formatTime(eta.data.eta_at)}</span>
                    <p className="text-xs text-muted-foreground">
                      in {formatMinutes(eta.data.duration_minutes)} ·{' '}
                      {formatNumber(eta.data.distance_km, { decimals: true })} km to go
                    </p>
                  </>
                ) : (
                  'Not available right now'
                )}
              </Row>
              <Row icon={<Navigation className="size-4 rotate-90" />} label="Seats">
                <span className="figure">
                  {formatNumber(trip.data.riders_count)} of {formatNumber(trip.data.seats_total)}
                </span>{' '}
                booked · {formatNumber(trip.data.available_seats)} free
              </Row>
            </div>
          ) : null}
        </div>
        {tripId && can('trips:manage', 'trips:monitor_live') ? (
          <SheetFooter>
            <Button asChild>
              <Link to={`/trips/${tripId}`}>Open trip</Link>
            </Button>
          </SheetFooter>
        ) : null}
      </SheetContent>
    </Sheet>
  )
}
