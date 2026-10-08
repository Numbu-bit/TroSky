import { ArrowDownRight, ArrowRight, ArrowUpRight } from 'lucide-react'
import type { ReactNode } from 'react'

import { cn } from '@/lib/utils'

/**
 * One figure with how it compares to the period before. Only what the API
 * returns: no trend is invented when there is no previous figure.
 */
export function StatTile({
  label,
  value,
  previous,
  changePercent,
  note,
  tone,
  className,
}: {
  label: string
  value: ReactNode
  /** The previous period's figure, formatted. */
  previous?: ReactNode
  /** "12.5" (per cent), or null when there was nothing before. */
  changePercent?: string | null
  note?: ReactNode
  tone?: 'danger' | 'warning'
  className?: string
}) {
  const change =
    changePercent === undefined || changePercent === null ? null : Number(changePercent)
  const Arrow =
    change === null || change === 0 ? ArrowRight : change > 0 ? ArrowUpRight : ArrowDownRight
  return (
    <div
      className={cn(
        'rounded-xl border bg-card p-4 shadow-xs',
        tone === 'danger' && 'border-danger/40 bg-danger-soft',
        tone === 'warning' && 'border-warning/40 bg-warning-soft',
        className,
      )}
    >
      <p className="text-sm text-muted-foreground">{label}</p>
      <p className="figure mt-1 text-2xl text-foreground">{value}</p>
      {previous !== undefined ? (
        <p className="mt-2 flex flex-wrap items-center gap-1 text-xs">
          {/* No change figure (nothing before to compare with): just the figure before. */}
          {change !== null ? (
            <>
              <Arrow className="size-3.5" aria-hidden />
              <span className="figure">{`${change > 0 ? '+' : ''}${changePercent}%`}</span>
            </>
          ) : null}
          <span className="text-muted-foreground">period before: {previous}</span>
        </p>
      ) : null}
      {note ? <p className="mt-1 text-xs text-muted-foreground">{note}</p> : null}
    </div>
  )
}
