import { Check, Undo2 } from 'lucide-react'
import { useId, useState } from 'react'
import { toast } from 'sonner'

import { errorMessage } from '@/api/errors'
import type { Schemas } from '@/api/types'
import { useSession } from '@/app/auth/auth-context'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Textarea } from '@/components/ui/textarea'

import { useReviewDocument, type DocumentType, type QueueKind } from './api'
import { DOCUMENT_LABELS } from './documents'

/** Documents with a date printed on them. */
const DATED = new Set<DocumentType>([
  'vehicle_insurance',
  'driver_license',
  'roadworthiness_certificate',
])
const MIN_REASON = 5

/**
 * Accept a document with the date printed on it, or send it back with a
 * reason. Only a date accepted here counts: insurance warnings and blocks go by
 * these dates, and accepting a later one unblocks a driver at once.
 */
export function DocumentReview({
  kind,
  document,
}: {
  kind: QueueKind
  document: Schemas['DocumentSummary']
}) {
  const { can } = useSession()
  const review = useReviewDocument()
  const id = useId()
  const [expiry, setExpiry] = useState(document.expiry_date ?? '')
  const [sendingBack, setSendingBack] = useState(false)
  const [reason, setReason] = useState('')
  const [failure, setFailure] = useState<string | null>(null)

  if (!can(kind === 'drivers' ? 'drivers:approve' : 'vehicles:approve')) return null

  const label = DOCUMENT_LABELS[document.document_type]
  const dated = DATED.has(document.document_type)
  const needsDate = document.document_type === 'vehicle_insurance'
  const accepted = document.status === 'approved'

  const accept = async () => {
    setFailure(null)
    try {
      const reviewed = await review.mutateAsync({
        id: document.id,
        decision: 'approved',
        expiry_date: dated && expiry ? expiry : null,
      })
      toast.success(
        reviewed.drivers_unblocked.length > 0
          ? `${label} accepted. The driver can take trips again.`
          : `${label} accepted.`,
      )
    } catch (error) {
      setFailure(errorMessage(error))
    }
  }

  const sendBack = async () => {
    setFailure(null)
    try {
      await review.mutateAsync({
        id: document.id,
        decision: 'rejected',
        rejection_reason: reason.trim(),
      })
      toast.success(`${label} sent back.`)
      setSendingBack(false)
      setReason('')
    } catch (error) {
      setFailure(errorMessage(error))
    }
  }

  return (
    <section aria-label={`Review ${label}`} className="space-y-3 rounded-lg border bg-card p-3">
      <div className="flex flex-wrap items-end gap-3">
        {dated ? (
          <div className="space-y-1.5">
            <Label htmlFor={`${id}-expiry`}>Expires on</Label>
            <Input
              id={`${id}-expiry`}
              type="date"
              value={expiry}
              onChange={(event) => setExpiry(event.target.value)}
              className="w-44"
            />
          </div>
        ) : null}
        <Button onClick={() => void accept()} disabled={review.isPending || (needsDate && !expiry)}>
          <Check aria-hidden />
          {accepted ? 'Save date' : 'Accept'}
        </Button>
        {sendingBack ? null : (
          <Button
            variant="outline"
            onClick={() => setSendingBack(true)}
            disabled={review.isPending}
          >
            <Undo2 aria-hidden />
            Send back
          </Button>
        )}
      </div>
      {needsDate ? (
        <p className="text-sm text-muted-foreground">
          Enter the date printed on the certificate. Drivers are warned and blocked by this date.
        </p>
      ) : null}
      {sendingBack ? (
        <div className="space-y-2">
          <Label htmlFor={`${id}-reason`}>What’s wrong (they see this)</Label>
          <Textarea
            id={`${id}-reason`}
            value={reason}
            onChange={(event) => setReason(event.target.value)}
            maxLength={500}
          />
          <div className="flex gap-2">
            <Button
              onClick={() => void sendBack()}
              disabled={review.isPending || reason.trim().length < MIN_REASON}
            >
              Send it back
            </Button>
            <Button variant="ghost" onClick={() => setSendingBack(false)}>
              Keep it
            </Button>
          </div>
        </div>
      ) : null}
      {failure ? (
        <p role="alert" className="text-sm text-destructive">
          {failure}
        </p>
      ) : null}
    </section>
  )
}
