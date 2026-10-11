import {
  CircleCheck,
  CircleDashed,
  CircleX,
  Clock,
  Info,
  TriangleAlert,
  type LucideIcon,
} from 'lucide-react'

import { cn } from '@/lib/utils'

export type Tone = 'success' | 'warning' | 'danger' | 'info' | 'neutral'

const TONE_CLASSES: Record<Tone, string> = {
  success: 'bg-success-soft text-success-text border-success/30',
  warning: 'bg-warning-soft text-warning-text border-warning/40',
  danger: 'bg-danger-soft text-danger-text border-danger/30',
  info: 'bg-info-soft text-info-text border-info/30',
  neutral: 'bg-muted text-muted-foreground border-border',
}

const TONE_ICONS: Record<Tone, LucideIcon> = {
  success: CircleCheck,
  warning: TriangleAlert,
  danger: CircleX,
  info: Info,
  neutral: CircleDashed,
}

/** A status: always an icon and a label, never colour alone. */
export function StatusBadge({
  tone,
  label,
  icon,
  className,
}: {
  tone: Tone
  label: string
  icon?: LucideIcon
  className?: string
}) {
  const Icon = icon ?? TONE_ICONS[tone]
  return (
    <span
      className={cn(
        'inline-flex items-center gap-1 rounded-full border px-2 py-0.5 text-xs font-medium whitespace-nowrap',
        TONE_CLASSES[tone],
        className,
      )}
    >
      <Icon className="size-3.5 shrink-0" aria-hidden />
      {label}
    </span>
  )
}

/** For statuses that are waiting on someone. */
export const PendingIcon = Clock
