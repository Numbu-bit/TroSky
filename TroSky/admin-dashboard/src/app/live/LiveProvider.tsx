import { useQueryClient } from '@tanstack/react-query'
import { useCallback, useEffect, useMemo, useState, type ReactNode } from 'react'

import { tokenStore } from '@/api/tokens'
import type { Schemas } from '@/api/types'
import { apiOrigin, env } from '@/lib/env'
import { localStore } from '@/lib/storage'

import { useAuth } from '../auth/auth-context'
import { LiveContext, type LiveStatus } from './live-context'

const SAVER_KEY = 'trosky-admin:data-saver'
const SOUND_KEY = 'trosky-admin:sos-sound'

/** Which cached data each pushed event makes stale. */
const INVALIDATES: Record<string, string[]> = {
  sos: ['sos', 'alerts', 'overview', 'notifications'],
  complaint: ['complaints', 'alerts', 'overview', 'notifications'],
  approval: ['approvals', 'alerts', 'notifications'],
  fraud: ['fraud', 'alerts'],
  // Drivers' answers and what followed them (topic "dispatch").
  booking: ['dispatch', 'trips', 'notifications'],
  trip: ['dispatch', 'trips'],
  passenger: ['dispatch', 'trips'],
}

interface PositionEvent {
  trip_id: string
  latitude: number
  longitude: number
  heading_degrees: string | null
  recorded_at: string
}

function useOnline(): boolean {
  const [online, setOnline] = useState(() => navigator.onLine)
  useEffect(() => {
    const on = () => setOnline(true)
    const off = () => setOnline(false)
    window.addEventListener('online', on)
    window.addEventListener('offline', off)
    return () => {
      window.removeEventListener('online', on)
      window.removeEventListener('offline', off)
    }
  }, [])
  return online
}

/**
 * Live data for the signed-in admin: the backend's event stream when it is
 * reachable (GET /admin/stream), reconnecting with backoff, and polling
 * meanwhile. Demo mode always polls.
 */
export function LiveProvider({ children }: { children: ReactNode }) {
  const queryClient = useQueryClient()
  const { state } = useAuth()
  const online = useOnline()
  const [streaming, setStreaming] = useState(false)
  const [dataSaver, setSaver] = useState(() => localStore.get(SAVER_KEY) === 'on')
  const [soundOn, setSound] = useState(() => localStore.get(SOUND_KEY) === 'on')
  const signedIn = state.status === 'signed-in'

  useEffect(() => {
    if (!signedIn || env.demoMode || typeof EventSource === 'undefined') return
    let source: EventSource | null = null
    let retry = 0
    let timer: ReturnType<typeof setTimeout> | undefined
    let stopped = false

    const schedule = () => {
      if (stopped) return
      const delay = Math.min(60_000, 5_000 * 2 ** retry)
      retry += 1
      timer = setTimeout(connect, delay)
    }

    function handle(type: string, data: string) {
      if (type === 'position') {
        const moved = JSON.parse(data) as PositionEvent
        queryClient.setQueryData<Schemas['LiveTripResponse'][]>(['live-trips'], (trips) =>
          trips?.map((trip) =>
            trip.trip_id === moved.trip_id
              ? {
                  ...trip,
                  latitude: moved.latitude,
                  longitude: moved.longitude,
                  heading: moved.heading_degrees,
                  updated_at: moved.recorded_at,
                  is_stale: false,
                }
              : trip,
          ),
        )
        return
      }
      const roots = INVALIDATES[type.split('.')[0] ?? ''] ?? []
      for (const root of roots) void queryClient.invalidateQueries({ queryKey: [root] })
    }

    function connect() {
      const token = tokenStore.access
      if (!token) {
        schedule()
        return
      }
      const url = new URL(`${apiOrigin}/api/v1/admin/stream`, window.location.origin)
      url.searchParams.set('token', token)
      source = new EventSource(url)
      source.onopen = () => {
        retry = 0
        setStreaming(true)
      }
      source.onerror = () => {
        source?.close()
        setStreaming(false)
        schedule()
      }
      for (const type of [
        'sos.created',
        'sos.updated',
        'complaint.created',
        'complaint.updated',
        'approval.requested',
        'approval.document_uploaded',
        'fraud.flagged',
        'fraud.updated',
        'booking.awaiting_acceptance',
        'booking.accepted',
        'booking.moved',
        'booking.not_accepted',
        'trip.accepted',
        'trip.declined',
        'passenger.alighted',
        'position',
      ]) {
        source.addEventListener(type, (event) => handle(type, (event as MessageEvent<string>).data))
      }
      // Access withdrawn (signed out, suspended): stop; requests will say why.
      source.addEventListener('end', () => {
        source?.close()
        setStreaming(false)
      })
    }

    connect()
    return () => {
      stopped = true
      source?.close()
      clearTimeout(timer)
      setStreaming(false)
    }
  }, [signedIn, queryClient])

  const setDataSaver = useCallback((on: boolean) => {
    setSaver(on)
    if (on) localStore.set(SAVER_KEY, 'on')
    else localStore.remove(SAVER_KEY)
  }, [])
  const setSoundOn = useCallback((on: boolean) => {
    setSound(on)
    if (on) localStore.set(SOUND_KEY, 'on')
    else localStore.remove(SOUND_KEY)
  }, [])

  const status: LiveStatus = !online ? 'offline' : streaming ? 'stream' : 'polling'
  const value = useMemo(
    () => ({ status, dataSaver, setDataSaver, soundOn, setSoundOn }),
    [status, dataSaver, setDataSaver, soundOn, setSoundOn],
  )
  return <LiveContext value={value}>{children}</LiveContext>
}
