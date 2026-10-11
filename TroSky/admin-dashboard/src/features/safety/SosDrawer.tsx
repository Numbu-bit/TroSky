import { Eye, Phone, PhoneCall, ShieldCheck } from 'lucide-react'
import { lazy, Suspense, useId, useState, type ReactNode } from 'react'
import { Link } from 'react-router'
import { toast } from 'sonner'

import { errorMessage } from '@/api/errors'
import type { Schemas } from '@/api/types'
import { ConfirmDialog } from '@/components/confirm/ConfirmDialog'
import { ErrorState } from '@/components/feedback/states'
import { StatusBadge } from '@/components/status/StatusBadge'
import { Button } from '@/components/ui/button'
import { Checkbox } from '@/components/ui/checkbox'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetHeader,
  SheetTitle,
} from '@/components/ui/sheet'
import { Skeleton } from '@/components/ui/skeleton'
import { Textarea } from '@/components/ui/textarea'
import { formatDateTime, formatPhone, formatRelative, humanize } from '@/lib/format'
import { useNow } from '@/lib/use-now'

import { useAcknowledgeSos, useLogEscalation, useResolveSos, useSosDetail } from './api'
import { ESCALATION_TYPES, SOS_STATUS } from './status'

const SosMap = lazy(() => import('./SosMap'))

function Block({ title, children }: { title: string; children: ReactNode }) {
  return (
    <section className="space-y-2 border-t px-4 py-3" aria-label={title}>
      <h3 className="text-sm font-semibold">{title}</h3>
      {children}
    </section>
  )
}

function Contact({
  label,
  name,
  phone,
}: {
  label: string
  name: string | null
  phone: string | null
}) {
  return (
    <div className="flex items-center justify-between gap-3 text-sm">
      <div className="min-w-0">
        <p className="text-xs text-muted-foreground">{label}</p>
        <p className="truncate font-medium">{name ?? 'Unknown'}</p>
      </div>
      {phone ? (
        <Button variant="outline" size="sm" asChild>
          <a
            href={`tel:${phone}`}
            aria-label={`Call ${label.toLowerCase()} on ${formatPhone(phone)}`}
          >
            <Phone aria-hidden /> {formatPhone(phone)}
          </a>
        </Button>
      ) : null}
    </div>
  )
}

