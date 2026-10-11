import { ExternalLink, FileWarning, RotateCw, Scan, ZoomIn, ZoomOut } from 'lucide-react'
import { useState } from 'react'

import { ErrorState } from '@/components/feedback/states'
import { Button } from '@/components/ui/button'
import { Skeleton } from '@/components/ui/skeleton'
import { formatNumber } from '@/lib/format'

import { useDocumentLink } from './api'
import { DOCUMENT_LABELS } from './documents'

const ZOOMS = [0.5, 0.75, 1, 1.25, 1.5, 2, 3]

/** One document, from a 5-minute link: images zoom and rotate; PDFs open as they are. */
export function DocumentViewer({ documentId, owner }: { documentId: string; owner: string }) {
  const link = useDocumentLink(documentId)
  const [zoom, setZoom] = useState(2)
  const [turns, setTurns] = useState(0)
  const scale = ZOOMS[zoom] ?? 1

  if (link.isPending) return <Skeleton className="h-96" />
  if (link.isError) return <ErrorState error={link.error} onRetry={() => void link.refetch()} />
  const document = link.data
  const label = `${DOCUMENT_LABELS[document.document_type]} for ${owner}`
  const image = document.mime_type.startsWith('image/')
  const pdf = document.mime_type === 'application/pdf'
  // Browsers won't open data: links in a tab (the demo's documents are data: images).
  const openable = !document.url.startsWith('data:')

  return (
    <figure className="space-y-2">
      <div className="flex flex-wrap items-center gap-1" role="toolbar" aria-label="Document view">
        {image ? (
          <>
            <Button
              size="icon"
              variant="outline"
              className="size-8"
              onClick={() => setZoom((value) => Math.max(0, value - 1))}
              disabled={zoom === 0}
              aria-label="Zoom out"
            >
              <ZoomOut aria-hidden />
            </Button>
            <span className="figure w-12 text-center text-sm" aria-live="polite">
              {formatNumber(scale * 100)}%
            </span>
            <Button
              size="icon"
              variant="outline"
              className="size-8"
              onClick={() => setZoom((value) => Math.min(ZOOMS.length - 1, value + 1))}
              disabled={zoom === ZOOMS.length - 1}
              aria-label="Zoom in"
            >
              <ZoomIn aria-hidden />
            </Button>
            <Button
              size="icon"
              variant="outline"
              className="size-8"
              onClick={() => setTurns((value) => (value + 1) % 4)}
              aria-label="Rotate a quarter turn"
            >
              <RotateCw aria-hidden />
            </Button>
            <Button
              size="sm"
              variant="ghost"
              onClick={() => {
                setZoom(2)
                setTurns(0)
              }}
            >
              <Scan aria-hidden /> Reset
            </Button>
          </>
        ) : null}
        {openable ? (
          <Button asChild size="sm" variant="ghost" className="ml-auto">
            <a href={document.url} target="_blank" rel="noreferrer">
              <ExternalLink aria-hidden /> Open in a new tab
            </a>
          </Button>
        ) : null}
      </div>
      <div className="h-[26rem] overflow-auto rounded-lg border bg-muted/40">
        {image ? (
          // Zoom sets the width (so the box scrolls to every part); rotation turns it.
          <div className="flex min-h-full min-w-full items-center justify-center p-3">
            <img
              src={document.url}
              alt={label}
              className="max-w-none transition-transform duration-150"
              style={{ width: `${scale * 100}%`, transform: `rotate(${turns * 90}deg)` }}
              draggable={false}
            />
          </div>
        ) : pdf ? (
          <object
            data={document.url}
            type="application/pdf"
            className="size-full"
            aria-label={label}
          >
            <p className="p-4 text-sm">
              This browser can’t show PDFs here.{' '}
              {openable ? (
                <a
                  className="text-primary underline"
                  href={document.url}
                  target="_blank"
                  rel="noreferrer"
                >
                  Open it in a new tab
                </a>
              ) : null}
            </p>
          </object>
        ) : (
          <p className="flex items-center gap-2 p-4 text-sm text-muted-foreground">
            <FileWarning className="size-4" aria-hidden /> This file type ({document.mime_type})
            can’t be shown here.
          </p>
        )}
      </div>
      <figcaption className="text-xs text-muted-foreground">
        {document.original_filename} · {formatNumber(Math.round(document.file_size_bytes / 1024))}{' '}
        KB · the link works for 5 minutes and renews while this is open.
      </figcaption>
    </figure>
  )
}
