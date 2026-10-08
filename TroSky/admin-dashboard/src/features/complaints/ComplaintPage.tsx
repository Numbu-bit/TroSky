import {
  ArrowLeft,
  CircleCheck,
  CircleSlash,
  Eye,
  Lock,
  Send,
  UserCheck,
  UserMinus,
} from 'lucide-react'
import { useId, useState, type ReactNode } from 'react'
import { Link, useParams } from 'react-router'
import { toast } from 'sonner'

import { errorMessage, isApiError } from '@/api/errors'
import type { Schemas } from '@/api/types'
import { useSession } from '@/app/auth/auth-context'
import { ConfirmButton } from '@/components/confirm/ConfirmButton'
import { EmptyState, ErrorState, PageSkeleton } from '@/components/feedback/states'
import { PageHeader, Section } from '@/components/layout/PageHeader'
import { StatusBadge } from '@/components/status/StatusBadge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Label } from '@/components/ui/label'
import { RadioGroup, RadioGroupItem } from '@/components/ui/radio-group'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import { Textarea } from '@/components/ui/textarea'
import { formatDateTime, formatPhone, maskPhone } from '@/lib/format'
import { isModuleEnabled } from '@/lib/modules'
import { useNow } from '@/lib/use-now'
import { cn } from '@/lib/utils'

import {
  useAddComplaintNote,
  useComplaint,
  useComplaintTeam,
  useDecideComplaint,
  useUpdateComplaint,
  type ComplaintPriority,
} from './api'
import { Due } from './Due'
import { CATEGORY, COMPLAINT_STATUS, OPEN_STATUSES, PRIORITIES, PRIORITY } from './labels'

type Detail = Schemas['AdminComplaintDetailResponse']

function Fact({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div className="flex justify-between gap-3 py-1.5 text-sm">
      <dt className="text-muted-foreground">{label}</dt>
      <dd className="text-right">{children}</dd>
    </div>
  )
}

function Thread({ complaint }: { complaint: Detail }) {
  const add = useAddComplaintNote(complaint.id)
  const [kind, setKind] = useState<'internal' | 'message'>('internal')
  const [body, setBody] = useState('')
  const bodyId = useId()
  const open = OPEN_STATUSES.has(complaint.status)

  async function send() {
    try {
      await add.mutateAsync({ kind, body: body.trim() })
      toast.success(kind === 'message' ? 'Sent to the passenger.' : 'Note added.')
      setBody('')
    } catch (error) {
      toast.error(errorMessage(error))
    }
  }

  return (
    <Section
      title="Notes and messages"
      description="Internal notes stay with the team; messages go to the passenger."
    >
      {complaint.notes.length ? (
        <ol className="space-y-3">
          {complaint.notes.map((note) => (
            <li
              key={note.id}
              className={cn(
                'rounded-lg border p-3 text-sm',
                note.kind === 'message' ? 'border-brand/40 bg-success-soft/40' : 'bg-card',
              )}
            >
              <p className="mb-1 flex flex-wrap items-center gap-2 text-xs text-muted-foreground">
                <StatusBadge
                  tone={note.kind === 'message' ? 'success' : 'neutral'}
                  icon={note.kind === 'message' ? Send : Lock}
                  label={note.kind === 'message' ? 'Sent to the passenger' : 'Internal note'}
                />
                {note.author_name ?? 'An admin'} · {formatDateTime(note.created_at)}
              </p>
              <p className="whitespace-pre-wrap">{note.body}</p>
            </li>
          ))}
        </ol>
      ) : (
        <p className="text-sm text-muted-foreground">Nothing written yet.</p>
      )}
      {open ? (
        <div className="space-y-2 rounded-lg border bg-card p-3">
          <RadioGroup
            value={kind}
            onValueChange={(value) => setKind(value as 'internal' | 'message')}
            className="flex flex-wrap gap-4"
            aria-label="Who sees it"
          >
            <div className="flex items-center gap-2">
              <RadioGroupItem value="internal" id={`${bodyId}-internal`} />
              <Label htmlFor={`${bodyId}-internal`} className="font-normal">
                Internal note
              </Label>
            </div>
            <div className="flex items-center gap-2">
              <RadioGroupItem value="message" id={`${bodyId}-message`} />
              <Label htmlFor={`${bodyId}-message`} className="font-normal">
                Message to the passenger
              </Label>
            </div>
          </RadioGroup>
          <Label htmlFor={bodyId} className="sr-only">
            {kind === 'message' ? 'Message' : 'Note'}
          </Label>
          <Textarea
            id={bodyId}
            value={body}
            maxLength={2000}
            onChange={(event) => setBody(event.target.value)}
            placeholder={
              kind === 'message'
                ? 'They get this as a notification from TroSky support.'
                : 'Only admins see this.'
            }
          />
          <div className="flex justify-end">
            <Button size="sm" onClick={() => void send()} disabled={!body.trim() || add.isPending}>
              <Send aria-hidden /> {kind === 'message' ? 'Send message' : 'Add note'}
            </Button>
          </div>
        </div>
      ) : null}
    </Section>
  )
}

