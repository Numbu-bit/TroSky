import { zodResolver } from '@hookform/resolvers/zod'
import { Archive, ArrowLeft, ArrowRight, Bus, Pencil } from 'lucide-react'
import { lazy, Suspense, useId, useState } from 'react'
import { useForm } from 'react-hook-form'
import { Link, useNavigate, useParams } from 'react-router'
import { toast } from 'sonner'
import { z } from 'zod'

import { ApiError, errorMessage, fieldErrors, isApiError } from '@/api/errors'
import type { Schemas } from '@/api/types'
import { useSession } from '@/app/auth/auth-context'
import { ConfirmButton } from '@/components/confirm/ConfirmButton'
import { EmptyState, ErrorState, PageSkeleton } from '@/components/feedback/states'
import { PageHeader, Section } from '@/components/layout/PageHeader'
import { Button } from '@/components/ui/button'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Skeleton } from '@/components/ui/skeleton'
import { useRoute } from '@/features/shared/reference'
import { formatDate, formatMinutes, formatNumber } from '@/lib/format'

import { useRetireRoute, useUpdateRoute } from './api'
import { Timetable } from './Timetable'

const RouteMap = lazy(() => import('@/components/map/RouteMap'))

type RouteDetail = Schemas['RouteDetailResponse']

const editSchema = z.object({
  name: z.string().trim().min(2, 'At least 2 characters.').max(200, 'At most 200 characters.'),
  distance: z
    .string()
    .trim()
    .refine(
      (value) => !value || (/^\d{1,6}(\.\d{1,2})?$/.test(value) && Number(value) > 0),
      'Kilometres above 0, at most two decimals.',
    ),
  minutes: z
    .string()
    .trim()
    .refine(
      (value) => !value || (/^\d+$/.test(value) && Number(value) > 0),
      'Whole minutes above 0.',
    ),
})

type EditInput = z.input<typeof editSchema>

function EditRoute({ route, onDone }: { route: RouteDetail; onDone: () => void }) {
  const update = useUpdateRoute(route.id)
  const id = useId()
  const form = useForm<EditInput>({
    resolver: zodResolver(editSchema),
    defaultValues: {
      name: route.name,
      distance: route.distance_km ?? '',
      minutes: route.estimated_duration_minutes ? String(route.estimated_duration_minutes) : '',
    },
  })
  const { errors, isSubmitting } = form.formState

  const submit = form.handleSubmit(async (values) => {
    const changes: Schemas['RouteUpdateRequest'] = {}
    if (values.name.trim() !== route.name) changes.name = values.name.trim()
    if (values.distance && Number(values.distance) !== Number(route.distance_km)) {
      changes.distance_km = values.distance
    }
    if (values.minutes && Number(values.minutes) !== route.estimated_duration_minutes) {
      changes.estimated_duration_minutes = Number(values.minutes)
    }
    if (!Object.keys(changes).length) {
      onDone()
      return
    }
    try {
      await update.mutateAsync(changes)
      toast.success('Route saved.')
      onDone()
    } catch (error) {
      if (isApiError(error, 409)) {
        form.setError('name', { message: errorMessage(error) })
        return
      }
      const fields = fieldErrors(error)
      if (fields.name) form.setError('name', { message: fields.name })
      else if (fields.distance_km) form.setError('distance', { message: fields.distance_km })
      else toast.error(errorMessage(error))
    }
  })

  const input = (name: keyof EditInput, label: string, extra: object = {}) => (
    <div className="grid gap-1.5">
      <Label htmlFor={`${id}-${name}`}>{label}</Label>
      <Input
        id={`${id}-${name}`}
        aria-invalid={errors[name] ? true : undefined}
        aria-describedby={errors[name] ? `${id}-${name}-error` : undefined}
        {...extra}
        {...form.register(name)}
      />
      {errors[name] ? (
        <p id={`${id}-${name}-error`} className="text-sm text-danger-text">
          {errors[name].message}
        </p>
      ) : null}
    </div>
  )

  return (
    <>
      <form id={`${id}-form`} className="space-y-4" onSubmit={submit} noValidate>
        {input('name', 'Name')}
        <div className="grid grid-cols-2 gap-3">
          {input('distance', 'Length in km', { inputMode: 'decimal' })}
          {input('minutes', 'Time in minutes', { inputMode: 'numeric' })}
        </div>
      </form>
      <DialogFooter>
        <Button type="submit" form={`${id}-form`} disabled={isSubmitting}>
          Save route
        </Button>
      </DialogFooter>
    </>
  )
}

