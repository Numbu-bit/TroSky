import { MapPin } from 'lucide-react'

import { MapView } from '@/components/map/MapView'
import { PlainMarker } from '@/components/map/PlainMarker'
import { ACCRA } from '@/components/map/map-support'

export interface Pin {
  latitude: number
  longitude: number
}

const round = (value: number) => Math.round(value * 1e6) / 1e6

/**
 * Click (or drag the pin) to place a stop. The latitude and longitude
 * fields beside it do the same for keyboard users. Loaded on demand.
 */
export default function PinMap({
  value,
  onChange,
}: {
  value: Pin | null
  onChange: (pin: Pin) => void
}) {
  return (
    <MapView
      label="Map: click to place the stop"
      className="h-60"
      initialViewState={value ? { ...value, zoom: 15 } : ACCRA}
      onClick={(event) =>
        onChange({ latitude: round(event.lngLat.lat), longitude: round(event.lngLat.lng) })
      }
    >
      {value ? (
        <PlainMarker
          latitude={value.latitude}
          longitude={value.longitude}
          anchor="bottom"
          draggable
          onDragEnd={(event) =>
            onChange({ latitude: round(event.lngLat.lat), longitude: round(event.lngLat.lng) })
          }
        >
          <MapPin
            className="size-9 fill-brand/25 text-brand-strong drop-shadow"
            role="img"
            aria-label="The stop"
          />
        </PlainMarker>
      ) : null}
    </MapView>
  )
}
