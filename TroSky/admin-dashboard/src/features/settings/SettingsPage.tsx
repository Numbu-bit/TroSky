import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Plus, RotateCcw, Save, X } from 'lucide-react'
import { useId, useState, type ReactNode } from 'react'
import { toast } from 'sonner'

import { api, unwrap } from '@/api/client'
import { fieldErrors } from '@/api/errors'
import type { Schemas } from '@/api/types'
import { useSession } from '@/app/auth/auth-context'
import { ConfirmDialog } from '@/components/confirm/ConfirmDialog'
import { QueryState, TableSkeleton } from '@/components/feedback/states'
import { PageHeader, Section } from '@/components/layout/PageHeader'
import { StatusBadge } from '@/components/status/StatusBadge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Switch } from '@/components/ui/switch'
import { formatDateTime } from '@/lib/format'

type Setting = Schemas['SettingResponse']
type Flag = Schemas['FeatureFlagResponse']
type Contact = { name: string; phone_number: string; role: string }

/** What each setting is, its unit and its limits (the backend's SettingsValues). */
const SETTINGS: Record<
  string,
  {
    title: string
    help: string
    kind: 'decimal' | 'whole' | 'sla' | 'contacts' | 'cities'
    unit?: string
    min?: number
    max?: number
  }
> = {
  platform_fee_flat_per_seat: {
    title: 'Platform fee per seat',
    help: 'Added to each seat booked.',
    kind: 'decimal',
    unit: 'GH₵',
    min: 0,
    max: 100,
  },
  platform_fee_percent: {
    title: 'Platform fee, share of the fare',
    help: 'On top of the flat fee.',
    kind: 'decimal',
    unit: '%',
    min: 0,
    max: 100,
  },
  driver_earnings_share_percent: {
    title: 'Drivers’ share of fares',
    help: 'What reaches the driver’s wallet for each completed trip.',
    kind: 'decimal',
    unit: '%',
    min: 0,
    max: 100,
  },
  reservation_hold_seconds: {
    title: 'Seat hold',
    help: 'How long a seat waits for payment (FR-007).',
    kind: 'whole',
    unit: 'seconds',
    min: 60,
    max: 3600,
  },
  live_update_interval_seconds: {
    title: 'Live position interval',
    help: 'How often a moving vehicle’s position is saved.',
    kind: 'whole',
    unit: 'seconds',
    min: 2,
    max: 60,
  },
  complaint_sla_hours: {
    title: 'Complaint resolution times',
    help: 'Hours to resolve a complaint, by priority.',
    kind: 'sla',
  },
  approval_target_hours: {
    title: 'Approval target',
    help: 'A driver or vehicle waiting longer for approval is overdue.',
    kind: 'whole',
    unit: 'hours',
    min: 1,
    max: 720,
  },
  sos_escalation_contacts: {
    title: 'SOS escalation contacts',
    help: 'Who admins call from an SOS, beyond the national numbers.',
    kind: 'contacts',
  },
  enabled_cities: {
    title: 'Cities TroSky runs in',
    help: 'Empty means no restriction.',
    kind: 'cities',
  },
}

const PRIORITIES = ['urgent', 'high', 'medium', 'low'] as const

function useSettingsQuery(enabled: boolean) {
  return useQuery({
    queryKey: ['settings'],
    queryFn: () => unwrap(api.GET('/api/v1/admin/settings')),
    enabled,
  })
}

function useFlagsQuery(enabled: boolean) {
  return useQuery({
    queryKey: ['feature-flags'],
    queryFn: () => unwrap(api.GET('/api/v1/admin/feature-flags')),
    enabled,
  })
}

/** Ask for a reason, then save (null puts the default back). */
function SaveDialog({
  open,
  onOpenChange,
  title,
  description,
  onSave,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
  title: string
  description: ReactNode
  onSave: (reason: string) => Promise<void>
}) {
  return (
    <ConfirmDialog
      open={open}
      onOpenChange={onOpenChange}
      title={title}
      description={description}
      confirmLabel="Save"
      reason={{ label: 'Why (for the audit log)', maxLength: 1000 }}
      onConfirm={onSave}
    />
  )
}

