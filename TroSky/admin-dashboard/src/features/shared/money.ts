import type { Schemas } from '@/api/types'
import type { Tone } from '@/components/status/StatusBadge'

export type Channel = Schemas['PaymentChannel']

/** How each payment channel is named to admins. */
export const CHANNEL_LABELS: Record<Channel, string> = {
  mtn_momo: 'MTN Mobile Money',
  telecel_cash: 'Telecel Cash',
  airteltigo_money: 'AirtelTigo Money',
  card: 'Debit card',
  wallet: 'TroSky wallet',
}

export const PAYMENT_STATUS: Record<Schemas['PaymentStatus'], { tone: Tone; label: string }> = {
  pending: { tone: 'warning', label: 'Pending' },
  processing: { tone: 'info', label: 'Processing' },
  successful: { tone: 'success', label: 'Paid' },
  failed: { tone: 'danger', label: 'Failed' },
  cancelled: { tone: 'neutral', label: 'Cancelled' },
  refunded: { tone: 'neutral', label: 'Refunded' },
  partially_refunded: { tone: 'warning', label: 'Partly refunded' },
}

export const BOOKING_STATUS: Record<Schemas['BookingStatus'], { tone: Tone; label: string }> = {
  awaiting_acceptance: { tone: 'warning', label: 'Waiting for the driver' },
  pending: { tone: 'warning', label: 'Held, not paid' },
  payment_pending: { tone: 'info', label: 'Payment in progress' },
  confirmed: { tone: 'success', label: 'Confirmed' },
  completed: { tone: 'neutral', label: 'Travelled' },
  cancelled: { tone: 'neutral', label: 'Cancelled' },
  expired: { tone: 'neutral', label: 'Expired' },
  refund_pending: { tone: 'warning', label: 'Refund waiting' },
  refunded: { tone: 'neutral', label: 'Refunded' },
}

export const REFUND_STATUS: Record<Schemas['RefundStatus'], { tone: Tone; label: string }> = {
  pending: { tone: 'warning', label: 'Waiting for a decision' },
  approved: { tone: 'info', label: 'Approved, paying out' },
  completed: { tone: 'success', label: 'Paid back' },
  rejected: { tone: 'neutral', label: 'Rejected' },
  failed: { tone: 'danger', label: 'Payout failed' },
}

export const PAYOUT_STATUS: Record<Schemas['WithdrawalStatus'], { tone: Tone; label: string }> = {
  pending: { tone: 'warning', label: 'Waiting for a decision' },
  approved: { tone: 'info', label: 'Approved, to send' },
  completed: { tone: 'success', label: 'Sent' },
  rejected: { tone: 'neutral', label: 'Rejected' },
  failed: { tone: 'danger', label: 'Failed, money returned' },
}

export const CANCELLATION_STATUS: Record<
  Schemas['CancellationStatus'],
  { tone: Tone; label: string }
> = {
  pending: { tone: 'warning', label: 'Waiting for a decision' },
  approved: { tone: 'success', label: 'Approved' },
  rejected: { tone: 'neutral', label: 'Turned down' },
}
