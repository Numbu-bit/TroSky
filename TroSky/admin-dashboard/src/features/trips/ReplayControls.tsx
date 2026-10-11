import { Pause, Play, Undo2 } from 'lucide-react'

import { Button } from '@/components/ui/button'
import { Slider } from '@/components/ui/slider'
import { ToggleGroup, ToggleGroupItem } from '@/components/ui/toggle-group'
import { formatClock, formatNumber, formatTime } from '@/lib/format'

import { REPLAY_SPEEDS, type ReplayPosition, type Timeline, type useReplay } from './replay'

/**
 * Play, pause and scrub through a trip's recorded positions. The arrow
 * keys move the slider about a 300th of the trip, Page Up and Down ten
 * times that; it reads out the time of day.
 */
export function ReplayControls({
  line,
  replay,
  position,
  live,
}: {
  line: Timeline
  replay: ReturnType<typeof useReplay>
  position: ReplayPosition | null
  /** On the road: leaving the replay shows the bus now. */
  live: boolean
}) {
  const seconds = Math.max(Math.round((line.end - line.start) / 1000), 1)
  // About 300 steps, whatever the trip's length.
  const step = Math.max(Math.round(seconds / 300), 1)
  const moment = replay.at ?? line.end
  const offset = Math.round((moment - line.start) / 1000)
  const totalKm = line.distances.at(-1) ?? 0

  return (
    <div className="space-y-3 rounded-lg border bg-card p-3" role="group" aria-label="Trip replay">
      <div className="flex flex-wrap items-center gap-3">
        <Button
          size="sm"
          variant={replay.running ? 'secondary' : 'default'}
          onClick={replay.running ? replay.pause : replay.play}
        >
          {replay.running ? <Pause aria-hidden /> : <Play aria-hidden />}
          {replay.running ? 'Pause' : replay.at === null ? 'Replay the trip' : 'Play'}
        </Button>
        <div className="min-w-48 flex-1 space-y-1">
          <Slider
            label="Moment in the trip"
            valueText={formatClock(moment)}
            min={0}
            max={seconds}
            step={step}
            value={[Math.min(offset, seconds)]}
            onValueChange={([value]) => replay.seek(line.start + (value ?? 0) * 1000)}
          />
          <div className="figure flex justify-between text-xs text-muted-foreground">
            <span>{formatTime(line.start)}</span>
            <span>{formatTime(line.end)}</span>
          </div>
        </div>
        <ToggleGroup
          type="single"
          variant="outline"
          size="sm"
          value={String(replay.speed)}
          onValueChange={(value: string) => value && replay.setSpeed(Number(value))}
          aria-label="Replay speed"
        >
          {REPLAY_SPEEDS.map((speed) => (
            <ToggleGroupItem
              key={speed}
              value={String(speed)}
              aria-label={`${speed} times as fast`}
            >
              {speed}×
            </ToggleGroupItem>
          ))}
        </ToggleGroup>
      </div>
      {replay.at !== null && position ? (
        <div className="flex flex-wrap items-center justify-between gap-2 text-sm">
          <p className="figure">
            <span className="font-medium">{formatClock(replay.at)}</span>
            {position.speedKmh !== null ? ` · ${formatNumber(position.speedKmh)} km/h` : ''}
            {` · ${formatNumber(position.km.toFixed(1), { decimals: true })} of ${formatNumber(totalKm.toFixed(1), { decimals: true })} km`}
          </p>
          <Button size="sm" variant="ghost" onClick={replay.stop}>
            <Undo2 aria-hidden /> {live ? 'Back to now' : 'Whole trip'}
          </Button>
        </div>
      ) : (
        <p className="text-sm text-muted-foreground">
          Plays the trip back from its recorded positions. Drag the slider to see where the bus was
          at any moment.
        </p>
      )}
    </div>
  )
}
