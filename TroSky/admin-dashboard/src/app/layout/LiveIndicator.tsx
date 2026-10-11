import { useQueryClient } from '@tanstack/react-query'
import { Radio, WifiOff } from 'lucide-react'
import { useCallback, useId, useSyncExternalStore } from 'react'

import { Button } from '@/components/ui/button'
import { Label } from '@/components/ui/label'
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover'
import { Switch } from '@/components/ui/switch'
import { env } from '@/lib/env'
import { formatRelative } from '@/lib/format'
import { useNow } from '@/lib/use-now'
import { cn } from '@/lib/utils'

import { LIVE_QUERY_ROOTS, useLive } from '../live/live-context'

/** When any live data last arrived. */
function useLastLiveUpdate(): number {
  const queryClient = useQueryClient()
  const subscribe = useCallback(
    (onChange: () => void) => queryClient.getQueryCache().subscribe(onChange),
    [queryClient],
  )
  const read = useCallback(() => {
    let newest = 0
    for (const query of queryClient.getQueryCache().getAll()) {
      if (LIVE_QUERY_ROOTS.has(String(query.queryKey[0])) && query.state.dataUpdatedAt > newest) {
        newest = query.state.dataUpdatedAt
      }
    }
    return newest
  }, [queryClient])
  return useSyncExternalStore(subscribe, read, read)
}

export function LiveIndicator() {
  const { status, dataSaver, setDataSaver, soundOn, setSoundOn } = useLive()
  const lastUpdate = useLastLiveUpdate()
  const now = useNow(1000)
  const saverId = useId()
  const soundId = useId()

  const label =
    status === 'offline'
      ? 'Offline'
      : status === 'stream'
        ? 'Live'
        : `Every ${dataSaver ? 30 : env.liveRefreshSeconds} s`
  return (
    <Popover>
      <PopoverTrigger asChild>
        <Button
          variant="ghost"
          size="sm"
          className="gap-2 px-2"
          aria-label={`Live updates: ${label}`}
        >
          {status === 'offline' ? (
            <WifiOff className="text-danger-text" aria-hidden />
          ) : (
            <span className="relative flex size-2.5" aria-hidden>
              {status === 'stream' && !dataSaver ? (
                <span className="absolute inline-flex size-full animate-ping rounded-full bg-brand opacity-60" />
              ) : null}
              <span
                className={cn(
                  'relative inline-flex size-2.5 rounded-full',
                  status === 'stream' ? 'bg-brand' : 'bg-gold',
                )}
              />
            </span>
          )}
          <span className="hidden text-xs text-muted-foreground lg:inline">
            {label}
            {lastUpdate ? ` · ${formatRelative(lastUpdate, now)}` : ''}
          </span>
        </Button>
      </PopoverTrigger>
      <PopoverContent align="end" className="w-72 space-y-3">
        <div className="flex items-start gap-2">
          <Radio className="mt-0.5 size-4 text-muted-foreground" aria-hidden />
          <div className="space-y-0.5 text-sm">
            <p className="font-medium">
              {status === 'offline'
                ? 'You’re offline'
                : status === 'stream'
                  ? 'Updates arrive as they happen'
                  : `Refreshing every ${dataSaver ? 30 : env.liveRefreshSeconds} seconds`}
            </p>
            <p className="text-muted-foreground">
              {status === 'offline'
                ? 'Live data will resume when the connection is back.'
                : lastUpdate
                  ? `Last update ${formatRelative(lastUpdate, now)}.`
                  : 'Waiting for the first update.'}
              {status === 'polling' && !env.demoMode ? ' Reconnecting to the live feed…' : ''}
            </p>
          </div>
        </div>
        <div className="flex items-center justify-between gap-3">
          <Label htmlFor={saverId} className="grid gap-0.5 font-normal">
            <span className="font-medium">Data saver</span>
            <span className="text-xs text-muted-foreground">Refresh every 30 s, no animation</span>
          </Label>
          <Switch id={saverId} checked={dataSaver} onCheckedChange={setDataSaver} />
        </div>
        <div className="flex items-center justify-between gap-3">
          <Label htmlFor={soundId} className="grid gap-0.5 font-normal">
            <span className="font-medium">SOS sound</span>
            <span className="text-xs text-muted-foreground">Play a tone when an SOS comes in</span>
          </Label>
          <Switch id={soundId} checked={soundOn} onCheckedChange={setSoundOn} />
        </div>
      </PopoverContent>
    </Popover>
  )
}
