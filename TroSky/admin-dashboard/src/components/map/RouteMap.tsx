import type { Feature, LineString } from 'geojson'
import { Bus } from 'lucide-react'
import { useMemo } from 'react'
import { Layer, Source } from 'react-map-gl/maplibre'

import { useTheme } from '@/app/theme-context'

import { MapView } from './MapView'
import { PlainMarker } from './PlainMarker'

export interface MapPoint {
  latitude: number
  longitude: number
}

function line(points: MapPoint[]): Feature<LineString> {
  return {
    type: 'Feature',
    properties: {},
    geometry: {
      type: 'LineString',
      coordinates: points.map((point) => [point.longitude, point.latitude]),
    },
  }
}

const NONE: MapPoint[] = []

/**
 * A route's stops in order (numbered, joined by a dashed line) and,
 * when given, where a bus has driven and where it is now. In a replay,
 * ``travelled`` is the part driven so far: the rest of the track fades.
 * Loaded on demand: it pulls in the map library.
 */
export default function RouteMap({
  stops,
  track = NONE,
  travelled,
  bus = null,
  busLabel = 'The bus now',
  label,
  className = 'h-72',
}: {
  stops: (MapPoint & { id: string; name: string })[]
  track?: MapPoint[]
  travelled?: MapPoint[]
  bus?: MapPoint | null
  busLabel?: string
  label: string
  className?: string
}) {
  const { resolvedTheme } = useTheme()
  // New data makes the map re-draw a line: only when the points change.
  const planned = useMemo(() => line(stops), [stops])
  const driven = useMemo(() => line(track), [track])
  const replayed = useMemo(() => (travelled ? line(travelled) : null), [travelled])
  const points = [...stops, ...track, ...(bus ? [bus] : [])]
  const first = points[0]
  if (!first) return null
  const latitudes = points.map((point) => point.latitude)
  const longitudes = points.map((point) => point.longitude)
  const view =
    points.length === 1
      ? { latitude: first.latitude, longitude: first.longitude, zoom: 14 }
      : {
          bounds: [
            [Math.min(...longitudes), Math.min(...latitudes)],
            [Math.max(...longitudes), Math.max(...latitudes)],
          ] as [[number, number], [number, number]],
          fitBoundsOptions: { padding: 48, maxZoom: 15 },
        }

  return (
    <MapView label={label} className={className} initialViewState={view}>
      {stops.length > 1 ? (
        <Source id="planned" type="geojson" data={planned}>
          <Layer
            id="planned-line"
            type="line"
            paint={{
              'line-color': resolvedTheme === 'dark' ? '#9db4d0' : '#12355b',
              'line-width': 2,
              'line-dasharray': [2, 2],
              'line-opacity': 0.7,
            }}
          />
        </Source>
      ) : null}
      {track.length > 1 ? (
        <Source id="driven" type="geojson" data={driven}>
          <Layer
            id="driven-line"
            type="line"
            layout={{ 'line-cap': 'round', 'line-join': 'round' }}
            paint={{
              'line-color': '#00a86b',
              'line-width': 4,
              'line-opacity': replayed ? 0.3 : 0.9,
            }}
          />
        </Source>
      ) : null}
      {replayed && travelled && travelled.length > 1 ? (
        <Source id="replayed" type="geojson" data={replayed}>
          <Layer
            id="replayed-line"
            type="line"
            layout={{ 'line-cap': 'round', 'line-join': 'round' }}
            paint={{ 'line-color': '#00a86b', 'line-width': 5, 'line-opacity': 1 }}
          />
        </Source>
      ) : null}
      {stops.map((stop, position) => (
        <PlainMarker
          key={stop.id}
          latitude={stop.latitude}
          longitude={stop.longitude}
          anchor="center"
        >
          <span
            className="flex size-5 items-center justify-center rounded-full border-2 border-white bg-navy text-[10px] font-semibold text-white shadow"
            role="img"
            aria-label={`Stop ${position + 1}: ${stop.name}`}
            title={stop.name}
          >
            {position + 1}
          </span>
        </PlainMarker>
      ))}
      {bus ? (
        <PlainMarker latitude={bus.latitude} longitude={bus.longitude} anchor="center">
          <span
            className="flex size-8 items-center justify-center rounded-full border-2 border-white bg-brand text-white shadow-md"
            role="img"
            aria-label={busLabel}
          >
            <Bus className="size-4" aria-hidden />
          </span>
        </PlainMarker>
      ) : null}
    </MapView>
  )
}
