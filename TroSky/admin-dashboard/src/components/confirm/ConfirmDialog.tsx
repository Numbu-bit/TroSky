import { LoaderCircle } from 'lucide-react'
import { useId, useRef, useState, type ReactNode } from 'react'

import { errorMessage } from '@/api/errors'
import {
  AlertDialog,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from '@/components/ui/alert-dialog'
import { Button } from '@/components/ui/button'
import { Label } from '@/components/ui/label'
import { Textarea } from '@/components/ui/textarea'

export interface ReasonOptions {
  label?: string
  required?: boolean
  placeholder?: string
  minLength?: number
  maxLength?: number
}

export interface ConfirmDialogProps {
  open: boolean
  onOpenChange: (open: boolean) => void
  title: string
  description?: ReactNode
  /** What it moves or changes: amount, recipient, method, consequence. */
  details?: ReactNode
  confirmLabel: string
  destructive?: boolean
  /** Ask for a reason (sent to the API where it accepts one). */
  reason?: ReasonOptions
  /** Resolve to close; throw to stay open and show why. */
  onConfirm: (reason: string) => Promise<void> | void
}

/**
 * Confirmation for destructive and money-moving actions. The confirm button
 * locks while the request runs, so an action can never be sent twice.
 */
export function ConfirmDialog({
  open,
  onOpenChange,
  title,
  description,
  details,
  confirmLabel,
  destructive,
  reason,
  onConfirm,
}: ConfirmDialogProps) {
  const [text, setText] = useState('')
  const [busy, setBusy] = useState(false)
  const [failure, setFailure] = useState<string | null>(null)
  const running = useRef(false)
  const reasonId = useId()

  const trimmed = text.trim()
  const minLength = reason?.required ? Math.max(reason.minLength ?? 3, 1) : 0
  const reasonOk = !reason || trimmed.length >= minLength

  function change(next: boolean) {
    if (busy) return
    if (!next) {
      setText('')
      setFailure(null)
    }
    onOpenChange(next)
  }

  async function confirm() {
    if (running.current || !reasonOk) return
    running.current = true
    setBusy(true)
    setFailure(null)
    try {
      await onConfirm(trimmed)
      setText('')
      onOpenChange(false)
    } catch (error) {
      setFailure(errorMessage(error))
    } finally {
      running.current = false
      setBusy(false)
    }
  }

  return (
    <AlertDialog open={open} onOpenChange={change}>
      <AlertDialogContent>
        <AlertDialogHeader>
          <AlertDialogTitle>{title}</AlertDialogTitle>
          {description ? <AlertDialogDescription>{description}</AlertDialogDescription> : null}
        </AlertDialogHeader>
        {details ? (
          <div className="rounded-md border bg-muted/50 p-3 text-sm">{details}</div>
        ) : null}
        {reason ? (
          <div className="space-y-1.5">
            <Label htmlFor={reasonId}>
              {reason.label ?? 'Reason'}
              {reason.required ? null : (
                <span className="font-normal text-muted-foreground"> (optional)</span>
              )}
            </Label>
            <Textarea
              id={reasonId}
              value={text}
              maxLength={reason.maxLength ?? 500}
              placeholder={reason.placeholder}
              onChange={(event) => setText(event.target.value)}
              aria-invalid={!reasonOk && text.length > 0 ? true : undefined}
            />
            {reason.required && !reasonOk ? (
              <p className="text-xs text-muted-foreground">
                At least {minLength} characters; it is kept with the record.
              </p>
            ) : null}
          </div>
        ) : null}
        {failure ? (
          <p role="alert" className="rounded-md bg-danger-soft p-2 text-sm text-danger-text">
            {failure}
          </p>
        ) : null}
        <AlertDialogFooter>
          <AlertDialogCancel disabled={busy}>Cancel</AlertDialogCancel>
          <Button
            variant={destructive ? 'destructive' : 'default'}
            disabled={busy || !reasonOk}
            onClick={() => void confirm()}
          >
            {busy ? <LoaderCircle className="animate-spin" aria-hidden /> : null}
            {confirmLabel}
          </Button>
        </AlertDialogFooter>
      </AlertDialogContent>
    </AlertDialog>
  )
}

/** Detail rows for a confirmation: "Amount  GH₵120.00". */
export function ConfirmFacts({ rows }: { rows: [string, ReactNode][] }) {
  return (
    <dl className="grid grid-cols-[auto_1fr] gap-x-4 gap-y-1">
      {rows.map(([term, value]) => (
        <div key={term} className="contents">
          <dt className="text-muted-foreground">{term}</dt>
          <dd className="font-medium">{value}</dd>
        </div>
      ))}
    </dl>
  )
}
