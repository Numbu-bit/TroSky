import { useEffect, useRef, type ComponentPropsWithoutRef, type ComponentRef } from 'react'
import { Marker } from 'react-map-gl/maplibre'

/**
 * A map marker whose content speaks for itself: a button, or an image with
 * a label. MapLibre gives each marker's wrapper role="button" and the name
 * "Map marker", which would put a control around ours (and isn't focusable
 * anyway). They are taken off once the marker is on the map: react-map-gl
 * adds it in its own effect, which runs before this one.
 */
export function PlainMarker(props: ComponentPropsWithoutRef<typeof Marker>) {
  const marker = useRef<ComponentRef<typeof Marker>>(null)
  useEffect(() => {
    const element = marker.current?.getElement()
    element?.removeAttribute('role')
    element?.removeAttribute('aria-label')
  }, [])
  return <Marker ref={marker} {...props} />
}
