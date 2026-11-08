import 'maplibre-gl/dist/maplibre-gl.css'

import { MapPinOff } from 'lucide-react'
import type * as MapLibre from 'maplibre-gl'
import workerUrl from 'maplibre-gl/dist/maplibre-gl-worker.mjs?worker&url'
import { forwardRef, type ReactNode } from 'react'
import Map, { AttributionControl, NavigationControl, type MapRef } from 'react-map-gl/maplibre'

import { useTheme } from '@/app/theme-context'
import { cn } from '@/lib/utils'

import { ACCRA, mapSupported } from './map-support'

/** Free, keyless basemaps that follow the theme (CARTO). */
const STYLES = {
  light: 'https://basemaps.cartocdn.com/gl/positron-gl-style/style.json',
  dark: 'https://basemaps.cartocdn.com/gl/dark-matter-gl-style/style.json',
}

let mapLibrary: Promise<typeof MapLibre> | null = null

/**
 * MapLibre, loaded the first time a map is drawn, and told where the worker
 * that draws its tiles is: it can't find one a bundler has moved, and without
 * it a map shows its markers on a blank background.
 */
function loadMapLibrary() {
  mapLibrary ??= import('maplibre-gl').then((maplibre) => {
    maplibre.setWorkerUrl(workerUrl)
    return maplibre
  })
  return mapLibrary
}

export function MapUnavailable({ className }: { className?: string }) {
  return (
    <div
      className={cn(
        'flex h-full min-h-48 flex-col items-center justify-center gap-2 rounded-lg border border-dashed bg-muted/40 p-6 text-center text-sm text-muted-foreground',
        className,
      )}
    >
      <MapPinOff className="size-6" aria-hidden />
      This device can’t draw maps. The same information is in the list.
    </div>
  )
}

interface MapViewProps {
  /** A centre and zoom, or ``bounds`` to fit. */
  initialViewState?: React.ComponentProps<typeof Map>['initialViewState']
  children?: ReactNode
  className?: string
  interactiveLayerIds?: string[]
  onClick?: React.ComponentProps<typeof Map>['onClick']
  /** The zoom once a zoom gesture or animation ends. */
  onZoomEnd?: (zoom: number) => void
  label: string
}

export const MapView = forwardRef<MapRef, MapViewProps>(function MapView(
  { initialViewState = ACCRA, children, className, interactiveLayerIds, onClick, onZoomEnd, label },
  ref,
) {
  const { resolvedTheme } = useTheme()
  if (!mapSupported()) return <MapUnavailable className={className} />
  return (
    <div
      className={cn('overflow-hidden rounded-lg border', className)}
      role="region"
      aria-label={label}
    >
      <Map
        ref={ref}
        mapLib={loadMapLibrary()}
        initialViewState={initialViewState}
        mapStyle={STYLES[resolvedTheme]}
        style={{ width: '100%', height: '100%' }}
        interactiveLayerIds={interactiveLayerIds}
        onClick={onClick}
        onZoomEnd={(event) => onZoomEnd?.(event.viewState.zoom)}
        attributionControl={false}
        cooperativeGestures={false}
      >
        <NavigationControl position="top-right" showCompass={false} />
        <AttributionControl compact position="bottom-right" />
        {children}
      </Map>
    </div>
  )
})
