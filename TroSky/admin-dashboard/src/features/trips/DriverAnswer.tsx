import { Clock, ThumbsDown, ThumbsUp } from 'lucide-react'

import type { Schemas } from '@/api/types'
import { StatusBadge } from '@/components/status/StatusBadge'

const ANSWERS = {
  pending: { tone: 'warning', label: 'Not answered yet', icon: Clock },
  accepted: { tone: 'success', label: 'Accepted', icon: ThumbsUp },
  declined: { tone: 'danger', label: 'Declined', icon: ThumbsDown },
} as const

/** The driver's answer to being put on a trip. */
export function DriverAnswer({
  response,
}: {
  response: Schemas['AssignmentResponse'] | null | undefined
}) {
  if (!response) return null
  const answer = ANSWERS[response]
  return <StatusBadge tone={answer.tone} label={answer.label} icon={answer.icon} />
}
