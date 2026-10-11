import type { ViewState } from 'react-map-gl/maplibre'

export const ACCRA: Pick<ViewState, 'latitude' | 'longitude' | 'zoom'> = {
  latitude: 5.61,
  longitude: -0.2,
  zoom: 10.6,
}

let webgl: boolean | null = null

/** Whether this browser can draw the map at all (WebGL). */
export function mapSupported(): boolean {
  if (webgl === null) {
    try {
      const canvas = document.createElement('canvas')
      webgl = Boolean(canvas.getContext('webgl2') ?? canvas.getContext('webgl'))
    } catch {
      webgl = false
    }
  }
  return webgl
}
