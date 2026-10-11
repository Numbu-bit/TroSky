import { useEffect, useState } from 'react'

import type { Schemas } from '@/api/types'

type Point = Schemas['TrackPoint']

/** A trip's recorded points along time and distance. */
export interface Timeline {
  /** When each point was recorded (ms). */
  times: number[]
  /** Kilometres driven from the first point to each point. */
  distances: number[]
  start: number
  end: number
}

const EARTH_RADIUS_KM = 6371.0088

function kilometres(a: Point, b: Point): number {
  const radians = Math.PI / 180
  const dLat = (b.latitude - a.latitude) * radians
  const dLon = (b.longitude - a.longitude) * radians
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(a.latitude * radians) * Math.cos(b.latitude * radians) * Math.sin(dLon / 2) ** 2
  return 2 * EARTH_RADIUS_KM * Math.asin(Math.min(1, Math.sqrt(h)))
}

/** ``points`` come oldest first, as the track endpoint returns them. */
export function timeline(points: Point[]): Timeline {
  const times = points.map((point) => Date.parse(point.recorded_at))
  const distances: number[] = []
  points.forEach((point, index) => {
    distances.push(index === 0 ? 0 : distances[index - 1]! + kilometres(points[index - 1]!, point))
  })
  return { times, distances, start: times[0] ?? 0, end: times.at(-1) ?? 0 }
}

export interface ReplayPosition {
  latitude: number
  longitude: number
  /** The last point recorded at or before the moment. */
  index: number
  km: number
  speedKmh: string | null
}

/** Where the bus was at ``at``: between the last point before it and the next. */
export function positionAt(points: Point[], line: Timeline, at: number): ReplayPosition | null {
  if (!points.length) return null
  // The last point recorded at or before ``at`` (binary search).
  let low = 0
  let high = line.times.length - 1
  while (low < high) {
    const middle = Math.ceil((low + high) / 2)
    if (line.times[middle]! <= at) low = middle
    else high = middle - 1
  }
  const index = low
  const here = points[index]!
  const next = points[index + 1]
  const span = next ? line.times[index + 1]! - line.times[index]! : 0
  const share = next && span > 0 ? Math.min(Math.max((at - line.times[index]!) / span, 0), 1) : 0
  const between = (from: number, to: number) => from + (to - from) * share
  return {
    latitude: next ? between(here.latitude, next.latitude) : here.latitude,
    longitude: next ? between(here.longitude, next.longitude) : here.longitude,
    index,
    km: next ? between(line.distances[index]!, line.distances[index + 1]!) : line.distances[index]!,
    speedKmh: here.speed_kmh ?? null,
  }
}

/** How many times faster than it happened. */
export const REPLAY_SPEEDS = [15, 60, 240] as const

/**
 * Playing a trip back: ``at`` is the moment shown (null when not
 * replaying). It advances by the real time elapsed times the speed, so
 * a 60-minute trip takes a minute at 60x, and pauses in a hidden tab.
 */
export function useReplay(line: Timeline) {
  const [at, setAt] = useState<number | null>(null)
  const [playing, setPlaying] = useState(false)
  const [speed, setSpeed] = useState<number>(60)
  const { start, end } = line
  const shown = at === null ? null : Math.min(Math.max(at, start), end)
  const ended = shown !== null && shown >= end
  const running = playing && !ended

  useEffect(() => {
    if (!running) return
    let frame = 0
    let last = performance.now()
    const step = (now: number) => {
      const elapsed = Math.max(now - last, 0)
      last = now
      setAt((previous) => Math.min(Math.max(previous ?? start, start) + elapsed * speed, end))
      frame = requestAnimationFrame(step)
    }
    frame = requestAnimationFrame(step)
    return () => cancelAnimationFrame(frame)
  }, [running, speed, start, end])

  return {
    at: shown,
    running,
    speed,
    setSpeed,
    /** From the start when not replaying yet or at the end. */
    play: () => {
      if (shown === null || ended) setAt(start)
      setPlaying(true)
    },
    pause: () => setPlaying(false),
    /** Moving the slider keeps a running replay running, a paused one paused. */
    seek: (moment: number) => {
      setAt(moment)
      if (!running) setPlaying(false)
    },
    /** Back to the whole trip (and, on the road, the bus now). */
    stop: () => {
      setAt(null)
      setPlaying(false)
    },
  }
}
