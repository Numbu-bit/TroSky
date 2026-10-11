/** Distances and positions along a route, for the demo's moving buses. */

export interface LatLng {
  latitude: number
  longitude: number
}

const EARTH_KM = 6371

function radians(degrees: number): number {
  return (degrees * Math.PI) / 180
}

export function haversineKm(a: LatLng, b: LatLng): number {
  const dLat = radians(b.latitude - a.latitude)
  const dLng = radians(b.longitude - a.longitude)
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(radians(a.latitude)) * Math.cos(radians(b.latitude)) * Math.sin(dLng / 2) ** 2
  return 2 * EARTH_KM * Math.asin(Math.sqrt(h))
}

/** Degrees clockwise from north, 0-359. */
export function bearing(a: LatLng, b: LatLng): number {
  const y = Math.sin(radians(b.longitude - a.longitude)) * Math.cos(radians(b.latitude))
  const x =
    Math.cos(radians(a.latitude)) * Math.sin(radians(b.latitude)) -
    Math.sin(radians(a.latitude)) *
      Math.cos(radians(b.latitude)) *
      Math.cos(radians(b.longitude - a.longitude))
  return (Math.round((Math.atan2(y, x) * 180) / Math.PI) + 360) % 360
}

/** Cumulative km at each point. */
export function offsets(points: LatLng[]): number[] {
  const result = [0]
  for (let index = 1; index < points.length; index += 1) {
    result.push((result[index - 1] ?? 0) + haversineKm(points[index - 1]!, points[index]!))
  }
  return result
}

/** The position ``fraction`` (0-1) of the way along ``points``, and its heading. */
export function along(points: LatLng[], fraction: number): LatLng & { heading: number } {
  const cumulative = offsets(points)
  const total = cumulative[cumulative.length - 1] ?? 0
  const target = Math.min(Math.max(fraction, 0), 1) * total
  for (let index = 1; index < points.length; index += 1) {
    const start = cumulative[index - 1]!
    const end = cumulative[index]!
    if (target <= end || index === points.length - 1) {
      const a = points[index - 1]!
      const b = points[index]!
      const share = end > start ? (target - start) / (end - start) : 0
      return {
        latitude: a.latitude + (b.latitude - a.latitude) * share,
        longitude: a.longitude + (b.longitude - a.longitude) * share,
        heading: bearing(a, b),
      }
    }
  }
  const only = points[0] ?? { latitude: 5.6, longitude: -0.2 }
  return { ...only, heading: 0 }
}
