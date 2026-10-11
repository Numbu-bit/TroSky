import { FileQuestion, FileX2 } from 'lucide-react'
import { useState, type ReactNode } from 'react'

import type { Schemas } from '@/api/types'
import { EmptyState } from '@/components/feedback/states'
import { StatusBadge, type Tone } from '@/components/status/StatusBadge'
import { formatDate } from '@/lib/format'
import { cn } from '@/lib/utils'

import type { QueueKind } from './api'
import { DocumentViewer } from './DocumentViewer'
import { DOCUMENT_LABELS, DOCUMENT_STATUS, EXPECTED } from './documents'

type Document = Schemas['DocumentSummary']
const DAY = 86_400_000

/** "Expired", "Expires in 12 days" or the date, for a licence or certificate. */
export function Expiry({ date, now }: { date: string | null; now: number }) {
  if (!date) return <span className="text-muted-foreground">Not given</span>
  const days = Math.floor((Date.parse(`${date}T23:59:59Z`) - now) / DAY)
  const tone: Tone | null = days < 0 ? 'danger' : days <= 30 ? 'warning' : null
  return (
    <span className="inline-flex flex-wrap items-center gap-2">
      <span className="figure">{formatDate(`${date}T12:00:00Z`)}</span>
      {tone ? (
        <StatusBadge tone={tone} label={days < 0 ? 'Expired' : `Expires in ${days} d`} />
      ) : null}
    </span>
  )
}

export function Facts({ rows }: { rows: [string, ReactNode][] }) {
  return (
    <dl className="grid grid-cols-[auto_1fr] gap-x-4 gap-y-2 text-sm">
      {rows.map(([label, value]) => (
        <div key={label} className="contents">
          <dt className="text-muted-foreground">{label}</dt>
          <dd className="min-w-0">{value}</dd>
        </div>
      ))}
    </dl>
  )
}

/** The documents uploaded, the expected ones missing, and the one being looked at. */
export function Documents({
  kind,
  documents,
  owner,
}: {
  kind: QueueKind
  documents: Document[]
  owner: string
}) {
  const [shown, setShown] = useState<string | null>(documents[0]?.id ?? null)
  const missing = EXPECTED[kind].filter(
    (expected) => !documents.some((document) => document.document_type === expected.type),
  )
  return (
    <div className="space-y-3">
      <ul className="flex flex-wrap gap-2" aria-label="Documents">
        {documents.map((document) => {
          const status = DOCUMENT_STATUS[document.status]
          const active = document.id === shown
          return (
            <li key={document.id}>
              <button
                type="button"
                onClick={() => setShown(document.id)}
                aria-pressed={active}
                className={cn(
                  'flex flex-col items-start gap-1 rounded-lg border bg-card px-3 py-2 text-left text-sm transition-colors hover:bg-muted',
                  active && 'border-brand ring-2 ring-brand/30',
                )}
              >
                <span className="font-medium">{DOCUMENT_LABELS[document.document_type]}</span>
                <StatusBadge tone={status.tone} label={status.label} />
              </button>
            </li>
          )
        })}
        {missing.map((expected) => (
          <li
            key={expected.type}
            className="flex flex-col items-start gap-1 rounded-lg border border-dashed px-3 py-2 text-sm text-muted-foreground"
          >
            <span>{DOCUMENT_LABELS[expected.type]}</span>
            <StatusBadge
              tone={expected.required ? 'danger' : 'neutral'}
              icon={FileX2}
              label={expected.required ? 'Missing' : 'Not uploaded (optional)'}
            />
          </li>
        ))}
      </ul>
      {shown ? (
        <>
          {(() => {
            const document = documents.find((candidate) => candidate.id === shown)
            return document?.rejection_reason ? (
              <p className="rounded-md bg-warning-soft p-2 text-sm text-warning-text">
                Asked again: {document.rejection_reason}
              </p>
            ) : null
          })()}
          <DocumentViewer key={shown} documentId={shown} owner={owner} />
        </>
      ) : (
        <EmptyState
          icon={FileQuestion}
          title="No documents uploaded"
          description="Ask for them, or reject the application."
        />
      )}
    </div>
  )
}
