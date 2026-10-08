import { Bus, Expand, List, Map as MapIcon } from 'lucide-react'
import { useMemo, useRef, useState } from 'react'
import { type MapRef } from 'react-map-gl/maplibre'

import { useSession } from '@/app/auth/auth-context'
import { useLive } from '@/app/live/live-context'
import { EmptyState, ErrorState, TableSkeleton } from '@/components/feedback/states'
import { WidgetBoundary } from '@/components/feedback/WidgetBoundary'
import { PageHeader } from '@/components/layout/PageHeader'
import { ACCRA, mapSupported } from '@/components/map/map-support'
import { MapView } from '@/components/map/MapView'
import { PlainMarker } from '@/components/map/PlainMarker'
import { StatusBadge } from '@/components/status/StatusBadge'
import { Button } from '@/components/ui/button'
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table'
import { ToggleGroup, ToggleGroupItem } from '@/components/ui/toggle-group'
import { useActiveSos } from '@/features/safety/api'
import { formatRelative } from '@/lib/format'
import { useUrlState } from '@/lib/url-state'
import { useNow } from '@/lib/use-now'
import { cn } from '@/lib/utils'

import { useLiveTrips } from './api'
import { BUS_STATES, busState, type BusState, type LiveTrip } from './status'
import { TripDrawer } from './TripDrawer'

type Placed = LiveTrip & { latitude: number; longitude: number; state: BusState }

interface Cluster {
  key: string
  latitude: number
  longitude: number
  buses: Placed[]
}

/** Buses near each other at this zoom share one counted marker. */
function cluster(buses: Placed[], zoom: number): Cluster[] {
  if (zoom >= 12.5) {
    return buses.map((bus) => ({
      key: bus.trip_id,
      latitude: bus.latitude,
      longitude: bus.longitude,
      buses: [bus],
    }))
  }
  // About 56 px cells: 360° spans 512 · 2^zoom px at this zoom.
  const cell = (56 * 360) / (512 * 2 ** zoom)
  const groups = new Map<string, Placed[]>()
  for (const bus of buses) {
    const key = `${Math.floor(bus.latitude / cell)}:${Math.floor(bus.longitude / cell)}`
    groups.set(key, [...(groups.get(key) ?? []), bus])
  }
  return [...groups.entries()].map(([key, members]) => ({
    key,
    latitude: members.reduce((sum, bus) => sum + bus.latitude, 0) / members.length,
    longitude: members.reduce((sum, bus) => sum + bus.longitude, 0) / members.length,
    buses: members,
  }))
}

const FILTERS: { value: string; label: string; states: BusState[] }[] = [
  {
    value: 'all',
    label: 'All',
    states: ['sos', 'moving', 'boarding', 'paused', 'stale', 'no-gps'],
  },
  { value: 'moving', label: 'On the road', states: ['moving', 'sos'] },
  { value: 'boarding', label: 'Boarding', states: ['boarding'] },
  { value: 'paused', label: 'Paused', states: ['paused'] },
  { value: 'gps', label: 'GPS problems', states: ['stale', 'no-gps'] },
]

function Legend() {
  return (
    <ul className="flex flex-wrap gap-2" aria-label="Map legend">
      {(Object.keys(BUS_STATES) as BusState[]).map((state) => {
        const { label, tone, icon } = BUS_STATES[state]
        return (
          <li key={state}>
            <StatusBadge tone={tone} label={label} icon={icon} />
          </li>
        )
      })}
    </ul>
  )
}

