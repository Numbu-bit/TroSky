import type { Schemas } from '@/api/types'

import { positionAt, timeline } from './replay'

const at = (minute: number) => new Date(Date.UTC(2026, 9, 4, 7, minute)).toISOString()

// Due north along a meridian: 0.01° of latitude is about 1.112 km.
const POINTS: Schemas['TrackPoint'][] = [
  { latitude: 5.6, longitude: -0.2, speed_kmh: '30.00', recorded_at: at(0) },
  { latitude: 5.61, longitude: -0.2, speed_kmh: '40.00', recorded_at: at(2) },
  { latitude: 5.62, longitude: -0.2, speed_kmh: null, recorded_at: at(6) },
]

describe('trip replay', () => {
  it('measures time and distance along the points', () => {
    const line = timeline(POINTS)
    expect(line.start).toBe(Date.parse(at(0)))
    expect(line.end).toBe(Date.parse(at(6)))
    expect(line.distances[0]).toBe(0)
    expect(line.distances[1]).toBeCloseTo(1.112, 2)
    expect(line.distances[2]).toBeCloseTo(2.224, 2)
  })

  it('puts the bus between the points either side of the moment', () => {
    const line = timeline(POINTS)
    // A minute in: halfway to the second point, at the first one's speed.
    const position = positionAt(POINTS, line, Date.parse(at(1)))!
    expect(position.index).toBe(0)
    expect(position.latitude).toBeCloseTo(5.605, 6)
    expect(position.km).toBeCloseTo(0.556, 2)
    expect(position.speedKmh).toBe('30.00')
    // Three minutes in: a quarter of the way from the second to the third.
    const later = positionAt(POINTS, line, Date.parse(at(3)))!
    expect(later.index).toBe(1)
    expect(later.latitude).toBeCloseTo(5.6125, 6)
  })

  it('stays on the first and last points outside the recording', () => {
    const line = timeline(POINTS)
    expect(positionAt(POINTS, line, Date.parse(at(0)) - 60_000)).toMatchObject({
      index: 0,
      latitude: 5.6,
      km: 0,
    })
    const end = positionAt(POINTS, line, Date.parse(at(9)))!
    expect(end.index).toBe(2)
    expect(end.latitude).toBe(5.62)
    expect(end.speedKmh).toBeNull()
  })

  it('has nothing to show without points', () => {
    expect(positionAt([], timeline([]), Date.now())).toBeNull()
  })
})
