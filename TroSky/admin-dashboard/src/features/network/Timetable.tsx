import { zodResolver } from '@hookform/resolvers/zod'
import { CalendarClock, Plus } from 'lucide-react'
import { useId } from 'react'
import { Controller, useForm } from 'react-hook-form'
import { toast } from 'sonner'
import { z } from 'zod'

import { errorMessage, fieldErrors } from '@/api/errors'
import { EmptyState, QueryState, TableSkeleton } from '@/components/feedback/states'
import { Button } from '@/components/ui/button'
import { Checkbox } from '@/components/ui/checkbox'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { useSchedules } from '@/features/shared/reference'
import { formatMoney } from '@/lib/format'
import { cedis } from '@/lib/validation'

import { useAddSchedule } from './api'
import { DAYS, formatDays, WEEKDAYS, WEEKEND, type Day } from './days'

const entrySchema = z.object({
  time: z.string().regex(/^\d{2}:\d{2}$/, 'Choose the departure time.'),
  days: z.array(z.string()).min(1, 'Choose at least one day.'),
  fare: cedis,
})

type EntryInput = z.input<typeof entrySchema>

function AddEntry({ routeId }: { routeId: string }) {
  const add = useAddSchedule(routeId)
  const id = useId()
  const form = useForm<EntryInput>({
    resolver: zodResolver(entrySchema),
    defaultValues: { time: '', days: [...WEEKDAYS], fare: '' },
  })
  const { errors, isSubmitting } = form.formState

  const submit = form.handleSubmit(async (values) => {
    try {
      await add.mutateAsync({
        departure_time: `${values.time}:00`,
        days_of_week: DAYS.map((day) => day.value).filter((day) => values.days.includes(day)),
        fare_amount: values.fare,
      })
      toast.success(`Departure at ${values.time} added.`)
      form.reset({ time: '', days: values.days, fare: values.fare })
    } catch (error) {
      const fields = fieldErrors(error)
      if (fields.fare_amount) form.setError('fare', { message: fields.fare_amount })
      else if (fields.departure_time) form.setError('time', { message: fields.departure_time })
      else toast.error(errorMessage(error))
    }
  })

  return (
    <form className="space-y-3 rounded-lg border bg-muted/30 p-3" onSubmit={submit} noValidate>
      <p className="text-sm font-medium">Add a departure</p>
      <div className="grid grid-cols-2 gap-3">
        <div className="grid gap-1.5">
          <Label htmlFor={`${id}-time`}>Leaves at</Label>
          <Input
            id={`${id}-time`}
            type="time"
            aria-invalid={errors.time ? true : undefined}
            aria-describedby={errors.time ? `${id}-time-error` : undefined}
            {...form.register('time')}
          />
          {errors.time ? (
            <p id={`${id}-time-error`} className="text-sm text-danger-text">
              {errors.time.message}
            </p>
          ) : null}
        </div>
        <div className="grid gap-1.5">
          <Label htmlFor={`${id}-fare`}>Fare (GH₵)</Label>
          <Input
            id={`${id}-fare`}
            inputMode="decimal"
            placeholder="8.00"
            aria-invalid={errors.fare ? true : undefined}
            aria-describedby={errors.fare ? `${id}-fare-error` : undefined}
            {...form.register('fare')}
          />
          {errors.fare ? (
            <p id={`${id}-fare-error`} className="text-sm text-danger-text">
              {errors.fare.message}
            </p>
          ) : null}
        </div>
      </div>
      <Controller
        control={form.control}
        name="days"
        render={({ field }) => {
          const chosen = new Set(field.value)
          const set = (days: readonly string[]) => field.onChange([...days])
          return (
            <fieldset className="space-y-2">
              <legend className="text-sm">Runs on</legend>
              <div className="flex flex-wrap gap-1">
                <Button
                  type="button"
                  size="sm"
                  variant="ghost"
                  onClick={() => set(DAYS.map((day) => day.value))}
                >
                  Every day
                </Button>
                <Button type="button" size="sm" variant="ghost" onClick={() => set(WEEKDAYS)}>
                  Mon–Fri
                </Button>
                <Button type="button" size="sm" variant="ghost" onClick={() => set(WEEKEND)}>
                  Weekends
                </Button>
              </div>
              <div className="flex flex-wrap gap-x-4 gap-y-2">
                {DAYS.map((day) => (
                  <label key={day.value} className="flex items-center gap-1.5 text-sm">
                    <Checkbox
                      checked={chosen.has(day.value)}
                      onCheckedChange={(checked) =>
                        set(
                          checked
                            ? [...field.value, day.value]
                            : field.value.filter((value) => value !== day.value),
                        )
                      }
                      aria-label={day.label}
                    />
                    <span aria-hidden>{day.short}</span>
                  </label>
                ))}
              </div>
              {errors.days ? (
                <p className="text-sm text-danger-text">{errors.days.message}</p>
              ) : null}
            </fieldset>
          )
        }}
      />
      <Button type="submit" size="sm" disabled={isSubmitting}>
        <Plus aria-hidden /> Add departure
      </Button>
    </form>
  )
}

/** A route's timetable: its regular departures, and a form to add one. */
export function Timetable({ routeId, manages }: { routeId: string; manages: boolean }) {
  const schedules = useSchedules(routeId)
  return (
    <div className="space-y-3">
      <QueryState
        query={schedules}
        skeleton={<TableSkeleton rows={3} columns={3} />}
        isEmpty={(entries) => entries.length === 0}
        empty={
          <EmptyState
            icon={CalendarClock}
            title="No timetable yet"
            description="Regular departures make trips quicker to set up."
          />
        }
      >
        {(entries) => (
          <ul className="divide-y rounded-lg border bg-card" aria-label="Departures">
            {entries.map((entry) => (
              <li key={entry.id} className="flex items-center gap-3 px-3 py-2 text-sm">
                <span className="figure w-12 font-semibold">
                  {entry.departure_time.slice(0, 5)}
                </span>
                <span className="flex-1 text-muted-foreground">
                  {formatDays(entry.days_of_week as Day[])}
                </span>
                <span className="figure">{formatMoney(entry.fare_amount)}</span>
              </li>
            ))}
          </ul>
        )}
      </QueryState>
      {manages ? (
        <>
          <AddEntry routeId={routeId} />
          <p className="text-xs text-muted-foreground">
            Departures can be added here but not changed or removed: the API has no way to do that
            yet. Retiring the route retires its timetable.
          </p>
        </>
      ) : null}
    </div>
  )
}
