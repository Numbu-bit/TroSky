import { zodResolver } from '@hookform/resolvers/zod'
import { lazy, Suspense, useId } from 'react'
import { useForm, useWatch } from 'react-hook-form'
import { toast } from 'sonner'
import { z } from 'zod'

import { errorMessage, fieldErrors, isApiError } from '@/api/errors'
import type { Schemas } from '@/api/types'
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
import { coordinate, optionalText } from '@/lib/validation'

import { useCreateStop, useUpdateStop } from './api'

const PinMap = lazy(() => import('./PinMap'))

type Stop = Schemas['StopResponse']

const stopSchema = z.object({
  name: z.string().trim().min(2, 'At least 2 characters.').max(200, 'At most 200 characters.'),
  code: optionalText(20),
  address: optionalText(500),
  city: optionalText(100),
  region: optionalText(100),
  latitude: coordinate('latitude', 90),
  longitude: coordinate('longitude', 180),
})

type StopInput = z.input<typeof stopSchema>
type StopValues = z.output<typeof stopSchema>
const FIELDS = ['name', 'code', 'address', 'city', 'region', 'latitude', 'longitude'] as const

function StopForm({ stop, onDone }: { stop: Stop | null; onDone: () => void }) {
  const create = useCreateStop()
  const update = useUpdateStop()
  const id = useId()
  const form = useForm<StopInput, unknown, StopValues>({
    resolver: zodResolver(stopSchema),
    defaultValues: {
      name: stop?.name ?? '',
      code: stop?.code ?? '',
      address: stop?.address ?? '',
      city: stop?.city ?? '',
      region: stop?.region ?? '',
      latitude: stop ? String(stop.latitude) : '',
      longitude: stop ? String(stop.longitude) : '',
    },
  })
  const { errors, isSubmitting } = form.formState
  const [latitude, longitude] = useWatch({ control: form.control, name: ['latitude', 'longitude'] })
  const pin =
    latitude && longitude && Number.isFinite(Number(latitude)) && Number.isFinite(Number(longitude))
      ? { latitude: Number(latitude), longitude: Number(longitude) }
      : null

  const submit = form.handleSubmit(async (values) => {
    const body = {
      ...values,
      latitude: Number(values.latitude),
      longitude: Number(values.longitude),
    }
    try {
      if (stop) await update.mutateAsync({ id: stop.id, ...body })
      else await create.mutateAsync(body)
      toast.success(stop ? 'Stop saved.' : `${values.name} added.`)
      onDone()
    } catch (error) {
      if (isApiError(error, 409)) {
        form.setError('code', { message: errorMessage(error) })
        return
      }
      const fields = fieldErrors(error)
      const known = FIELDS.filter((field) => fields[field])
      for (const field of known) form.setError(field, { message: fields[field] })
      if (!known.length) toast.error(errorMessage(error))
    }
  })

  const field = (name: (typeof FIELDS)[number], label: string, extra: object = {}) => {
    const message = errors[name]?.message
    return (
      <div className="grid gap-1.5">
        <Label htmlFor={`${id}-${name}`}>{label}</Label>
        <Input
          id={`${id}-${name}`}
          aria-invalid={message ? true : undefined}
          aria-describedby={message ? `${id}-${name}-error` : undefined}
          {...extra}
          {...form.register(name)}
        />
        {message ? (
          <p id={`${id}-${name}-error`} className="text-sm text-danger-text">
            {message}
          </p>
        ) : null}
      </div>
    )
  }

  return (
    <>
      <form id={`${id}-form`} className="space-y-4" onSubmit={submit} noValidate>
        <div className="grid gap-3 sm:grid-cols-[2fr_1fr]">
          {field('name', 'Name', { placeholder: 'e.g. Madina Zongo Junction' })}
          {field('code', 'Code (optional)', { placeholder: 'MDZ' })}
        </div>
        <Suspense fallback={<Skeleton className="h-60" />}>
          <PinMap
            value={pin}
            onChange={(next) => {
              form.setValue('latitude', String(next.latitude), { shouldValidate: true })
              form.setValue('longitude', String(next.longitude), { shouldValidate: true })
            }}
          />
        </Suspense>
        <div className="grid grid-cols-2 gap-3">
          {field('latitude', 'Latitude', { inputMode: 'decimal', placeholder: '5.6037' })}
          {field('longitude', 'Longitude', { inputMode: 'decimal', placeholder: '-0.1870' })}
        </div>
        {field('address', 'Address or landmark (optional)')}
        <div className="grid grid-cols-2 gap-3">
          {field('city', 'City (optional)', { placeholder: 'Accra' })}
          {field('region', 'Region (optional)', { placeholder: 'Greater Accra' })}
        </div>
      </form>
      <DialogFooter>
        <Button type="submit" form={`${id}-form`} disabled={isSubmitting}>
          {stop ? 'Save stop' : 'Add stop'}
        </Button>
      </DialogFooter>
    </>
  )
}

/** Add a stop, or change one: name, code, and where it is (click the map). */
export function StopDialog({
  open,
  stop,
  onOpenChange,
}: {
  open: boolean
  stop: Stop | null
  onOpenChange: (open: boolean) => void
}) {
  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-h-[92vh] overflow-y-auto sm:max-w-xl">
        <DialogHeader>
          <DialogTitle>{stop ? `Edit ${stop.name}` : 'New stop'}</DialogTitle>
          <DialogDescription>
            {stop
              ? 'Moving a stop re-measures every active route that uses it.'
              : 'Click the map where buses stop, or type the coordinates.'}
          </DialogDescription>
        </DialogHeader>
        {open ? (
          <StopForm key={stop?.id ?? 'new'} stop={stop} onDone={() => onOpenChange(false)} />
        ) : null}
      </DialogContent>
    </Dialog>
  )
}