function Handling({ complaint }: { complaint: Detail }) {
  const { me } = useSession()
  const update = useUpdateComplaint(complaint.id)
  const team = useComplaintTeam()
  const priorityId = useId()
  const assigneeId = useId()
  const change = async (body: Schemas['ComplaintUpdateRequest'], done: string) => {
    try {
      await update.mutateAsync(body)
      toast.success(done)
    } catch (error) {
      toast.error(errorMessage(error))
    }
  }
  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-base">Handling</CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="space-y-2">
          {team.data?.length ? (
            <>
              <Label htmlFor={assigneeId}>With</Label>
              <Select
                value={complaint.assigned_to ?? 'nobody'}
                onValueChange={(value) =>
                  void change(
                    { assigned_to: value === 'nobody' ? null : value },
                    value === 'nobody' ? 'Unassigned.' : 'Assigned.',
                  )
                }
              >
                <SelectTrigger id={assigneeId}>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="nobody">Nobody yet</SelectItem>
                  {team.data.map((member) => (
                    <SelectItem key={member.id} value={member.id}>
                      {member.full_name ?? member.email ?? member.phone_number}
                      {member.id === me.id ? ' (you)' : ''}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </>
          ) : (
            <>
              <p className="text-sm">
                <span className="text-muted-foreground">With: </span>
                {complaint.assigned_to === me.id
                  ? 'You'
                  : (complaint.assignee_name ?? 'Nobody yet')}
              </p>
              {complaint.assigned_to === me.id ? (
                <Button
                  size="sm"
                  variant="outline"
                  onClick={() => void change({ assigned_to: null }, 'Unassigned.')}
                >
                  <UserMinus aria-hidden /> Give it back
                </Button>
              ) : (
                <Button
                  size="sm"
                  variant="outline"
                  onClick={() => void change({ assigned_to: me.id }, 'It’s yours.')}
                >
                  <UserCheck aria-hidden /> Take it
                </Button>
              )}
            </>
          )}
        </div>
        <div className="grid gap-1.5">
          <Label htmlFor={priorityId}>Priority</Label>
          <Select
            value={complaint.priority}
            onValueChange={(value) =>
              void change(
                { priority: value as ComplaintPriority },
                `Priority set to ${PRIORITY[value as ComplaintPriority].label.toLowerCase()}. The due time follows it.`,
              )
            }
          >
            <SelectTrigger id={priorityId}>
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              {PRIORITIES.map((value) => (
                <SelectItem key={value} value={value}>
                  {PRIORITY[value].label}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
        {complaint.status === 'open' ? (
          <Button
            size="sm"
            variant="outline"
            onClick={() => void change({ status: 'in_review' }, 'Review started.')}
          >
            <Eye aria-hidden /> Start review
          </Button>
        ) : null}
      </CardContent>
    </Card>
  )
}

function Decision({ complaint }: { complaint: Detail }) {
  const decide = useDecideComplaint(complaint.id)
  return (
    <div className="flex flex-wrap gap-2">
      <ConfirmButton
        label="Resolve"
        icon={CircleCheck}
        title="Resolve this complaint?"
        description="It closes, and the passenger is told it was resolved."
        confirmLabel="Resolve"
        reason={{
          label: 'Resolution note',
          required: true,
          maxLength: 1000,
          placeholder: 'e.g. We spoke to the driver; a warning has been recorded.',
        }}
        onConfirm={async (notes) => {
          await decide.mutateAsync({ resolve: true, notes })
          toast.success('Complaint resolved.')
        }}
      />
      <ConfirmButton
        label="Dismiss"
        icon={CircleSlash}
        variant="outline"
        title="Dismiss this complaint?"
        description="It closes without action. The passenger is told."
        confirmLabel="Dismiss"
        destructive
        reason={{
          label: 'Why it is dismissed',
          required: true,
          maxLength: 1000,
          placeholder: 'e.g. A duplicate of an earlier complaint.',
        }}
        onConfirm={async (notes) => {
          await decide.mutateAsync({ resolve: false, notes })
          toast.success('Complaint dismissed.')
        }}
      />
    </div>
  )
}

/** One complaint: what was said, the notes, who has it, and the decision. */
export function ComplaintPage() {
  const { complaintId = '' } = useParams()
  const { can } = useSession()
  const complaint = useComplaint(complaintId)
  const now = useNow(30_000)
  const [revealed, setRevealed] = useState(false)
  const insights = isModuleEnabled('complaints-insights')

  if (complaint.isPending) return <PageSkeleton />
  if (complaint.isError) {
    return (
      <>
        <BackLink />
        {isApiError(complaint.error, 404) ? (
          <EmptyState title="Complaint not found" description="The link may be wrong or old." />
        ) : (
          <ErrorState error={complaint.error} onRetry={() => void complaint.refetch()} />
        )}
      </>
    )
  }
  const data = complaint.data
  const status = COMPLAINT_STATUS[data.status]
  const open = OPEN_STATUSES.has(data.status)

  return (
    <>
      <BackLink />
      <PageHeader
        title={data.subject}
        description={
          <span className="inline-flex flex-wrap items-center gap-2">
            <StatusBadge tone={status.tone} label={status.label} icon={status.icon} />
            <StatusBadge
              tone={PRIORITY[data.priority].tone}
              label={`${PRIORITY[data.priority].label} priority`}
            />
            <span>{CATEGORY[data.category]}</span>
            {open && insights ? <Due complaint={data} now={now} prefix="due " /> : null}
          </span>
        }
      />
      <div className="grid gap-6 lg:grid-cols-3">
        <div className="space-y-6 lg:col-span-2">
          <Section title="What they said">
            <p className="rounded-lg border bg-card p-4 text-sm whitespace-pre-wrap">
              {data.description}
            </p>
            <p className="flex flex-wrap gap-4 text-sm">
              {data.booking_id && can('bookings:view_any') ? (
                <Link to={`/bookings?booking=${data.booking_id}`} className="link-inline">
                  Open the booking
                </Link>
              ) : null}
              {data.trip_id && can('trips:manage', 'trips:monitor_live') ? (
                <Link to={`/trips/${data.trip_id}`} className="link-inline">
                  Open the trip
                </Link>
              ) : null}
            </p>
          </Section>
          {!open ? (
            <Section
              title={data.status === 'resolved' ? 'How it was resolved' : 'Why it was dismissed'}
            >
              <p className="rounded-lg border bg-card p-4 text-sm whitespace-pre-wrap">
                {data.resolution_notes ?? 'No note was left.'}
              </p>
              {data.resolved_at ? (
                <p className="text-xs text-muted-foreground">{formatDateTime(data.resolved_at)}</p>
              ) : null}
            </Section>
          ) : null}
          {insights ? <Thread complaint={data} /> : null}
        </div>
        <div className="space-y-6">
          <Card>
            <CardHeader>
              <CardTitle className="text-base">Details</CardTitle>
            </CardHeader>
            <CardContent>
              <dl className="divide-y">
                <Fact label="From">{data.filed_by_name ?? 'A passenger'}</Fact>
                <Fact label="Phone">
                  {data.filed_by_phone ? (
                    revealed ? (
                      <a className="figure link-inline" href={`tel:${data.filed_by_phone}`}>
                        {formatPhone(data.filed_by_phone)}
                      </a>
                    ) : (
                      <button
                        type="button"
                        className="figure link-inline"
                        onClick={() => setRevealed(true)}
                        aria-label="Show the full number"
                      >
                        {maskPhone(data.filed_by_phone)}
                      </button>
                    )
                  ) : (
                    '—'
                  )}
                </Fact>
                <Fact label="Filed">{formatDateTime(data.created_at)}</Fact>
                {insights ? (
                  <>
                    <Fact label="Due">{formatDateTime(data.due_at)}</Fact>
                    <Fact label="First response">
                      {data.first_response_at ? formatDateTime(data.first_response_at) : 'Not yet'}
                    </Fact>
                  </>
                ) : null}
              </dl>
            </CardContent>
          </Card>
          {open && insights ? <Handling complaint={data} /> : null}
          {open ? <Decision complaint={data} /> : null}
        </div>
      </div>
    </>
  )
}

function BackLink() {
  return (
    <Button asChild variant="ghost" size="sm" className="mb-2 -ml-2">
      <Link to="/complaints">
        <ArrowLeft aria-hidden /> Complaints
      </Link>
    </Button>
  )
}
