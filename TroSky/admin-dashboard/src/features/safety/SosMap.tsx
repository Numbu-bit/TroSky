import { Bus, Siren } from 'lucide-react'

import { MapView } from '@/components/map/MapView'
import { PlainMarker } from '@/components/map/PlainMarker'

/** Where the SOS was raised, and where the bus is now. Loaded on demand. */
export default function SosMap({
  alert,
  bus,
}: {
  alert: { latitude: number; longitude: number } | null
  bus: { latitude: number; longitude: number } | null
}) {
  const center = alert ?? bus
  if (!center) return null
  return (
    <MapView
      label="Where the SOS was raised"
      className="h-56"
      initialViewState={{ latitude: center.latitude, longitude: center.longitude, zoom: 14 }}
    >
      {alert ? (
        <PlainMarker latitude={alert.latitude} longitude={alert.longitude} anchor="center">
          <span
            className="flex size-8 items-center justify-center rounded-full border-2 border-white bg-danger text-danger-foreground shadow-md"
            role="img"
            aria-label="Where the SOS was raised"
          >
            <Siren className="size-4" aria-hidden />
          </span>
        </PlainMarker>
      ) : null}
      {bus ? (
        <PlainMarker latitude={bus.latitude} longitude={bus.longitude} anchor="center">
          <span
            className="flex size-8 items-center justify-center rounded-full border-2 border-white bg-brand text-white shadow-md"
            role="img"
            aria-label="The bus now"
          >
            <Bus className="size-4" aria-hidden />
          </span>
        </PlainMarker>
      ) : null}
    </MapView>
  )
}
