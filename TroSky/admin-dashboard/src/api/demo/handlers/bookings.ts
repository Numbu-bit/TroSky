import type { Schemas } from '@/api/types'
import { hasAny, type Permission } from '@/lib/permissions'

import type { DemoAccount } from '../accounts'
import { DAY, getDb, index, touch } from '../db'
import { postToWallet, walletFor } from '../db/extras'
import type { BookingRec, PaymentRec } from '../db/model'
import { csvAnswer, endpoint, errorResponse, notFound, paginate } from '../http'
import { Random } from '../random'
import {
  booking as bookingView,
  money,
  payment as paymentView,
  refundRequest,
  withdrawal as withdrawalView,
} from '../views'

const ids = new Random(6161)
const TERMINAL = new Set(['cancelled', 'expired', 'completed', 'refunded'])

const holds = (admin: DemoAccount, ...permissions: Permission[]) =>
  hasAny(new Set(admin.permissions), permissions)

const invalid = (message: string) => errorResponse(409, 'INVALID_STATE_TRANSITION', message)

function list(value: string | null): string[] {
  return (value ?? '')
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean)
}

/** TroSky's own payment reference (the demo derives it from the id). */
export const paymentReference = (payment: PaymentRec) =>
  `PAY-${payment.id.replace(/-/g, '').slice(0, 10).toUpperCase()}`

export function adminPayment(payment: PaymentRec): Schemas['AdminPaymentResponse'] {
  const { bookings, trips, routes, users } = index()
  const booking = payment.booking_id ? bookings.get(payment.booking_id) : undefined
  const trip = booking ? trips.get(booking.trip_id) : undefined
  const payer = users.get(payment.user_id)
  return {
    id: payment.id,
    reference: paymentReference(payment),
    provider_reference: payment.provider_reference,
    purpose: payment.purpose,
    method: payment.channel,
    status: payment.status,
    amount: money(payment.amount),
    platform_fee: booking ? money(booking.platform_fee) : null,
    refunded_amount: money(payment.refunded_amount),
    currency: 'GHS',
    failure_reason: payment.failure_reason,
    booking: booking ? { id: booking.id, reference: booking.reference } : null,
    payer: {
      id: payment.user_id,
      name: payer?.full_name ?? null,
      phone_number: payer?.phone_number ?? '',
    },
    route_name: trip ? (routes.get(trip.route_id)?.name ?? null) : null,
    created_at: payment.created_at,
    completed_at: payment.completed_at,
  }
}

/** One ticket per seat once the booking is paid (the QR token is never shown). */
function tickets(booking: BookingRec): Schemas['TicketResponse'][] {
  if (['awaiting_acceptance', 'pending', 'payment_pending', 'expired'].includes(booking.status)) {
    return []
  }
  const trip = index().trips.get(booking.trip_id)!
  const issued = Date.parse(booking.created_at) + 5 * 60_000
  return booking.passengers.map((passenger) => {
    const revoked = ['cancelled', 'refund_pending', 'refunded'].includes(booking.status)
    const status: Schemas['TicketStatus'] = passenger.boarded_at
      ? 'validated'
      : revoked
        ? 'revoked'
        : trip.status === 'completed' || trip.status === 'cancelled'
          ? 'expired'
          : 'issued'
    return {
      id: `${passenger.id.slice(0, 24)}${booking.id.slice(24)}`,
      ticket_reference: `TKT-${booking.reference.slice(4)}-${passenger.seat_label}`,
      booking_id: booking.id,
      booking_passenger_id: passenger.id,
      trip_id: booking.trip_id,
      status,
      issued_at: new Date(issued).toISOString(),
      expires_at: trip.scheduled_arrival_at,
      validated_at: passenger.boarded_at,
      qr_token: 'demo-qr-token-not-for-display',
    }
  })
}

