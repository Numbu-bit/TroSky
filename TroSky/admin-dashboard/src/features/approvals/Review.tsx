import { Check, Undo2, X } from 'lucide-react'
import { useId, useState, type ReactNode } from 'react'
import { toast } from 'sonner'

import type { Schemas } from '@/api/types'
import { ConfirmButton } from '@/components/confirm/ConfirmButton'
import { ConfirmFacts } from '@/components/confirm/ConfirmDialog'
import { ErrorState } from '@/components/feedback/states'
import { StatusBadge } from '@/components/status/StatusBadge'
import { Button } from '@/components/ui/button'
import { Checkbox } from '@/components/ui/checkbox'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
import { Label } from '@/components/ui/label'
import { Skeleton } from '@/components/ui/skeleton'
import { Textarea } from '@/components/ui/textarea'
import { errorMessage } from '@/api/errors'
import { formatAge, formatDate, formatPhone, humanize } from '@/lib/format'
import { useNow } from '@/lib/use-now'

import {
  useDecide,
  useDriverDetail,
  useRequestInfo,
  useVehicleDetail,
  type DocumentType,
  type QueueKind,
} from './api'
import { Documents, Expiry, Facts } from './DocumentList'
import { CHECKLISTS, DOCUMENT_LABELS, EXPECTED } from './documents'

type Document = Schemas['DocumentSummary']
const DECIDABLE = new Set(['pending', 'under_review'])

function Checklist({
  kind,
  checked,
  onChange,
}: {
  kind: QueueKind
  checked: Set<string>
  onChange: (next: Set<string>) => void
}) {
  const items = CHECKLISTS[kind]
  return (
    <fieldset className="space-y-2">
      <legend className="mb-1 text-sm font-semibold">
        Checks ({checked.size} of {items.length})
      </legend>
      {items.map((item) => (
        <div key={item.id} className="flex items-start gap-2">
          <Checkbox
            id={`check-${item.id}`}
            checked={checked.has(item.id)}
            onCheckedChange={(value) => {
              const next = new Set(checked)
              if (value === true) next.add(item.id)
              else next.delete(item.id)
              onChange(next)
            }}
          />
          <Label htmlFor={`check-${item.id}`} className="text-sm leading-snug font-normal">
            {item.label}
          </Label>
        </div>
      ))}
    </fieldset>
  )
}

