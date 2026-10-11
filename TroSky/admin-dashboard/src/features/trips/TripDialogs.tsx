import { zodResolver } from '@hookform/resolvers/zod'
import { CalendarClock, CalendarPlus } from 'lucide-react'
import { useId, useState } from 'react'
import { Controller, useForm } from 'react-hook-form'
import { useNavigate } from 'react-router'
import { toast } from 'sonner'
import { z } from 'zod'

import { errorMessage } from '@/api/errors'
import { Button } from '@/components/ui/button'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from '@/components/ui/dialog'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import { useRoutes, useSchedules } from '@/features/shared/reference'
import { formatDays } from '@/features/network/days'
import { accraDateKey, formatMoney } from '@/lib/format'

import { cedis } from '@/lib/validation'

import { useCreateTrip, useCreateTripFromSchedule } from './api'

function FieldError({ id, message }: { id: string; message?: string }) {
  return message ? (
    <p id={id} className="text-sm text-danger-text">
      {message}
    </p>
  ) : null
}

const tripSchema = z.object({
  route_id: z.string().min(1, 'Choose a route.'),
  date: z.string().min(1, 'Choose the day.'),
  time: z.string().min(1, 'Choose the departure time.'),
  fare: cedis,
})

/** A one-off trip on a route: drivers and vehicles are assigned on its page. */
export function CreateTripDialog() {
  const [open, setOpen] = useState(false)
  const navigate = useNavigate()
  const routes = useRoutes()
  const create = useCreateTrip()
  const ids = { route: useId(), date: useId(), time: useId(), fare: useId() }
  const form = useForm<z.infer<typeof tripSchema>>({
    resolver: zodResolver(tripSchema),
    defaultValues: { route_id: '', date: accraDateKey(), time: '', fare: '' },
  })
  const { errors, isSubmitting } = form.formState

  const submit = form.handleSubmit(async (values) => {
    // Accra is UTC+0 all year: the local time is the UTC time.
    const departure = `${values.date}T${values.time}:00Z`
    const minutes = routes.data?.items.find(
      (route) => route.id === values.route_id,
    )?.estimated_duration_minutes
    try {
      const trip = await create.mutateAsync({
        route_id: values.route_id,
        scheduled_departure_at: departure,
        scheduled_arrival_at: minutes
          ? new Date(Date.parse(departure) + minutes * 60_000).toISOString()
          : null,
        fare_amount: values.fare,
      })
      toast.success('Trip created. Assign a driver and a vehicle next.')
      setOpen(false)
      form.reset()
      navigate(`/trips/${trip.id}`)
    } catch (error) {
      toast.error(errorMessage(error))
    }
  })

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button>
          <CalendarPlus aria-hidden /> New trip
        </Button>
      </DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>New trip</DialogTitle>
          <DialogDescription>
            A one-off trip. Times are Accra time; the arrival is estimated from the route.
          </DialogDescription>
        </DialogHeader>
        <form className="space-y-4" onSubmit={submit} noValidate id="new-trip">
          <div className="grid gap-1.5">
            <Label htmlFor={ids.route}>Route</Label>
            <Controller
              control={form.control}
              name="route_id"
              render={({ field }) => (
                <Select value={field.value} onValueChange={field.onChange}>
                  <SelectTrigger
                    id={ids.route}
                    aria-invalid={errors.route_id ? true : undefined}
                    aria-describedby={errors.route_id ? `${ids.route}-error` : undefined}
                  >
                    <SelectValue
                      placeholder={routes.isPending ? 'Loading routes…' : 'Choose a route'}
                    />
                  </SelectTrigger>
                  <SelectContent>
                    {(routes.data?.items ?? []).map((route) => (
                      <SelectItem key={route.id} value={route.id}>
                        {route.name}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              )}
            />
            <FieldError id={`${ids.route}-error`} message={errors.route_id?.message} />
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div className="grid gap-1.5">
              <Label htmlFor={ids.date}>Day</Label>
              <Input
                id={ids.date}
                type="date"
                min={accraDateKey()}
                aria-invalid={errors.date ? true : undefined}
                aria-describedby={errors.date ? `${ids.date}-error` : undefined}
                {...form.register('date')}
              />
              <FieldError id={`${ids.date}-error`} message={errors.date?.message} />
            </div>
            <div className="grid gap-1.5">
              <Label htmlFor={ids.time}>Departure</Label>
              <Input
                id={ids.time}
                type="time"
                aria-invalid={errors.time ? true : undefined}
                aria-describedby={errors.time ? `${ids.time}-error` : undefined}
                {...form.register('time')}
              />
              <FieldError id={`${ids.time}-error`} message={errors.time?.message} />
            </div>
          </div>
          <div className="grid gap-1.5">
            <Label htmlFor={ids.fare}>Fare per seat, whole route (GH₵)</Label>
            <Input
              id={ids.fare}
              inputMode="decimal"
              placeholder="8.00"
              aria-invalid={errors.fare ? true : undefined}
              aria-describedby={errors.fare ? `${ids.fare}-error` : undefined}
              {...form.register('fare')}
            />
            <FieldError id={`${ids.fare}-error`} message={errors.fare?.message} />
          </div>
        </form>
        <DialogFooter>
          <Button type="submit" form="new-trip" disabled={isSubmitting}>
            Create trip
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

/** A trip from a timetable entry: its time and fare come from the entry. */
export function TripFromTimetableDialog() {
  const [open, setOpen] = useState(false)
  const [routeId, setRouteId] = useState('')
  const [scheduleId, setScheduleId] = useState('')
  const [date, setDate] = useState(accraDateKey())
  const navigate = useNavigate()
  const routes = useRoutes()
  const schedules = useSchedules(routeId || null)
  const create = useCreateTripFromSchedule()
  const ids = { route: useId(), schedule: useId(), date: useId() }

  async function submit(event: React.FormEvent) {
    event.preventDefault()
    if (!scheduleId || !date) {
      toast.error('Choose a timetable entry and a day.')
      return
    }
    try {
      const trip = await create.mutateAsync({ schedule_id: scheduleId, travel_date: date })
      toast.success('Trip created from the timetable. Assign a driver and a vehicle next.')
      setOpen(false)
      navigate(`/trips/${trip.id}`)
    } catch (error) {
      toast.error(errorMessage(error))
    }
  }

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button variant="outline">
          <CalendarClock aria-hidden /> From timetable
        </Button>
      </DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Trip from the timetable</DialogTitle>
          <DialogDescription>The departure time and fare come from the entry.</DialogDescription>
        </DialogHeader>
        <form className="space-y-4" onSubmit={submit} id="trip-from-timetable">
          <div className="grid gap-1.5">
            <Label htmlFor={ids.route}>Route</Label>
            <Select
              value={routeId}
              onValueChange={(value) => {
                setRouteId(value)
                setScheduleId('')
              }}
            >
              <SelectTrigger id={ids.route}>
                <SelectValue placeholder="Choose a route" />
              </SelectTrigger>
              <SelectContent>
                {(routes.data?.items ?? []).map((route) => (
                  <SelectItem key={route.id} value={route.id}>
                    {route.name}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
          <div className="grid gap-1.5">
            <Label htmlFor={ids.schedule}>Timetable entry</Label>
            <Select value={scheduleId} onValueChange={setScheduleId} disabled={!routeId}>
              <SelectTrigger id={ids.schedule}>
                <SelectValue
                  placeholder={
                    !routeId
                      ? 'Choose a route first'
                      : schedules.isPending
                        ? 'Loading the timetable…'
                        : schedules.data?.length
                          ? 'Choose a departure'
                          : 'This route has no timetable'
                  }
                />
              </SelectTrigger>
              <SelectContent>
                {(schedules.data ?? []).map((schedule) => (
                  <SelectItem key={schedule.id} value={schedule.id}>
                    {schedule.departure_time.slice(0, 5)} · {formatMoney(schedule.fare_amount)} ·{' '}
                    {formatDays(schedule.days_of_week)}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
          <div className="grid gap-1.5">
            <Label htmlFor={ids.date}>Day</Label>
            <Input
              id={ids.date}
              type="date"
              value={date}
              min={accraDateKey()}
              onChange={(event) => setDate(event.target.value)}
            />
          </div>
        </form>
        <DialogFooter>
          <Button
            type="submit"
            form="trip-from-timetable"
            disabled={create.isPending || !scheduleId}
          >
            Create trip
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
