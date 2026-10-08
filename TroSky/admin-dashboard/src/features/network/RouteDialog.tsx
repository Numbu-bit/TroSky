import { zodResolver } from '@hookform/resolvers/zod'
import { ArrowDown, ArrowUp, Plus, X } from 'lucide-react'
import { useId, useState } from 'react'
import { Controller, useFieldArray, useForm } from 'react-hook-form'
import { useNavigate } from 'react-router'
import { toast } from 'sonner'
import { z } from 'zod'

import { errorMessage, fieldErrors, isApiError } from '@/api/errors'
import { StopPicker } from '@/components/pickers/pickers'
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

import { useCreateRoute } from './api'

const stopRef = z.object({ id: z.string(), name: z.string() })

const optionalNumber = (check: (value: number) => boolean, message: string) =>
  z
    .string()
    .trim()
    .refine((value) => !value || (Number.isFinite(Number(value)) && check(Number(value))), message)

const routeSchema = z
  .object({
    name: z.string().trim().min(2, 'At least 2 characters.').max(200, 'At most 200 characters.'),
    origin: stopRef.nullable().refine(Boolean, 'Choose where the route starts.'),
    destination: stopRef.nullable().refine(Boolean, 'Choose where the route ends.'),
    via: z.array(stopRef),
    distance: optionalNumber(
      (value) => value > 0 && value < 1_000_000 && /^\d+(\.\d{1,2})?$/.test(String(value)),
      'Kilometres above 0, at most two decimals.',
    ),
    minutes: optionalNumber(
      (value) => Number.isInteger(value) && value > 0,
      'Whole minutes above 0.',
    ),
  })
  .superRefine((values, context) => {
    const ids = [values.origin?.id, ...values.via.map((stop) => stop.id), values.destination?.id]
    const seen = new Set<string>()
    ids.forEach((id, position) => {
      if (!id) return
      if (seen.has(id)) {
        context.addIssue({
          code: 'custom',
          message: 'A route can’t visit the same stop twice.',
          path:
            position === 0 ? ['origin'] : position === ids.length - 1 ? ['destination'] : ['via'],
        })
      }
      seen.add(id)
    })
  })

type RouteInput = z.input<typeof routeSchema>

function FieldError({ id, message }: { id: string; message?: string }) {
  return message ? (
    <p id={id} className="text-sm text-danger-text">
      {message}
    </p>
  ) : null
}