function RequestDocuments({
  kind,
  id,
  name,
  documents,
  onDone,
}: {
  kind: QueueKind
  id: string
  name: string
  documents: Document[]
  onDone: () => void
}) {
  const [open, setOpen] = useState(false)
  const [types, setTypes] = useState<DocumentType[]>([])
  const [note, setNote] = useState('')
  const [failure, setFailure] = useState<string | null>(null)
  const request = useRequestInfo()
  const noteId = useId()
  const options = [
    ...new Set<DocumentType>([
      ...EXPECTED[kind].map((expected) => expected.type),
      ...documents.map((document) => document.document_type),
      'other',
    ]),
  ]
  const ready = types.length > 0 && note.trim().length >= 5

  async function send() {
    setFailure(null)
    try {
      await request.mutateAsync({ kind, id, document_types: types, note: note.trim() })
      toast.success(`Asked ${name} for ${types.length === 1 ? 'a document' : 'documents'}.`)
      setOpen(false)
      setTypes([])
      setNote('')
      onDone()
    } catch (error) {
      setFailure(errorMessage(error))
    }
  }

  return (
    <>
      <Button variant="outline" onClick={() => setOpen(true)}>
        <Undo2 aria-hidden /> Ask for documents
      </Button>
      <Dialog open={open} onOpenChange={(next) => !request.isPending && setOpen(next)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Ask {name} for documents</DialogTitle>
            <DialogDescription>
              Instead of rejecting: they’re told what to upload again, and the application waits for
              them.
            </DialogDescription>
          </DialogHeader>
          <fieldset className="space-y-2">
            <legend className="mb-1 text-sm font-medium">Which documents</legend>
            {options.map((type) => (
              <div key={type} className="flex items-center gap-2">
                <Checkbox
                  id={`${noteId}-${type}`}
                  checked={types.includes(type)}
                  onCheckedChange={(value) =>
                    setTypes((current) =>
                      value === true ? [...current, type] : current.filter((item) => item !== type),
                    )
                  }
                />
                <Label htmlFor={`${noteId}-${type}`} className="font-normal">
                  {DOCUMENT_LABELS[type]}
                </Label>
              </div>
            ))}
          </fieldset>
          <div className="space-y-1.5">
            <Label htmlFor={noteId}>What’s wrong (they see this)</Label>
            <Textarea
              id={noteId}
              value={note}
              maxLength={500}
              placeholder="e.g. The licence photo is blurred. Please upload a clear photo of the front."
              onChange={(event) => setNote(event.target.value)}
            />
            <p className="text-xs text-muted-foreground">At least 5 characters.</p>
          </div>
          {failure ? (
            <p role="alert" className="rounded-md bg-danger-soft p-2 text-sm text-danger-text">
              {failure}
            </p>
          ) : null}
          <DialogFooter>
            <Button onClick={() => void send()} disabled={!ready || request.isPending}>
              Send request
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </>
  )
}

function Decisions({
  kind,
  id,
  name,
  status,
  documents,
  facts,
  onDecided,
}: {
  kind: QueueKind
  id: string
  name: string
  status: Schemas['ApprovalStatus']
  documents: Document[]
  facts: [string, ReactNode][]
  onDecided: () => void
}) {
  const [checked, setChecked] = useState<Set<string>>(new Set())
  const decide = useDecide()
  const ready = checked.size === CHECKLISTS[kind].length
  const what = kind === 'drivers' ? 'driver' : 'vehicle'

  if (!DECIDABLE.has(status)) {
    return (
      <p className="text-sm text-muted-foreground">
        This application is {humanize(status).toLowerCase()}: nothing to decide.
      </p>
    )
  }

  return (
    <div className="space-y-4">
      <Checklist kind={kind} checked={checked} onChange={setChecked} />
      <div className="flex flex-wrap gap-2">
        <ConfirmButton
          label={`Approve ${what}`}
          icon={Check}
          disabled={!ready}
          title={`Approve ${name}?`}
          description={
            kind === 'drivers'
              ? 'They can be put on trips straight away.'
              : 'It can be put on trips straight away.'
          }
          details={<ConfirmFacts rows={facts} />}
          confirmLabel={`Approve ${what}`}
          reason={{ label: 'Note for the record', placeholder: 'Anything worth keeping.' }}
          onConfirm={async (notes) => {
            await decide.mutateAsync({ kind, id, approve: true, notes })
            toast.success(`${name} approved.`)
            onDecided()
          }}
        />
        <ConfirmButton
          label="Reject"
          icon={X}
          variant="outline"
          title={`Reject ${name}?`}
          description="The application ends. They can apply again."
          details={<ConfirmFacts rows={facts} />}
          confirmLabel="Reject"
          destructive
          reason={{
            label: 'Reason (they see it)',
            required: true,
            minLength: 5,
            maxLength: 500,
            placeholder: 'e.g. The licence has expired.',
          }}
          onConfirm={async (reason) => {
            await decide.mutateAsync({ kind, id, approve: false, reason })
            toast.success(`${name} rejected.`)
            onDecided()
          }}
        />
        <RequestDocuments
          kind={kind}
          id={id}
          name={name}
          documents={documents}
          onDone={onDecided}
        />
      </div>
      {!ready ? (
        <p className="text-xs text-muted-foreground">Tick every check to approve.</p>
      ) : null}
    </div>
  )
}

function ReviewLayout({
  title,
  subtitle,
  facts,
  documents,
  decisions,
}: {
  title: string
  subtitle: ReactNode
  facts: ReactNode
  documents: ReactNode
  decisions: ReactNode
}) {
  return (
    <article className="space-y-5" aria-label={`Application: ${title}`}>
      <header className="space-y-1">
        <h2 className="text-xl font-semibold">{title}</h2>
        <div className="text-sm text-muted-foreground">{subtitle}</div>
      </header>
      <div className="grid gap-6 xl:grid-cols-5">
        <div className="xl:col-span-3">{documents}</div>
        <div className="space-y-6 xl:col-span-2">
          {facts}
          {decisions}
        </div>
      </div>
    </article>
  )
}

function ReviewSkeleton() {
  return (
    <div className="space-y-4">
      <Skeleton className="h-8 w-64" />
      <Skeleton className="h-96" />
    </div>
  )
}

function DriverReview({ id, onDecided }: { id: string; onDecided: () => void }) {
  const driver = useDriverDetail(id)
  const now = useNow(60_000)
  if (driver.isPending) return <ReviewSkeleton />
  if (driver.isError)
    return <ErrorState error={driver.error} onRetry={() => void driver.refetch()} />
  const data = driver.data
  const name = data.full_name ?? 'Unnamed applicant'
  const facts: [string, ReactNode][] = [
    ['Phone', formatPhone(data.phone_number)],
    ['Email', data.email ?? '—'],
    ['Licence', <span className="figure">{data.license_number}</span>],
    ['Class', data.license_class ?? '—'],
    ['Expires', <Expiry date={data.license_expiry} now={now} />],
    ['Experience', data.years_of_experience !== null ? `${data.years_of_experience} years` : '—'],
    ['Fleet', data.fleet?.name ?? 'Independent'],
  ]
  return (
    <ReviewLayout
      title={name}
      subtitle={
        <>
          Applied {formatDate(data.created_at)} · waiting {formatAge(data.created_at, now)} ·{' '}
          <StatusBadge tone="warning" label={humanize(data.status)} />
        </>
      }
      documents={<Documents kind="drivers" documents={data.documents} owner={name} />}
      facts={<Facts rows={facts} />}
      decisions={
        <Decisions
          kind="drivers"
          id={data.id}
          name={name}
          status={data.status}
          documents={data.documents}
          facts={[
            ['Licence', data.license_number],
            ['Expires', formatDate(`${data.license_expiry}T12:00:00Z`)],
          ]}
          onDecided={onDecided}
        />
      }
    />
  )
}

function VehicleReview({ id, onDecided }: { id: string; onDecided: () => void }) {
  const vehicle = useVehicleDetail(id)
  const now = useNow(60_000)
  if (vehicle.isPending) return <ReviewSkeleton />
  if (vehicle.isError) {
    return <ErrorState error={vehicle.error} onRetry={() => void vehicle.refetch()} />
  }
  const data = vehicle.data
  const facts: [string, ReactNode][] = [
    ['Plate', <span className="figure">{data.registration_number}</span>],
    ['Type', humanize(data.vehicle_type)],
    ['Make and model', data.make_model ?? '—'],
    ['Year', data.year ?? '—'],
    ['Seats', data.capacity],
    ['Fleet', data.fleet.name ?? '—'],
    ['Owner', data.fleet_owner.name ?? '—'],
    ['Insurance', <Expiry date={data.insurance_expiry} now={now} />],
    ['Roadworthy', <Expiry date={data.roadworthy_expiry} now={now} />],
  ]
  return (
    <ReviewLayout
      title={data.registration_number}
      subtitle={
        <>
          {data.make_model ?? humanize(data.vehicle_type)} · added {formatDate(data.created_at)} ·
          waiting {formatAge(data.created_at, now)} ·{' '}
          <StatusBadge tone="warning" label={humanize(data.status)} />
        </>
      }
      documents={
        <Documents kind="vehicles" documents={data.documents} owner={data.registration_number} />
      }
      facts={<Facts rows={facts} />}
      decisions={
        <Decisions
          kind="vehicles"
          id={data.id}
          name={data.registration_number}
          status={data.status}
          documents={data.documents}
          facts={[
            ['Vehicle', data.make_model ?? humanize(data.vehicle_type)],
            ['Seats', String(data.capacity)],
          ]}
          onDecided={onDecided}
        />
      }
    />
  )
}

/** One application under review. Re-mounted for each, so its checks start empty. */
export function Review({
  kind,
  id,
  onDecided,
}: {
  kind: QueueKind
  id: string
  onDecided: () => void
}) {
  return kind === 'drivers' ? (
    <DriverReview key={id} id={id} onDecided={onDecided} />
  ) : (
    <VehicleReview key={id} id={id} onDecided={onDecided} />
  )
}