/** A refund request for a paid booking now waiting for its money back. */
function openRefund(booking: BookingRec, requestedBy: string | null) {
  const db = getDb()
  if (booking.status !== 'refund_pending') return
  const payment = (index().paymentsByBooking.get(booking.id) ?? []).find(
    (candidate) => candidate.status === 'successful' || candidate.status === 'partially_refunded',
  )
  if (!payment) return
  const existing = db.refunds.find(
    (refund) =>
      refund.payment_id === payment.id &&
      (refund.status === 'pending' || refund.status === 'approved'),
  )
  if (existing) return
  db.refunds.push({
    id: ids.uuid(),
    payment_id: payment.id,
    booking_id: booking.id,
    amount: Math.round((payment.amount - payment.refunded_amount) * 100) / 100,
    reason: 'Booking cancelled before departure.',
    status: 'pending',
    reviewed_by: null,
    reviewed_at: null,
    decision_notes: null,
    provider_refund_reference: null,
    failure_reason: null,
    created_at: new Date().toISOString(),
  })
  void requestedBy
}

export const bookingHandlers = [
  // ---------------------------------------------------------- bookings
  endpoint.get('/admin/bookings', ['bookings:view_any'], ({ url }) => {
    const status = url.searchParams.get('booking_status')
    const rows = getDb()
      .bookings.filter((booking) => !status || booking.status === status)
      .sort((a, b) => b.created_at.localeCompare(a.created_at))
    if (url.searchParams.get('format') === 'csv') {
      return csvAnswer(rows.slice(0, 10_000).map(bookingView), 'bookings')
    }
    const page = paginate(rows, url)
    return { ...page, items: page.items.map(bookingView) }
  }),

  endpoint.get('/bookings/:bookingId', 'team', ({ params, admin }) => {
    const booking = index().bookings.get(params.bookingId!)
    if (!booking || !holds(admin, 'bookings:view_any')) return notFound('Booking not found.')
    return bookingView(booking)
  }),

  endpoint.get('/bookings/:bookingId/tickets', 'team', ({ params, admin }) => {
    const booking = index().bookings.get(params.bookingId!)
    if (!booking || !holds(admin, 'bookings:view_any')) return notFound('Booking not found.')
    return tickets(booking)
  }),

  // Admins may cancel anyone's booking (bookings:view_any): decided at
  // once before the trip starts, queued for review after.
  endpoint.post('/bookings/:bookingId/cancel', 'team', ({ params, admin, body }) => {
    const db = getDb()
    const booking = index().bookings.get(params.bookingId!)
    if (!booking || !holds(admin, 'bookings:view_any')) return notFound('Booking not found.')
    if (TERMINAL.has(booking.status)) {
      return invalid(`A booking in status '${booking.status}' cannot be cancelled.`)
    }
    const reason = (body as Schemas['CancelBookingRequest'] | undefined)?.reason ?? null
    const trip = index().trips.get(booking.trip_id)!
    const notStarted = trip.status === 'scheduled'
    const paid = booking.status === 'confirmed'
    const refundEligible = paid && notStarted
    const decideNow = notStarted || booking.status === 'awaiting_acceptance'
    const now = new Date().toISOString()
    db.cancellations.push({
      id: ids.uuid(),
      booking_id: booking.id,
      requested_by: admin.id,
      reason,
      status: decideNow ? 'approved' : 'pending',
      refund_eligible: refundEligible,
      decided_by: decideNow ? admin.id : null,
      decided_at: decideNow ? now : null,
      decision_notes: null,
      created_at: now,
    })
    if (decideNow) {
      for (const offer of db.offers) {
        if (offer.booking_id === booking.id && offer.status === 'pending') {
          offer.status = 'withdrawn'
          offer.decided_at = now
          offer.reason = 'Cancelled by the passenger'
        }
      }
      booking.status = refundEligible ? 'refund_pending' : 'cancelled'
      booking.expires_at = null
      openRefund(booking, admin.id)
    }
    touch()
    return bookingView(booking)
  }),

  // ---------------------------------------------------------- payments
  endpoint.get('/payments/:paymentId', 'team', ({ params, admin }) => {
    const payment = getDb().payments.find((candidate) => candidate.id === params.paymentId)
    if (!payment || !holds(admin, 'payments:review')) return notFound('Payment not found.')
    return paymentView(payment)
  }),

  endpoint.get(
    '/admin/payments',
    ['payments:review', 'refunds:approve', 'reports:view'],
    ({ url }) => {
      const to = url.searchParams.get('to') ?? new Date().toISOString().slice(0, 10)
      const from =
        url.searchParams.get('from') ??
        new Date(Date.parse(`${to}T00:00:00Z`) - 29 * DAY).toISOString().slice(0, 10)
      const methods = list(url.searchParams.get('method'))
      const statuses = list(url.searchParams.get('status'))
      const purposes = list(url.searchParams.get('purpose'))
      const city = url.searchParams.get('city')
      const routeId = url.searchParams.get('route_id')
      const fleetId = url.searchParams.get('fleet_id')
      const q = (url.searchParams.get('q') ?? '').trim().toUpperCase().replace(/\s/g, '')
      const sort = url.searchParams.get('sort') ?? '-created_at'
      const { bookings, trips, routes, vehicles, users } = index()
      const rows = getDb().payments.filter((payment) => {
        const day = payment.created_at.slice(0, 10)
        if (day < from || day > to) return false
        if (methods.length && !methods.includes(payment.channel)) return false
        if (statuses.length && !statuses.includes(payment.status)) return false
        if (purposes.length && !purposes.includes(payment.purpose)) return false
        const booking = payment.booking_id ? bookings.get(payment.booking_id) : undefined
        const trip = booking ? trips.get(booking.trip_id) : undefined
        if (routeId && trip?.route_id !== routeId) return false
        if (city && (trip ? routes.get(trip.route_id)?.city : null) !== city) return false
        if (
          fleetId &&
          (trip?.vehicle_id ? vehicles.get(trip.vehicle_id)?.fleet_id : null) !== fleetId
        ) {
          return false
        }
        if (q) {
          const phone = users.get(payment.user_id)?.phone_number.replace(/\s/g, '') ?? ''
          const local = q.startsWith('0') ? `+233${q.slice(1)}` : q
          if (
            paymentReference(payment) !== q &&
            booking?.reference !== q &&
            phone !== local &&
            phone !== q
          ) {
            return false
          }
        }
        return true
      })
      const key = sort.replace(/^-/, '') as 'created_at' | 'completed_at' | 'amount' | 'status'
      rows.sort((a, b) =>
        key === 'amount'
          ? a.amount - b.amount
          : String(a[key] ?? '').localeCompare(String(b[key] ?? '')),
      )
      if (sort.startsWith('-')) rows.reverse()
      if (url.searchParams.get('format') === 'csv') {
        return csvAnswer(rows.slice(0, 10_000).map(adminPayment), 'payments')
      }
      const page = paginate(rows, url)
      return { ...page, items: page.items.map(adminPayment) }
    },
  ),

  // --------------------------------------------- cancellations & refunds
  endpoint.post(
    '/admin/cancellation-requests/:requestId/review',
    ['refunds:approve'],
    ({ params, admin, body }) => {
      const request = getDb().cancellations.find((candidate) => candidate.id === params.requestId)
      if (!request) return notFound('Cancellation request not found.')
      if (request.status !== 'pending') {
        return invalid(`Cannot review a cancellation request in status '${request.status}'.`)
      }
      const booking = index().bookings.get(request.booking_id)
      if (!booking) return notFound('Booking not found.')
      const decision = body as Schemas['CancellationReviewRequest']
      const refund = decision.approve ? Boolean(decision.refund_eligible) : false
      request.status = decision.approve ? 'approved' : 'rejected'
      request.refund_eligible = refund
      request.decided_by = admin.id
      request.decided_at = new Date().toISOString()
      request.decision_notes = decision.notes ?? null
      if (decision.approve) {
        booking.status = refund ? 'refund_pending' : 'cancelled'
        openRefund(booking, admin.id)
      }
      touch()
      return bookingView(booking)
    },
  ),

  endpoint.post(
    '/admin/refund-requests/:refundId/approve',
    ['refunds:approve'],
    ({ params, admin, body }) => {
      const db = getDb()
      const refund = db.refunds.find((candidate) => candidate.id === params.refundId)
      if (!refund) return notFound('Refund request not found.')
      if (refund.status === 'completed') return refundRequest(refund)
      if (refund.status !== 'pending') {
        return invalid(`Cannot approve a refund request in status '${refund.status}'.`)
      }
      const payment = db.payments.find((candidate) => candidate.id === refund.payment_id)
      if (!payment) return notFound('The payment behind this refund request no longer exists.')
      const refundable = Math.round((payment.amount - payment.refunded_amount) * 100) / 100
      if (refund.amount > refundable) {
        return errorResponse(
          409,
          'REFUND_NOT_ALLOWED',
          'Refund amount exceeds the payment’s refundable balance.',
          {
            refundable: money(refundable),
            requested: money(refund.amount),
          },
        )
      }
      const now = new Date().toISOString()
      refund.reviewed_by = admin.id
      refund.reviewed_at = now
      refund.decision_notes = (body as Schemas['RefundDecisionRequest'] | undefined)?.notes ?? null
      if (payment.channel === 'wallet') {
        postToWallet(payment.user_id, {
          entry_type: 'credit',
          amount: refund.amount,
          reference_type: 'refund',
          reference_id: refund.id,
          description: `Refund for payment ${payment.id.slice(0, 8)}`,
        })
      } else {
        refund.provider_refund_reference = `RF${ids.int(10_000_000, 99_999_999)}`
      }
      refund.status = 'completed'
      payment.refunded_amount = Math.round((payment.refunded_amount + refund.amount) * 100) / 100
      payment.status = payment.refunded_amount >= payment.amount ? 'refunded' : 'partially_refunded'
      const booking = refund.booking_id ? index().bookings.get(refund.booking_id) : undefined
      if (booking?.status === 'refund_pending') booking.status = 'refunded'
      touch()
      return refundRequest(refund)
    },
  ),

  endpoint.post(
    '/admin/refund-requests/:refundId/reject',
    ['refunds:approve'],
    ({ params, admin, body }) => {
      const refund = getDb().refunds.find((candidate) => candidate.id === params.refundId)
      if (!refund) return notFound('Refund request not found.')
      if (refund.status !== 'pending') {
        return invalid(`Cannot reject a refund request in status '${refund.status}'.`)
      }
      refund.status = 'rejected'
      refund.reviewed_by = admin.id
      refund.reviewed_at = new Date().toISOString()
      refund.decision_notes = (body as Schemas['RefundDecisionRequest'] | undefined)?.notes ?? null
      touch()
      return refundRequest(refund)
    },
  ),

  // ------------------------------------------------------------ payouts
  endpoint.get('/wallet/withdrawals/:withdrawalId', 'team', ({ params, admin }) => {
    const payout = getDb().withdrawals.find((candidate) => candidate.id === params.withdrawalId)
    if (!payout || !holds(admin, 'withdrawals:review'))
      return notFound('Withdrawal request not found.')
    return withdrawalView(payout)
  }),

  endpoint.post(
    '/admin/withdrawals/:withdrawalId/approve',
    ['withdrawals:review'],
    ({ params, admin, body }) => {
      const payout = getDb().withdrawals.find((candidate) => candidate.id === params.withdrawalId)
      if (!payout) return notFound('Withdrawal request not found.')
      if (payout.status !== 'pending') {
        return invalid(`Cannot approve a withdrawal request in status '${payout.status}'.`)
      }
      const wallet = walletFor(payout.user_id)
      if (wallet.frozen_at) {
        return errorResponse(
          403,
          'WALLET_FROZEN',
          'This wallet is frozen. Please contact TroSky support.',
        )
      }
      if (wallet.balance < payout.amount) {
        return errorResponse(
          402,
          'INSUFFICIENT_WALLET_BALANCE',
          'The wallet balance is insufficient for this transaction.',
        )
      }
      postToWallet(payout.user_id, {
        entry_type: 'debit',
        amount: payout.amount,
        reference_type: 'withdrawal',
        reference_id: payout.id,
        description: `Withdrawal to ${payout.destination_phone_number}`,
      })
      const now = new Date().toISOString()
      const notes = (body as Schemas['WithdrawalDecisionRequest'] | undefined)?.notes ?? null
      payout.status = 'approved'
      payout.reviewed_by = admin.id
      payout.reviewed_at = now
      payout.decision_notes = notes
      payout.history.push({ status: 'approved', at: now, by: admin.id, note: notes })
      touch()
      return withdrawalView(payout)
    },
  ),

  endpoint.post(
    '/admin/withdrawals/:withdrawalId/reject',
    ['withdrawals:review'],
    ({ params, admin, body }) => {
      const payout = getDb().withdrawals.find((candidate) => candidate.id === params.withdrawalId)
      if (!payout) return notFound('Withdrawal request not found.')
      if (payout.status !== 'pending') {
        return invalid(`Cannot reject a withdrawal request in status '${payout.status}'.`)
      }
      const now = new Date().toISOString()
      const notes = (body as Schemas['WithdrawalDecisionRequest'] | undefined)?.notes ?? null
      payout.status = 'rejected'
      payout.reviewed_by = admin.id
      payout.reviewed_at = now
      payout.decision_notes = notes
      payout.history.push({ status: 'rejected', at: now, by: admin.id, note: notes })
      touch()
      return withdrawalView(payout)
    },
  ),

  endpoint.post(
    '/admin/withdrawals/:withdrawalId/complete',
    ['withdrawals:review'],
    ({ params, admin, body }) => {
      const payout = getDb().withdrawals.find((candidate) => candidate.id === params.withdrawalId)
      if (!payout) return notFound('Withdrawal request not found.')
      if (payout.status === 'completed') return withdrawalView(payout)
      if (payout.status !== 'approved') {
        return invalid(`Cannot complete a withdrawal request in status '${payout.status}'.`)
      }
      if (walletFor(payout.user_id).frozen_at) {
        return errorResponse(
          403,
          'WALLET_FROZEN',
          'This wallet is frozen. Please contact TroSky support.',
        )
      }
      const reference =
        (body as Schemas['CompleteWithdrawalRequest'] | undefined)?.provider_reference ?? null
      payout.status = 'completed'
      payout.provider_reference = reference
      payout.history.push({
        status: 'completed',
        at: new Date().toISOString(),
        by: admin.id,
        note: reference,
      })
      touch()
      return withdrawalView(payout)
    },
  ),

  endpoint.post(
    '/admin/withdrawals/:withdrawalId/fail',
    ['withdrawals:review'],
    ({ params, admin, body }) => {
      const payout = getDb().withdrawals.find((candidate) => candidate.id === params.withdrawalId)
      if (!payout) return notFound('Withdrawal request not found.')
      if (payout.status !== 'approved') {
        return invalid(`Cannot fail a withdrawal request in status '${payout.status}'.`)
      }
      const reason = (body as Schemas['FailWithdrawalRequest']).reason
      postToWallet(payout.user_id, {
        entry_type: 'credit',
        amount: payout.amount,
        reference_type: 'withdrawal',
        reference_id: payout.id,
        description: `Withdrawal reversal: ${reason}`,
      })
      payout.status = 'failed'
      payout.failure_reason = reason
      payout.history.push({
        status: 'failed',
        at: new Date().toISOString(),
        by: admin.id,
        note: reason,
      })
      touch()
      return withdrawalView(payout)
    },
  ),
]