/** A new route: its two ends, the stops between in order, and its length. */
export function RouteDialog() {
  const [open, setOpen] = useState(false)
  const navigate = useNavigate()
  const create = useCreateRoute()
  const id = useId()
  const form = useForm<RouteInput>({
    resolver: zodResolver(routeSchema),
    defaultValues: {
      name: '',
      origin: null,
      destination: null,
      via: [],
      distance: '',
      minutes: '',
    },
  })
  const via = useFieldArray({ control: form.control, name: 'via', keyName: 'key' })
  const { errors, isSubmitting } = form.formState

  const submit = form.handleSubmit(async (values) => {
    try {
      const route = await create.mutateAsync({
        name: values.name.trim(),
        origin_stop_id: values.origin!.id,
        destination_stop_id: values.destination!.id,
        intermediate_stop_ids: values.via.map((stop) => stop.id),
        distance_km: values.distance ? values.distance : null,
        estimated_duration_minutes: values.minutes ? Number(values.minutes) : null,
      })
      toast.success(`${route.name} created. Add its timetable next.`)
      setOpen(false)
      form.reset()
      navigate(`/network/routes/${route.id}`)
    } catch (error) {
      if (isApiError(error, 409)) {
        form.setError('name', { message: errorMessage(error) })
        return
      }
      const fields = fieldErrors(error)
      if (fields.name) form.setError('name', { message: fields.name })
      else toast.error(errorMessage(error))
    }
  })

  const [adding, setAdding] = useState(false)

  return (
    <Dialog
      open={open}
      onOpenChange={(next) => {
        setOpen(next)
        if (!next) form.reset()
      }}
    >
      <DialogTrigger asChild>
        <Button>
          <Plus aria-hidden /> New route
        </Button>
      </DialogTrigger>
      <DialogContent className="max-h-[92vh] overflow-y-auto sm:max-w-lg">
        <DialogHeader>
          <DialogTitle>New route</DialogTitle>
          <DialogDescription>
            Pick its stops in the order buses call at them. Leave the length and time blank to have
            them estimated.
          </DialogDescription>
        </DialogHeader>
        <form id={`${id}-form`} className="space-y-4" onSubmit={submit} noValidate>
          <div className="grid gap-1.5">
            <Label htmlFor={`${id}-name`}>Name</Label>
            <Input
              id={`${id}-name`}
              placeholder="e.g. Madina – Circle"
              aria-invalid={errors.name ? true : undefined}
              aria-describedby={errors.name ? `${id}-name-error` : undefined}
              {...form.register('name')}
            />
            <FieldError id={`${id}-name-error`} message={errors.name?.message} />
          </div>
          <div className="grid gap-1.5">
            <Label htmlFor={`${id}-origin`}>Starts at</Label>
            <Controller
              control={form.control}
              name="origin"
              render={({ field }) => (
                <StopPicker
                  id={`${id}-origin`}
                  value={field.value?.id ?? null}
                  selectedLabel={field.value?.name}
                  onChange={(option) =>
                    field.onChange(option ? { id: option.value, name: option.label } : null)
                  }
                />
              )}
            />
            <FieldError id={`${id}-origin-error`} message={errors.origin?.message} />
          </div>
          <fieldset className="space-y-2">
            <legend className="text-sm font-medium">Stops in between, in order</legend>
            {via.fields.length ? (
              <ol className="space-y-1">
                {via.fields.map((stop, position) => (
                  <li
                    key={stop.key}
                    className="flex items-center gap-2 rounded-md border bg-muted/40 px-2 py-1 text-sm"
                  >
                    <span className="figure w-5 text-muted-foreground">{position + 2}.</span>
                    <span className="min-w-0 flex-1 truncate">{stop.name}</span>
                    <Button
                      type="button"
                      size="icon"
                      variant="ghost"
                      className="size-7"
                      disabled={position === 0}
                      onClick={() => via.move(position, position - 1)}
                      aria-label={`Move ${stop.name} earlier`}
                    >
                      <ArrowUp aria-hidden />
                    </Button>
                    <Button
                      type="button"
                      size="icon"
                      variant="ghost"
                      className="size-7"
                      disabled={position === via.fields.length - 1}
                      onClick={() => via.move(position, position + 1)}
                      aria-label={`Move ${stop.name} later`}
                    >
                      <ArrowDown aria-hidden />
                    </Button>
                    <Button
                      type="button"
                      size="icon"
                      variant="ghost"
                      className="size-7"
                      onClick={() => via.remove(position)}
                      aria-label={`Take ${stop.name} off the route`}
                    >
                      <X aria-hidden />
                    </Button>
                  </li>
                ))}
              </ol>
            ) : (
              <p className="text-sm text-muted-foreground">None: buses run straight through.</p>
            )}
            {adding ? (
              <>
                <Label htmlFor={`${id}-via`} className="sr-only">
                  Next stop in between
                </Label>
                <StopPicker
                  id={`${id}-via`}
                  value={null}
                  placeholder="Choose the next stop"
                  onChange={(option) => {
                    if (option) via.append({ id: option.value, name: option.label })
                    setAdding(false)
                  }}
                />
              </>
            ) : (
              <Button type="button" size="sm" variant="outline" onClick={() => setAdding(true)}>
                <Plus aria-hidden /> Add a stop in between
              </Button>
            )}
            <FieldError
              id={`${id}-via-error`}
              message={errors.via?.message ?? errors.via?.root?.message}
            />
          </fieldset>
          <div className="grid gap-1.5">
            <Label htmlFor={`${id}-destination`}>Ends at</Label>
            <Controller
              control={form.control}
              name="destination"
              render={({ field }) => (
                <StopPicker
                  id={`${id}-destination`}
                  value={field.value?.id ?? null}
                  selectedLabel={field.value?.name}
                  onChange={(option) =>
                    field.onChange(option ? { id: option.value, name: option.label } : null)
                  }
                />
              )}
            />
            <FieldError id={`${id}-destination-error`} message={errors.destination?.message} />
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div className="grid gap-1.5">
              <Label htmlFor={`${id}-distance`}>Length in km (optional)</Label>
              <Input
                id={`${id}-distance`}
                inputMode="decimal"
                aria-invalid={errors.distance ? true : undefined}
                aria-describedby={errors.distance ? `${id}-distance-error` : undefined}
                {...form.register('distance')}
              />
              <FieldError id={`${id}-distance-error`} message={errors.distance?.message} />
            </div>
            <div className="grid gap-1.5">
              <Label htmlFor={`${id}-minutes`}>Time in minutes (optional)</Label>
              <Input
                id={`${id}-minutes`}
                inputMode="numeric"
                aria-invalid={errors.minutes ? true : undefined}
                aria-describedby={errors.minutes ? `${id}-minutes-error` : undefined}
                {...form.register('minutes')}
              />
              <FieldError id={`${id}-minutes-error`} message={errors.minutes?.message} />
            </div>
          </div>
        </form>
        <DialogFooter>
          <Button type="submit" form={`${id}-form`} disabled={isSubmitting}>
            Create route
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
