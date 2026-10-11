import { createContext, useContext } from 'react'

import { env } from '@/lib/env'

export type LiveStatus = 'stream' | 'polling' | 'offline'

export interface LiveContextValue {
  /** How live data arrives now: pushed, polled, or not at all. */
  status: LiveStatus
  /** Data saver: refresh every 30 s, without animation. */
  dataSaver: boolean
  setDataSaver: (on: boolean) => void
  /** A sound when a new SOS comes in. */
  soundOn: boolean
  setSoundOn: (on: boolean) => void
}

export const LiveContext = createContext<LiveContextValue | null>(null)

export function useLive(): LiveContextValue {
  const context = useContext(LiveContext)
  if (!context) throw new Error('useLive must be used inside <LiveProvider>.')
  return context
}

/**
 * How often live queries refetch: every 5-10 s (SRS FR-006), 30 s in data
 * saver mode, and only as a safety net when the server pushes updates.
 * Never while offline. Hidden tabs do not refetch at all (TanStack Query).
 */
export function useLiveInterval(): number | false {
  const { status, dataSaver } = useLive()
  if (status === 'offline') return false
  if (status === 'stream') return 60_000
  return dataSaver ? 30_000 : env.liveRefreshSeconds * 1000
}

/** Query keys whose data is live, for the "last updated" indicator. */
export const LIVE_QUERY_ROOTS = new Set(['live-trips', 'sos'])
