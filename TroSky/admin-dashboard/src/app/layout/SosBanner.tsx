import { Siren } from 'lucide-react'
import { useEffect, useRef } from 'react'
import { Link } from 'react-router'

import { useSession } from '@/app/auth/auth-context'
import { useActiveSos } from '@/features/safety/api'
import { formatRelative } from '@/lib/format'
import { useNow } from '@/lib/use-now'

import { useLive } from '../live/live-context'

/** A short two-tone alarm, made in the browser (no audio file to load). */
function playAlarm(): void {
  try {
    const context = new AudioContext()
    const tones = [880, 660, 880]
    tones.forEach((frequency, index) => {
      const oscillator = context.createOscillator()
      const gain = context.createGain()
      oscillator.frequency.value = frequency
      gain.gain.value = 0.08
      oscillator.connect(gain).connect(context.destination)
      oscillator.start(context.currentTime + index * 0.22)
      oscillator.stop(context.currentTime + index * 0.22 + 0.18)
    })
    setTimeout(() => void context.close(), 1200)
  } catch {
    // No audio (blocked autoplay, no device): the banner still shows.
  }
}

/**
 * Red, on every page, while any SOS has not been acknowledged: someone may
 * be in danger and nobody has picked it up yet.
 */
export function SosBanner() {
  const { can } = useSession()
  const allowed = can('sos:review')
  const { data } = useActiveSos(allowed)
  const { soundOn } = useLive()
  const now = useNow(5000)
  const seen = useRef<Set<string> | null>(null)
  const alerts = data?.items ?? []

  useEffect(() => {
    if (!data) return
    const ids = new Set(data.items.map((alert) => alert.id))
    // The first load is not news; anything new after it is.
    if (seen.current && soundOn && [...ids].some((id) => !seen.current!.has(id))) playAlarm()
    seen.current = ids
  }, [data, soundOn])

  if (!allowed || alerts.length === 0) return null
  const newest = alerts[0]!
  return (
    <div
      role="alert"
      data-print="hide"
      className="flex flex-wrap items-center gap-x-4 gap-y-2 bg-danger px-4 py-2 text-sm text-danger-foreground sm:px-6"
    >
      <span className="flex items-center gap-2 font-semibold">
        <Siren className="size-4 motion-safe:animate-pulse" aria-hidden />
        {alerts.length === 1
          ? 'SOS not yet acknowledged'
          : `${alerts.length} SOS alerts not yet acknowledged`}
      </span>
      <span>Raised {formatRelative(newest.created_at, now)}</span>
      {/* Red on white (5:1 or more in both themes), not white on a tint. */}
      <Link
        to={`/safety?status=open&alert=${newest.id}`}
        className="ml-auto rounded-md bg-white px-3 py-1 font-semibold text-danger hover:bg-white/90 focus-visible:ring-2 focus-visible:ring-white focus-visible:ring-offset-2 focus-visible:ring-offset-danger focus-visible:outline-none"
      >
        Open SOS
      </Link>
    </div>
  )
}