function SettingEditor({ setting }: { setting: Setting }) {
  const definition = SETTINGS[setting.key]
  const queryClient = useQueryClient()
  const id = useId()
  const [draft, setDraft] = useState<unknown>(setting.value)
  const [confirming, setConfirming] = useState<'save' | 'reset' | null>(null)
  const [problem, setProblem] = useState<string | null>(null)
  const save = useMutation({
    mutationFn: (body: Record<string, unknown>) =>
      unwrap(
        api.PATCH('/api/v1/admin/settings', { body: body as Schemas['SettingsUpdateRequest'] }),
      ),
    onSuccess: (settings) => queryClient.setQueryData(['settings'], settings),
  })
  if (!definition) return null
  const dirty = JSON.stringify(draft) !== JSON.stringify(setting.value)

  function check(): string | null {
    if (definition!.kind === 'decimal' || definition!.kind === 'whole') {
      const number = Number(draft)
      const pattern = definition!.kind === 'decimal' ? /^\d+(\.\d{1,2})?$/ : /^\d+$/
      if (!pattern.test(String(draft)) || number < definition!.min! || number > definition!.max!) {
        return `Enter ${definition!.kind === 'decimal' ? 'a number with at most 2 decimals' : 'a whole number'} from ${definition!.min} to ${definition!.max}.`
      }
    }
    if (definition!.kind === 'sla') {
      const hours = draft as Record<string, unknown>
      if (
        !PRIORITIES.every(
          (priority) =>
            /^\d+$/.test(String(hours[priority])) &&
            Number(hours[priority]) >= 1 &&
            Number(hours[priority]) <= 720,
        )
      ) {
        return 'Each priority needs 1-720 hours.'
      }
    }
    if (definition!.kind === 'contacts') {
      const contacts = draft as Contact[]
      if (
        contacts.some(
          (contact) =>
            !contact.name.trim() || !contact.role.trim() || contact.phone_number.trim().length < 5,
        )
      ) {
        return 'Each contact needs a name, a role and a phone number.'
      }
    }
    return null
  }

  function normalised(): unknown {
    if (definition!.kind === 'whole') return Number(draft)
    if (definition!.kind === 'decimal') return String(draft)
    if (definition!.kind === 'sla') {
      const hours = draft as Record<string, unknown>
      return Object.fromEntries(PRIORITIES.map((priority) => [priority, Number(hours[priority])]))
    }
    if (definition!.kind === 'cities')
      return (draft as string[]).map((city) => city.trim()).filter(Boolean)
    return (draft as Contact[]).map((contact) => ({
      name: contact.name.trim(),
      phone_number: contact.phone_number.trim(),
      role: contact.role.trim(),
    }))
  }

  async function persist(value: unknown, reason: string) {
    try {
      const settings = await save.mutateAsync({ [setting.key]: value, reason: reason || null })
      const saved = settings.find((item) => item.key === setting.key)
      setDraft(saved?.value ?? value)
      toast.success(
        value === null
          ? `${definition!.title}: back to the default.`
          : `${definition!.title} saved.`,
      )
    } catch (error) {
      const fields = fieldErrors(error)
      throw new Error(
        Object.values(fields)[0] ?? (error instanceof Error ? error.message : 'Could not save it.'),
      )
    }
  }

  let editor: ReactNode
  if (definition.kind === 'decimal' || definition.kind === 'whole') {
    editor = (
      <div className="flex items-center gap-2">
        <Input
          id={id}
          className="w-32"
          inputMode={definition.kind === 'decimal' ? 'decimal' : 'numeric'}
          value={String(draft)}
          onChange={(event) => setDraft(event.target.value)}
        />
        <span className="text-sm text-muted-foreground">{definition.unit}</span>
      </div>
    )
  } else if (definition.kind === 'sla') {
    const hours = draft as Record<string, unknown>
    editor = (
      <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
        {PRIORITIES.map((priority) => (
          <div key={priority} className="grid gap-1">
            <Label htmlFor={`${id}-${priority}`} className="text-xs capitalize">
              {priority}
            </Label>
            <Input
              id={`${id}-${priority}`}
              inputMode="numeric"
              value={String(hours[priority] ?? '')}
              onChange={(event) => setDraft({ ...hours, [priority]: event.target.value })}
            />
          </div>
        ))}
      </div>
    )
  } else if (definition.kind === 'cities') {
    const cities = draft as string[]
    editor = (
      <div className="space-y-2">
        <ul className="flex flex-wrap gap-2" aria-label="Cities">
          {cities.map((city, position) => (
            <li
              key={`${city}-${position}`}
              className="inline-flex items-center gap-1 rounded-full border bg-muted px-2 py-0.5 text-sm"
            >
              {city}
              <button
                type="button"
                aria-label={`Remove ${city}`}
                onClick={() => setDraft(cities.filter((_, index) => index !== position))}
              >
                <X className="size-3.5" aria-hidden />
              </button>
            </li>
          ))}
          {!cities.length ? (
            <li className="text-sm text-muted-foreground">Every city (no restriction)</li>
          ) : null}
        </ul>
        <form
          className="flex gap-2"
          onSubmit={(event) => {
            event.preventDefault()
            const input = new FormData(event.currentTarget).get('city')
            const city = String(input ?? '').trim()
            if (city && !cities.includes(city) && cities.length < 50) setDraft([...cities, city])
            event.currentTarget.reset()
          }}
        >
          <Label htmlFor={id} className="sr-only">
            Add a city
          </Label>
          <Input id={id} name="city" className="w-48" placeholder="e.g. Takoradi" />
          <Button type="submit" size="sm" variant="outline">
            <Plus aria-hidden /> Add
          </Button>
        </form>
      </div>
    )
  } else {
    const contacts = draft as Contact[]
    const change = (position: number, field: keyof Contact, value: string) =>
      setDraft(
        contacts.map((contact, index) =>
          index === position ? { ...contact, [field]: value } : contact,
        ),
      )
    editor = (
      <div className="space-y-2">
        {contacts.map((contact, position) => (
          <div key={position} className="grid grid-cols-[1fr_1fr_1fr_auto] items-end gap-2">
            {(['name', 'role', 'phone_number'] as const).map((field) => (
              <div key={field} className="grid gap-1">
                <Label htmlFor={`${id}-${position}-${field}`} className="text-xs">
                  {field === 'phone_number' ? 'Phone' : field === 'name' ? 'Name' : 'Role'}
                </Label>
                <Input
                  id={`${id}-${position}-${field}`}
                  value={contact[field]}
                  onChange={(event) => change(position, field, event.target.value)}
                />
              </div>
            ))}
            <Button
              size="icon"
              variant="ghost"
              aria-label={`Remove ${contact.name || 'this contact'}`}
              onClick={() => setDraft(contacts.filter((_, index) => index !== position))}
            >
              <X aria-hidden />
            </Button>
          </div>
        ))}
        {contacts.length < 20 ? (
          <Button
            size="sm"
            variant="outline"
            onClick={() => setDraft([...contacts, { name: '', role: '', phone_number: '' }])}
          >
            <Plus aria-hidden /> Add a contact
          </Button>
        ) : null}
      </div>
    )
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-base">
          {definition.kind === 'decimal' || definition.kind === 'whole' ? (
            <Label htmlFor={id}>{definition.title}</Label>
          ) : (
            definition.title
          )}
        </CardTitle>
        <CardDescription>
          {definition.help}{' '}
          {setting.overridden ? (
            <StatusBadge
              tone="info"
              label={`Changed${setting.updated_at ? ` ${formatDateTime(setting.updated_at)}` : ''}`}
            />
          ) : (
            <StatusBadge tone="neutral" label="Default" />
          )}
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-3">
        {editor}
        {problem ? (
          <p role="alert" className="text-sm text-danger-text">
            {problem}
          </p>
        ) : null}
        <div className="flex flex-wrap gap-2">
          <Button
            size="sm"
            disabled={!dirty || save.isPending}
            onClick={() => {
              const found = check()
              setProblem(found)
              if (!found) setConfirming('save')
            }}
          >
            <Save aria-hidden /> Save
          </Button>
          {dirty ? (
            <Button size="sm" variant="ghost" onClick={() => setDraft(setting.value)}>
              Undo changes
            </Button>
          ) : null}
          {setting.overridden ? (
            <Button size="sm" variant="ghost" onClick={() => setConfirming('reset')}>
              <RotateCcw aria-hidden /> Back to default
            </Button>
          ) : null}
        </div>
      </CardContent>
      <SaveDialog
        open={confirming !== null}
        onOpenChange={(open) => !open && setConfirming(null)}
        title={
          confirming === 'reset'
            ? `Put ${definition.title.toLowerCase()} back to the default?`
            : `Save ${definition.title.toLowerCase()}?`
        }
        description="It applies across the platform within about 30 seconds."
        onSave={async (reason) => {
          await persist(confirming === 'reset' ? null : normalised(), reason)
          setConfirming(null)
        }}
      />
    </Card>
  )
}