/** What to say when a route can't be retired: its trips still to run. */
function retireFailure(error: unknown): Error {
  if (isApiError(error, 409) && error instanceof ApiError) {
    const count = Number(error.details.unfinished_trips ?? 0)
    if (count) {
      return new Error(
        `${formatNumber(count)} trip${count === 1 ? ' is' : 's are'} still scheduled or under way on this route. Cancel or finish ${count === 1 ? 'it' : 'them'} first (Trips, filtered to this route).`,
      )
    }
  }
  return error instanceof Error ? error : new Error('Could not retire the route.')
}

/** One route: its stops in order on a map, its timetable, edit and retire. */
export function RoutePage() {
  const { routeId = '' } = useParams()
  const { can } = useSession()
  const navigate = useNavigate()
  const route = useRoute(routeId)
  const retire = useRetireRoute(routeId)
  const [editing, setEditing] = useState(false)
  const manages = can('routes:manage')

  if (route.isPending) return <PageSkeleton />
  if (route.isError || !route.data) {
    return (
      <>
        <BackLink />
        {isApiError(route.error, 404) ? (
          <EmptyState
            title="Route not found"
            description="It may have been retired. Retired routes stay in trip and booking history."
          />
        ) : (
          <ErrorState error={route.error} onRetry={() => void route.refetch()} />
        )}
      </>
    )
  }

  const data = route.data
  const first = data.stops[0]
  const last = data.stops.at(-1)

  return (
    <>
      <BackLink />
      <PageHeader
        title={data.name}
        description={
          <>
            {first?.name} <ArrowRight className="inline size-3" aria-label="to" /> {last?.name} ·{' '}
            {data.distance_km
              ? `${formatNumber(data.distance_km, { decimals: true })} km`
              : 'length not set'}{' '}
            ·{' '}
            {data.estimated_duration_minutes
              ? formatMinutes(data.estimated_duration_minutes)
              : 'time not set'}
          </>
        }
        actions={
          <>
            {can('trips:manage', 'trips:monitor_live') ? (
              <Button asChild variant="outline">
                <Link to={`/trips?route=${data.id}&date=all`}>
                  <Bus aria-hidden /> Trips
                </Link>
              </Button>
            ) : null}
            {manages ? (
              <>
                <Button variant="outline" onClick={() => setEditing(true)}>
                  <Pencil aria-hidden /> Edit
                </Button>
                <ConfirmButton
                  label="Retire route"
                  icon={Archive}
                  variant="outline"
                  title={`Retire ${data.name}?`}
                  description="It and its timetable stop taking new trips and bookings. Past trips keep it. Refused while trips on it are still to run."
                  confirmLabel="Retire route"
                  destructive
                  onConfirm={async () => {
                    try {
                      await retire.mutateAsync()
                    } catch (error) {
                      throw retireFailure(error)
                    }
                    toast.success(`${data.name} retired.`)
                    navigate('/network')
                  }}
                />
              </>
            ) : null}
          </>
        }
      />
      <div className="grid gap-6 lg:grid-cols-5">
        <div className="space-y-6 lg:col-span-3">
          <Suspense fallback={<Skeleton className="h-80" />}>
            <RouteMap label={`Map of ${data.name}`} stops={data.stops} className="h-80" />
          </Suspense>
          <Section title="Stops, in order">
            <ol className="divide-y rounded-lg border bg-card">
              {data.stops.map((stop, position) => (
                <li key={stop.id} className="flex items-center gap-3 px-3 py-2 text-sm">
                  <span className="figure flex size-6 shrink-0 items-center justify-center rounded-full bg-navy text-xs font-semibold text-white">
                    {position + 1}
                  </span>
                  <span className="min-w-0 flex-1">
                    <span className="font-medium">{stop.name}</span>
                    {stop.code ? (
                      <span className="text-muted-foreground"> · {stop.code}</span>
                    ) : null}
                  </span>
                  <span className="text-muted-foreground">{stop.city ?? ''}</span>
                </li>
              ))}
            </ol>
            <p className="text-xs text-muted-foreground">
              Created {formatDate(data.created_at)}. The API can’t change a route’s stops: to change
              them, create a new route and retire this one.
            </p>
          </Section>
        </div>
        <Section title="Timetable" className="lg:col-span-2">
          <Timetable routeId={data.id} manages={manages} />
        </Section>
      </div>
      <Dialog open={editing} onOpenChange={setEditing}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Edit {data.name}</DialogTitle>
            <DialogDescription>
              A new length or time re-measures the distance and time to each stop.
            </DialogDescription>
          </DialogHeader>
          {editing ? <EditRoute route={data} onDone={() => setEditing(false)} /> : null}
        </DialogContent>
      </Dialog>
    </>
  )
}

function BackLink() {
  return (
    <Button asChild variant="ghost" size="sm" className="mb-2 -ml-2">
      <Link to="/network">
        <ArrowLeft aria-hidden /> Routes
      </Link>
    </Button>
  )
}