export default function LiveMapPage() {
  const { can } = useSession()
  const { dataSaver } = useLive()
  const [{ trip: selected, show, view }, update] = useUrlState({
    trip: '',
    show: 'all',
    view: 'map',
  })
  const trips = useLiveTrips()
  const sos = useActiveSos(can('sos:review'))
  const now = useNow(1000)
  const mapRef = useRef<MapRef>(null)
  const [zoom, setZoom] = useState(ACCRA.zoom)

  const sosByTrip = useMemo(
    () =>
      new Map(
        (sos.data?.items ?? [])
          .filter((alert) => alert.trip_id)
          .map((alert) => [alert.trip_id!, alert.id]),
      ),
    [sos.data],
  )
  const sosTrips = useMemo(() => new Set(sosByTrip.keys()), [sosByTrip])
  const filter = FILTERS.find((candidate) => candidate.value === show) ?? FILTERS[0]!
  const rows = useMemo(
    () =>
      (trips.data ?? [])
        .map((trip) => ({ ...trip, state: busState(trip, sosTrips) }))
        .filter((trip) => filter.states.includes(trip.state))
        .sort(
          (a, b) =>
            Number(b.state === 'sos') - Number(a.state === 'sos') ||
            a.route_name.localeCompare(b.route_name),
        ),
    [trips.data, sosTrips, filter],
  )
  const placed = rows.filter(
    (trip): trip is Placed => trip.latitude !== null && trip.longitude !== null,
  )
  const clusters = cluster(placed, zoom)
  const mapAvailable = mapSupported()

  function focus(trip: Placed | (typeof rows)[number]) {
    update({ trip: trip.trip_id }, { keepPage: true })
    if (trip.latitude !== null && trip.longitude !== null) {
      mapRef.current?.[dataSaver ? 'jumpTo' : 'flyTo']({
        center: [trip.longitude, trip.latitude],
        zoom: Math.max(zoom, 13),
      })
    }
  }

  function fitAll() {
    if (placed.length === 0) return
    const lats = placed.map((bus) => bus.latitude)
    const lngs = placed.map((bus) => bus.longitude)
    mapRef.current?.fitBounds(
      [
        [Math.min(...lngs), Math.min(...lats)],
        [Math.max(...lngs), Math.max(...lats)],
      ],
      { padding: 60, duration: dataSaver ? 0 : 800, maxZoom: 14 },
    )
  }

  const updated = trips.dataUpdatedAt ? formatRelative(trips.dataUpdatedAt, now) : null

  return (
    <div className="space-y-4">
      <PageHeader
        title="Live map"
        description={
          trips.data
            ? `${trips.data.length} trips out now${updated ? ` · updated ${updated}` : ''}`
            : 'Every bus out on the road now.'
        }
        actions={
          <>
            <ToggleGroup
              type="single"
              variant="outline"
              value={view}
              onValueChange={(value) => value && update({ view: value }, { keepPage: true })}
              aria-label="Show"
              className="lg:hidden"
            >
              <ToggleGroupItem value="map" aria-label="Map">
                <MapIcon aria-hidden />
              </ToggleGroupItem>
              <ToggleGroupItem value="list" aria-label="List">
                <List aria-hidden />
              </ToggleGroupItem>
            </ToggleGroup>
            <Button
              variant="outline"
              onClick={fitAll}
              disabled={!mapAvailable || placed.length === 0}
            >
              <Expand aria-hidden /> Show all buses
            </Button>
          </>
        }
      />
      <div className="flex flex-wrap items-center justify-between gap-3">
        <ToggleGroup
          type="single"
          variant="outline"
          value={filter.value}
          onValueChange={(value) => value && update({ show: value }, { keepPage: true })}
          aria-label="Which buses"
        >
          {FILTERS.map((option) => (
            <ToggleGroupItem key={option.value} value={option.value}>
              {option.label}
            </ToggleGroupItem>
          ))}
        </ToggleGroup>
        <Legend />
      </div>

      {trips.isError && !trips.data ? (
        <ErrorState error={trips.error} onRetry={() => void trips.refetch()} />
      ) : (
        <div className="grid gap-4 lg:grid-cols-[minmax(0,1fr)_24rem]">
          <WidgetBoundary title="The map failed">
            <MapView
              ref={mapRef}
              label="Map of buses on the road"
              className={cn(
                'h-[60vh] min-h-80 lg:h-[calc(100svh-15rem)]',
                view === 'list' && 'max-lg:hidden',
              )}
              onZoomEnd={(zoomLevel) => setZoom(zoomLevel)}
            >
              {clusters.map((group) =>
                group.buses.length > 1 ? (
                  <PlainMarker
                    key={group.key}
                    latitude={group.latitude}
                    longitude={group.longitude}
                    anchor="center"
                  >
                    <button
                      type="button"
                      className="flex size-10 items-center justify-center rounded-full border-2 border-white bg-navy text-sm font-bold text-white shadow-md focus-visible:ring-2 focus-visible:ring-ring focus-visible:outline-none"
                      aria-label={`${group.buses.length} buses here. Zoom in.`}
                      onClick={() =>
                        mapRef.current?.[dataSaver ? 'jumpTo' : 'flyTo']({
                          center: [group.longitude, group.latitude],
                          zoom: Math.min(zoom + 2, 14),
                        })
                      }
                    >
                      {group.buses.some((bus) => bus.state === 'sos') ? (
                        <span
                          className="absolute -top-1 -right-1 size-3 rounded-full bg-danger"
                          aria-hidden
                        />
                      ) : null}
                      {group.buses.length}
                    </button>
                  </PlainMarker>
                ) : (
                  <BusMarker
                    key={group.key}
                    bus={group.buses[0]!}
                    selected={group.buses[0]!.trip_id === selected}
                    animate={!dataSaver}
                    onSelect={() => focus(group.buses[0]!)}
                  />
                ),
              )}
            </MapView>
          </WidgetBoundary>
          <section
            aria-label="Buses on the road"
            className={cn(
              'max-h-[calc(100svh-15rem)] overflow-auto rounded-lg border bg-card',
              view === 'map' && mapAvailable && 'max-lg:hidden',
            )}
          >
            {trips.isPending ? (
              <div className="p-3">
                <TableSkeleton rows={8} columns={3} />
              </div>
            ) : rows.length === 0 ? (
              <EmptyState
                icon={Bus}
                title="No buses here"
                description="None match this filter right now."
                className="m-3"
              />
            ) : (
              <Table>
                <caption className="sr-only">Buses on the road, SOS first</caption>
                <TableHeader className="sticky top-0 bg-card">
                  <TableRow>
                    <TableHead>Bus</TableHead>
                    <TableHead>Status</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {rows.map((trip) => (
                    <TableRow
                      key={trip.trip_id}
                      data-state={trip.trip_id === selected ? 'selected' : undefined}
                    >
                      <TableCell className="max-w-48">
                        <button
                          type="button"
                          className="text-left hover:underline focus-visible:underline focus-visible:outline-none"
                          onClick={() => focus(trip)}
                        >
                          <span className="block truncate font-medium">{trip.route_name}</span>
                          <span className="block truncate text-xs text-muted-foreground">
                            {trip.vehicle_registration_number ?? 'No vehicle'} ·{' '}
                            {trip.driver_name ?? 'No driver'}
                          </span>
                        </button>
                      </TableCell>
                      <TableCell>
                        <StatusBadge
                          tone={BUS_STATES[trip.state].tone}
                          label={BUS_STATES[trip.state].label}
                          icon={BUS_STATES[trip.state].icon}
                        />
                        <span className="mt-1 block text-xs text-muted-foreground">
                          {trip.updated_at
                            ? formatRelative(trip.updated_at, now)
                            : 'No position yet'}
                        </span>
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            )}
          </section>
        </div>
      )}
      <TripDrawer
        tripId={selected || null}
        sosAlertId={selected ? (sosByTrip.get(selected) ?? null) : null}
        onClose={() => update({ trip: null }, { keepPage: true })}
      />
    </div>
  )
}

function BusMarker({
  bus,
  selected,
  animate,
  onSelect,
}: {
  bus: Placed
  selected: boolean
  animate: boolean
  onSelect: () => void
}) {
  const style = BUS_STATES[bus.state]
  const Icon = style.icon
  return (
    <PlainMarker latitude={bus.latitude} longitude={bus.longitude} anchor="center">
      <button
        type="button"
        onClick={onSelect}
        aria-label={`${bus.route_name}, ${bus.vehicle_registration_number ?? 'no vehicle'}: ${style.label}`}
        aria-pressed={selected}
        className={cn(
          'relative flex size-8 items-center justify-center rounded-full border-2 border-white shadow-md focus-visible:ring-2 focus-visible:ring-ring focus-visible:outline-none',
          style.marker,
          selected && 'ring-2 ring-navy ring-offset-2',
        )}
      >
        {bus.state === 'sos' && animate ? (
          <span
            className="absolute inset-0 rounded-full bg-danger motion-safe:animate-ping"
            aria-hidden
          />
        ) : null}
        <Icon className="relative size-4" aria-hidden />
      </button>
    </PlainMarker>
  )
}
