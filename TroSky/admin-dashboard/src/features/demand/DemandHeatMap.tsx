import type { FeatureCollection, Point } from 'geojson'
import { Layer, Source } from 'react-map-gl/maplibre'

import type { Schemas } from '@/api/types'
import { MapView } from '@/components/map/MapView'
import { ACCRA } from '@/components/map/map-support'

/** The cells holding most of the demand, so a few far-off ones don't shrink the view. */
function busiest(cells: Schemas['DemandCell'][], share = 0.9): Schemas['DemandCell'][] {
  const sorted = [...cells].sort((a, b) => b.weight - a.weight)
  const total = sorted.reduce((sum, cell) => sum + cell.weight, 0)
  const kept: Schemas['DemandCell'][] = []
  let sum = 0
  for (const cell of sorted) {
    kept.push(cell)
    sum += cell.weight
    if (sum >= total * share) break
  }
  return kept
}

/**
 * Where demand is, as a heat map of ~550 m cells (the blue magnitude ramp).
 * It opens on where 90% of the demand is; the rest is a pan or zoom away.
 * Loaded on demand: it pulls in the map library.
 */
export default function DemandHeatMap({
  cells,
  label,
}: {
  cells: Schemas['DemandCell'][]
  label: string
}) {
  const max = Math.max(1, ...cells.map((cell) => cell.weight))
  const data: FeatureCollection<Point, { weight: number }> = {
    type: 'FeatureCollection',
    features: cells.map((cell) => ({
      type: 'Feature',
      properties: { weight: cell.weight },
      geometry: { type: 'Point', coordinates: [Number(cell.longitude), Number(cell.latitude)] },
    })),
  }
  const focus = busiest(cells)
  const latitudes = focus.map((cell) => Number(cell.latitude))
  const longitudes = focus.map((cell) => Number(cell.longitude))
  const view = cells.length
    ? {
        bounds: [
          [Math.min(...longitudes), Math.min(...latitudes)],
          [Math.max(...longitudes), Math.max(...latitudes)],
        ] as [[number, number], [number, number]],
        fitBoundsOptions: { padding: 40, maxZoom: 13 },
      }
    : ACCRA
  return (
    <MapView label={label} className="h-112" initialViewState={view}>
      <Source id="demand" type="geojson" data={data}>
        <Layer
          id="demand-heat"
          type="heatmap"
          paint={{
            'heatmap-weight': ['interpolate', ['linear'], ['get', 'weight'], 0, 0, max, 1],
            'heatmap-intensity': ['interpolate', ['linear'], ['zoom'], 6, 1, 9, 1, 14, 2.5],
            'heatmap-radius': ['interpolate', ['linear'], ['zoom'], 6, 8, 9, 14, 14, 36],
            'heatmap-color': [
              'interpolate',
              ['linear'],
              ['heatmap-density'],
              0,
              'rgba(205, 226, 251, 0)',
              0.2,
              '#cde2fb',
              0.4,
              '#9cc4f2',
              0.6,
              '#5f9be0',
              0.8,
              '#2c6ebd',
              1,
              '#0d366b',
            ],
            'heatmap-opacity': 0.85,
          }}
        />
      </Source>
    </MapView>
  )
}
