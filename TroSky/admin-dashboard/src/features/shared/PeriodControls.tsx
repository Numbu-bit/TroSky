import { useId } from 'react'

import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import { ToggleGroup, ToggleGroupItem } from '@/components/ui/toggle-group'
import { accraDateKey } from '@/lib/format'
import { useUrlState } from '@/lib/url-state'

import { CITIES, PRESETS, usePeriod } from './period'

/** The period presets (or custom dates), and the city when the figures take one. */
export function PeriodControls({ city = true }: { city?: boolean }) {
  const [period, update] = usePeriod()
  const [state] = useUrlState({ days: '30', from: '', to: '', city: '' })
  const fromId = useId()
  const toId = useId()
  const custom = state.days === 'custom'
  return (
    <div className="flex flex-wrap items-end gap-3" role="group" aria-label="Period and city">
      <ToggleGroup
        type="single"
        variant="outline"
        value={
          custom
            ? 'custom'
            : PRESETS.includes(state.days as (typeof PRESETS)[number])
              ? state.days
              : '30'
        }
        onValueChange={(value) => {
          if (!value) return
          if (value === 'custom') update({ days: 'custom', from: period.from, to: period.to })
          else update({ days: value, from: null, to: null })
        }}
        aria-label="Period"
      >
        <ToggleGroupItem value="7">7 days</ToggleGroupItem>
        <ToggleGroupItem value="30">30 days</ToggleGroupItem>
        <ToggleGroupItem value="90">90 days</ToggleGroupItem>
        <ToggleGroupItem value="custom">Custom</ToggleGroupItem>
      </ToggleGroup>
      {custom ? (
        <>
          <div className="grid gap-1">
            <Label htmlFor={fromId} className="text-xs">
              From
            </Label>
            <Input
              id={fromId}
              type="date"
              className="w-40"
              value={state.from}
              max={state.to || undefined}
              onChange={(event) => update({ from: event.target.value })}
            />
          </div>
          <div className="grid gap-1">
            <Label htmlFor={toId} className="text-xs">
              To
            </Label>
            <Input
              id={toId}
              type="date"
              className="w-40"
              value={state.to}
              min={state.from || undefined}
              max={accraDateKey()}
              onChange={(event) => update({ to: event.target.value })}
            />
          </div>
        </>
      ) : null}
      {city ? (
        <Select
          value={state.city || 'all'}
          onValueChange={(value) => update({ city: value === 'all' ? null : value })}
        >
          <SelectTrigger className="w-40" aria-label="City">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="all">All cities</SelectItem>
            {CITIES.map((city) => (
              <SelectItem key={city} value={city}>
                {city}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
      ) : null}
    </div>
  )
}