function FlagRow({ flag }: { flag: Flag }) {
  const queryClient = useQueryClient()
  const id = useId()
  const platformWide = flag.key === 'fare_sharing' || flag.key === 'book_moving_trips'
  const [pending, setPending] = useState<{ enabled?: boolean; rollout_percent?: number } | null>(
    null,
  )
  const [rollout, setRollout] = useState(String(flag.rollout_percent))
  const save = useMutation({
    mutationFn: (body: Schemas['FeatureFlagUpdateRequest']) =>
      unwrap(
        api.PATCH('/api/v1/admin/feature-flags/{key}', {
          params: { path: { key: flag.key } },
          body,
        }),
      ),
    onSuccess: () => void queryClient.invalidateQueries({ queryKey: ['feature-flags'] }),
  })
  return (
    <li className="space-y-2 rounded-lg border bg-card p-4">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0 space-y-1">
          <p id={`${id}-key`} className="figure text-sm font-medium">
            {flag.key}
          </p>
          <p className="text-sm text-muted-foreground">{flag.description}</p>
          <p className="text-xs text-muted-foreground">
            Last changed {formatDateTime(flag.updated_at)}
          </p>
        </div>
        <div className="flex items-center gap-2">
          {/* Named by the flag; on or off is the switch's own state. */}
          <Switch
            id={id}
            aria-labelledby={`${id}-key`}
            checked={flag.enabled}
            onCheckedChange={(enabled) => setPending({ enabled })}
          />
          <span className="text-sm font-medium" aria-hidden>
            {flag.enabled ? 'On' : 'Off'}
          </span>
        </div>
      </div>
      {platformWide ? (
        <p className="text-xs text-muted-foreground">Platform-wide: on or off for everyone.</p>
      ) : (
        <form
          className="flex items-end gap-2"
          onSubmit={(event) => {
            event.preventDefault()
            const value = Number(rollout)
            if (!Number.isInteger(value) || value < 0 || value > 100) {
              toast.error('Rollout is a whole number from 0 to 100.')
              return
            }
            setPending({ rollout_percent: value })
          }}
        >
          <div className="grid gap-1">
            <Label htmlFor={`${id}-rollout`} className="text-xs">
              Share of users who get it
            </Label>
            <div className="flex items-center gap-1">
              <Input
                id={`${id}-rollout`}
                className="w-20"
                inputMode="numeric"
                value={rollout}
                onChange={(event) => setRollout(event.target.value)}
              />
              <span className="text-sm text-muted-foreground">%</span>
            </div>
          </div>
          <Button
            type="submit"
            size="sm"
            variant="outline"
            disabled={rollout === String(flag.rollout_percent)}
          >
            Save
          </Button>
        </form>
      )}
      <SaveDialog
        open={pending !== null}
        onOpenChange={(open) => !open && setPending(null)}
        title={
          pending?.enabled !== undefined
            ? `Turn ${flag.key} ${pending.enabled ? 'on' : 'off'}?`
            : `Roll ${flag.key} out to ${pending?.rollout_percent}%?`
        }
        description={flag.description}
        onSave={async (reason) => {
          await save.mutateAsync({ ...pending, reason: reason || null })
          toast.success(`${flag.key} saved.`)
          setPending(null)
        }}
      />
    </li>
  )
}