function EscalationForm({ alert }: { alert: Schemas['AdminSosAlertDetailResponse'] }) {
  const log = useLogEscalation()
  const [type, setType] = useState<Schemas['EscalationContactType']>('police')
  const [name, setName] = useState('')
  const [phone, setPhone] = useState('')
  const [notes, setNotes] = useState('')
  const ids = { type: useId(), name: useId(), phone: useId(), notes: useId() }

  async function submit(event: React.FormEvent) {
    event.preventDefault()
    try {
      await log.mutateAsync({
        id: alert.id,
        contact_type: type,
        contact_name: name || null,
        phone_number: phone || null,
        notes: notes || null,
      })
      toast.success('Escalation logged.')
      setName('')
      setPhone('')
      setNotes('')
    } catch (error) {
      toast.error(errorMessage(error))
    }
  }

  return (
    <form
      className="space-y-2 rounded-md border p-3"
      onSubmit={submit}
      aria-label="Log an escalation"
    >
      <div className="grid gap-2 sm:grid-cols-2">
        <div className="grid gap-1">
          <Label htmlFor={ids.type}>Who was contacted</Label>
          <Select value={type} onValueChange={(value) => setType(value as typeof type)}>
            <SelectTrigger id={ids.type}>
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              {ESCALATION_TYPES.map((option) => (
                <SelectItem key={option.value} value={option.value}>
                  {option.label}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
        <div className="grid gap-1">
          <Label htmlFor={ids.name}>Name (optional)</Label>
          <Input
            id={ids.name}
            value={name}
            maxLength={200}
            onChange={(event) => setName(event.target.value)}
          />
        </div>
        <div className="grid gap-1">
          <Label htmlFor={ids.phone}>Phone (optional)</Label>
          <Input
            id={ids.phone}
            value={phone}
            maxLength={20}
            inputMode="tel"
            onChange={(event) => setPhone(event.target.value)}
          />
        </div>
      </div>
      <div className="grid gap-1">
        <Label htmlFor={ids.notes}>What was agreed (optional)</Label>
        <Textarea
          id={ids.notes}
          value={notes}
          maxLength={1000}
          onChange={(event) => setNotes(event.target.value)}
        />
      </div>
      <Button type="submit" size="sm" disabled={log.isPending}>
        <PhoneCall aria-hidden /> Log escalation
      </Button>
    </form>
  )
}

/** One SOS: who, where, the bus, who has been called, and what to do next. */
export function SosDrawer({ alertId, onClose }: { alertId: string | null; onClose: () => void }) {
  const detail = useSosDetail(alertId)
  const acknowledge = useAcknowledgeSos()
  const resolve = useResolveSos()
  const [resolving, setResolving] = useState(false)
  const [falseAlarm, setFalseAlarm] = useState(false)
  const now = useNow(5000)
  const falseAlarmId = useId()
  const alert = detail.data
  const status = alert ? SOS_STATUS[alert.status] : null
  const open = alert && (alert.status === 'active' || alert.status === 'acknowledged')

  return (
    <Sheet open={Boolean(alertId)} onOpenChange={(next) => !next && onClose()}>
      <SheetContent className="w-full overflow-y-auto sm:max-w-lg">
        <SheetHeader>
          <SheetTitle>
            SOS{alert?.triggered_by_name ? ` from ${alert.triggered_by_name}` : ''}
          </SheetTitle>
          <SheetDescription asChild>
            <div className="flex flex-wrap items-center gap-2">
              {status ? (
                <StatusBadge tone={status.tone} label={status.label} icon={status.icon} />
              ) : null}
              {alert ? (
                <span>
                  Raised {formatRelative(alert.created_at, now)} ·{' '}
                  {formatDateTime(alert.created_at)}
                </span>
              ) : null}
            </div>
          </SheetDescription>
        </SheetHeader>
        {detail.isPending ? (
          <div className="space-y-3 p-4">
            <Skeleton className="h-56" />
            <Skeleton className="h-16" />
            <Skeleton className="h-24" />
          </div>
        ) : detail.isError || !alert ? (
          <div className="p-4">
            <ErrorState error={detail.error} onRetry={() => void detail.refetch()} />
          </div>
        ) : (
          <>
            {open ? (
              <div className="flex flex-wrap gap-2 px-4">
                {alert.status === 'active' ? (
                  <Button
                    disabled={acknowledge.isPending}
                    onClick={async () => {
                      try {
                        await acknowledge.mutateAsync(alert.id)
                        toast.success(
                          'Acknowledged. The rider’s app shows that help is on the way.',
                        )
                      } catch (error) {
                        toast.error(errorMessage(error))
                      }
                    }}
                  >
                    <Eye aria-hidden /> Acknowledge
                  </Button>
                ) : null}
                <Button variant="outline" onClick={() => setResolving(true)}>
                  <ShieldCheck aria-hidden /> Resolve
                </Button>
              </div>
            ) : null}
            <Suspense fallback={<Skeleton className="m-4 h-56" />}>
              <div className="px-4 pt-3">
                <SosMap
                  alert={
                    alert.latitude !== null && alert.longitude !== null
                      ? { latitude: alert.latitude, longitude: alert.longitude }
                      : null
                  }
                  bus={alert.trip?.last_position ?? null}
                />
              </div>
            </Suspense>
            <Block title="People">
              <Contact
                label="Raised by"
                name={alert.triggered_by_name}
                phone={alert.triggered_by_phone || null}
              />
              {alert.trip ? (
                <>
                  <Contact
                    label="Driver"
                    name={alert.trip.driver_name}
                    phone={alert.trip.driver_phone}
                  />
                  <Contact
                    label="Fleet owner"
                    name={alert.trip.fleet_owner_name}
                    phone={alert.trip.fleet_owner_phone}
                  />
                </>
              ) : (
                <p className="text-sm text-muted-foreground">Raised outside a trip.</p>
              )}
            </Block>
            {alert.trip ? (
              <Block title="The trip">
                <p className="text-sm">
                  <Link to={`/live?trip=${alert.trip.trip_id}`} className="link-inline font-medium">
                    {alert.trip.route_name}
                  </Link>{' '}
                  · {humanize(alert.trip.status)} ·{' '}
                  {alert.trip.vehicle_registration_number ?? 'no vehicle'}
                </p>
                {alert.trip.last_position ? (
                  <p className="text-xs text-muted-foreground">
                    Bus last reported {formatRelative(alert.trip.last_position.recorded_at, now)} at{' '}
                    {alert.trip.last_position.latitude.toFixed(5)},{' '}
                    {alert.trip.last_position.longitude.toFixed(5)}
                  </p>
                ) : null}
              </Block>
            ) : null}
            <Block title="Escalations">
              {alert.escalations.length ? (
                <ol className="space-y-2">
                  {alert.escalations.map((escalation) => (
                    <li key={escalation.id} className="rounded-md bg-muted/60 p-2 text-sm">
                      <p className="font-medium">
                        {ESCALATION_TYPES.find((type) => type.value === escalation.contact_type)
                          ?.label ?? humanize(escalation.contact_type)}
                        {escalation.contact_name ? ` · ${escalation.contact_name}` : ''}
                        {escalation.phone_number
                          ? ` · ${formatPhone(escalation.phone_number)}`
                          : ''}
                      </p>
                      <p className="text-xs text-muted-foreground">
                        {formatDateTime(escalation.contacted_at)} · logged by{' '}
                        {escalation.logged_by_name ?? 'an admin'}
                      </p>
                      {escalation.notes ? <p className="mt-1">{escalation.notes}</p> : null}
                    </li>
                  ))}
                </ol>
              ) : (
                <p className="text-sm text-muted-foreground">Nobody has been called yet.</p>
              )}
              <div className="flex flex-wrap gap-2">
                {alert.escalation_contacts.map((contact) => (
                  <Button key={contact.phone_number} variant="outline" size="sm" asChild>
                    <a href={`tel:${contact.phone_number}`}>
                      <Phone aria-hidden /> {contact.name} ({contact.phone_number})
                    </a>
                  </Button>
                ))}
              </div>
              {open ? <EscalationForm alert={alert} /> : null}
            </Block>
            {alert.resolution_notes ? (
              <Block title="Resolution">
                <p className="text-sm">{alert.resolution_notes}</p>
                <p className="text-xs text-muted-foreground">{formatDateTime(alert.resolved_at)}</p>
              </Block>
            ) : null}
            <ConfirmDialog
              open={resolving}
              onOpenChange={(next) => {
                setResolving(next)
                if (!next) setFalseAlarm(false)
              }}
              title="Resolve this SOS?"
              description="Say what happened. It is kept with the alert and the rider is told it is closed."
              confirmLabel={falseAlarm ? 'Close as false alarm' : 'Resolve'}
              reason={{
                label: 'Resolution note',
                required: true,
                placeholder: 'e.g. Police met the bus at Legon; the rider is safe.',
              }}
              details={
                <div className="flex items-center gap-2">
                  <Checkbox
                    id={falseAlarmId}
                    checked={falseAlarm}
                    onCheckedChange={(checked) => setFalseAlarm(checked === true)}
                  />
                  <Label htmlFor={falseAlarmId} className="font-normal">
                    It was a false alarm
                  </Label>
                </div>
              }
              onConfirm={async (notes) => {
                await resolve.mutateAsync({ id: alert.id, notes, falseAlarm })
                toast.success(falseAlarm ? 'Closed as a false alarm.' : 'SOS resolved.')
              }}
            />
          </>
        )}
      </SheetContent>
    </Sheet>
  )
}