/** Platform settings and feature flags, each changed on its own with a reason. */
export default function SettingsPage() {
  const { can } = useSession()
  const settings = useSettingsQuery(can('system_settings:manage'))
  const flags = useFlagsQuery(can('feature_flags:manage'))
  return (
    <>
      <PageHeader
        title="Settings"
        description="Changes apply across the platform and are kept in the audit log."
      />
      <div className="space-y-8">
        {can('system_settings:manage') ? (
          <Section title="Platform settings">
            <QueryState query={settings} skeleton={<TableSkeleton rows={4} columns={2} />}>
              {(list) => (
                <div className="grid gap-4 xl:grid-cols-2">
                  {list.map((setting) => (
                    <SettingEditor
                      key={`${setting.key}-${setting.updated_at ?? 'default'}`}
                      setting={setting}
                    />
                  ))}
                </div>
              )}
            </QueryState>
          </Section>
        ) : null}
        {can('feature_flags:manage') ? (
          <Section title="Feature flags">
            <QueryState query={flags} skeleton={<TableSkeleton rows={3} columns={2} />}>
              {(list) => (
                <ul className="grid gap-3 xl:grid-cols-2">
                  {list.map((flag) => (
                    <FlagRow key={`${flag.key}-${flag.updated_at}`} flag={flag} />
                  ))}
                </ul>
              )}
            </QueryState>
          </Section>
        ) : null}
      </div>
    </>
  )
}
