import type { Schemas } from '@/api/types'

import { Random } from '../random'
import type { DemoDb } from './build'
import { DAY, getDb, HOUR, index, touch } from './index'

/**
 * Per-user records the build doesn't make up front: wallets (with their
 * ledger) and signed-in sessions. Made on first use, deterministically from
 * the user's id, and kept with the demo platform they belong to (a rebuilt
 * platform starts afresh).
 */
export interface WalletTxRec {
  id: string
  entry_type: Schemas['WalletEntryType']
  amount: number
  balance_after: number
  reference_type: Schemas['WalletReferenceType']
  reference_id: string | null
  description: string
  created_at: string
}

export interface WalletRec {
  user_id: string
  balance: number
  frozen_at: string | null
  frozen_reason: string | null
  /** Newest first. */
  transactions: WalletTxRec[]
}

export interface SessionRec {
  id: string
  device_id: string | null
  device_name: string | null
  ip_address: string | null
  user_agent: string | null
  created_at: string
  last_seen_at: string
  revoked_at: string | null
}

interface Extras {
  wallets: Map<string, WalletRec>
  sessions: Map<string, SessionRec[]>
}

const extras = new WeakMap<DemoDb, Extras>()

function state(): Extras {
  const db = getDb()
  let found = extras.get(db)
  if (!found) {
    found = { wallets: new Map(), sessions: new Map() }
    extras.set(db, found)
  }
  return found
}

/** The same numbers for the same user, every time. */
function randomFor(userId: string, salt: number): Random {
  let hash = salt
  for (const character of userId) hash = Math.imul(hash ^ character.charCodeAt(0), 16_777_619)
  return new Random(hash)
}

const iso = (ms: number) => new Date(ms).toISOString()
const round2 = (value: number) => Math.round(value * 100) / 100

const DEVICES = [
  ['Samsung Galaxy A14', 'TroSky/2.4.0 (Android 13; SM-A145F)'],
  ['TECNO Spark 10', 'TroSky/2.4.0 (Android 13; TECNO KI5q)'],
  ['Infinix Hot 30', 'TroSky/2.3.2 (Android 13; Infinix X6831)'],
  ['iPhone 12', 'TroSky/2.4.0 (iOS 17.5; iPhone13,2)'],
  ['itel A70', 'TroSky/2.3.2 (Android 13; itel A665L)'],
  ['Chrome on Windows', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/128.0'],
] as const

/** Sessions a user is signed in with (documentation IP ranges: fictitious). */
export function sessionsFor(userId: string): SessionRec[] {
  const known = state().sessions.get(userId)
  if (known) return known
  const user = index().users.get(userId)
  const random = randomFor(userId, 811)
  const now = getDb().builtAt
  const count = !user || user.is_suspended || !user.is_active ? 0 : random.int(1, 3)
  const sessions: SessionRec[] = Array.from({ length: count }, () => {
    const [device, agent] = random.pick(DEVICES)
    const created = now - random.float(0.5, 40) * DAY
    return {
      id: random.uuid(),
      device_id: `dev-${random.int(100_000, 999_999)}`,
      device_name: device,
      ip_address: `${random.pick(['192.0.2', '198.51.100', '203.0.113'])}.${random.int(2, 250)}`,
      user_agent: agent,
      created_at: iso(created),
      last_seen_at: iso(Math.max(created, now - random.float(0.05, 60) * HOUR)),
      revoked_at: null,
    }
  })
  sessions.sort((a, b) => b.last_seen_at.localeCompare(a.last_seen_at))
  state().sessions.set(userId, sessions)
  return sessions
}

/** Sign a user out everywhere (suspension). */
export function revokeAllSessions(userId: string): number {
  const now = iso(Date.now())
  let revoked = 0
  for (const session of sessionsFor(userId)) {
    if (session.revoked_at) continue
    session.revoked_at = now
    revoked += 1
  }
  if (revoked) touch()
  return revoked
}

/**
 * A user's wallet: a driver's holds trip earnings less payouts; a
 * passenger's, top-ups less wallet payments plus refunds. The ledger
 * always covers the payouts still waiting, so they can be approved.
 */
export function walletFor(userId: string): WalletRec {
  const known = state().wallets.get(userId)
  if (known) return known
  const db = getDb()
  const random = randomFor(userId, 977)
  const now = db.builtAt
  const entries: Omit<WalletTxRec, 'balance_after'>[] = []
  const add = (
    entry_type: WalletTxRec['entry_type'],
    amount: number,
    reference_type: WalletTxRec['reference_type'],
    reference_id: string | null,
    description: string,
    at: number,
  ) =>
    entries.push({
      id: random.uuid(),
      entry_type,
      amount: round2(amount),
      reference_type,
      reference_id,
      description,
      created_at: iso(at),
    })

  const driver = index().driverByUser.get(userId)
  if (driver) {
    const earned = db.trips
      .filter(
        (trip) =>
          trip.driver_id === driver.id &&
          trip.status === 'completed' &&
          Date.parse(trip.scheduled_departure_at) > now - 45 * DAY,
      )
      .slice(-40)
    for (const trip of earned) {
      const fares = (index().bookingsByTrip.get(trip.id) ?? [])
        .filter((booking) => booking.status === 'completed')
        .reduce((sum, booking) => sum + booking.fare_amount, 0)
      if (fares > 0) {
        add(
          'credit',
          fares * 0.9,
          'trip_earning',
          trip.id,
          `Earnings for the ${trip.scheduled_departure_at.slice(11, 16)} trip`,
          Date.parse(trip.actual_arrival_at ?? trip.scheduled_departure_at),
        )
      }
    }
    for (const payout of db.withdrawals.filter((candidate) => candidate.user_id === userId)) {
      if (payout.status === 'pending' || payout.status === 'rejected' || !payout.reviewed_at)
        continue
      const at = Date.parse(payout.reviewed_at)
      add(
        'debit',
        payout.amount,
        'withdrawal',
        payout.id,
        `Withdrawal to ${payout.destination_phone_number}`,
        at,
      )
      if (payout.status === 'failed') {
        add(
          'credit',
          payout.amount,
          'withdrawal',
          payout.id,
          `Withdrawal reversal: ${payout.failure_reason ?? 'failed'}`,
          at + 3 * HOUR,
        )
      }
    }
  } else {
    const topups = random.int(0, 4)
    for (let step = 0; step < topups; step += 1) {
      add(
        'credit',
        random.int(2, 10) * 10,
        'wallet_topup',
        null,
        'Top-up from mobile money',
        now - random.float(2, 80) * DAY,
      )
    }
    for (const paid of db.payments.filter(
      (candidate) =>
        candidate.user_id === userId &&
        candidate.channel === 'wallet' &&
        candidate.status !== 'failed',
    )) {
      const at = Date.parse(paid.completed_at ?? paid.created_at)
      add('debit', paid.amount, 'booking_payment', paid.booking_id, 'Paid for a booking', at)
      // Enough came in before it was spent.
      add(
        'credit',
        Math.ceil(paid.amount / 10) * 10,
        'wallet_topup',
        null,
        'Top-up from mobile money',
        at - random.float(0.1, 3) * DAY,
      )
      if (paid.refunded_amount > 0) {
        add(
          'credit',
          paid.refunded_amount,
          'refund',
          paid.booking_id,
          'Refund for a cancelled booking',
          at + random.float(1, 30) * HOUR,
        )
      }
    }
  }

  entries.sort((a, b) => a.created_at.localeCompare(b.created_at))
  const waiting = db.withdrawals
    .filter((payout) => payout.user_id === userId && payout.status === 'pending')
    .reduce((sum, payout) => sum + payout.amount, 0)
  // Opening credit, so the balance never dips below zero and covers what is waiting.
  let lowest = 0
  let running = 0
  for (const entry of entries) {
    running += entry.entry_type === 'credit' ? entry.amount : -entry.amount
    lowest = Math.min(lowest, running)
  }
  const opening = Math.max(-lowest, waiting - running, 0)
  if (opening > 0) {
    entries.unshift({
      id: random.uuid(),
      entry_type: 'credit',
      amount: round2(opening + random.int(0, 20)),
      reference_type: driver ? 'trip_earning' : 'wallet_topup',
      reference_id: null,
      description: driver ? 'Earnings carried over' : 'Top-up from mobile money',
      created_at: iso(
        Math.min(Date.parse(entries[0]?.created_at ?? iso(now)) - HOUR, now - 50 * DAY),
      ),
    })
  }
  let balance = 0
  const transactions: WalletTxRec[] = entries.map((entry) => {
    balance = round2(balance + (entry.entry_type === 'credit' ? entry.amount : -entry.amount))
    return { ...entry, balance_after: balance }
  })
  const wallet: WalletRec = {
    user_id: userId,
    balance,
    frozen_at: null,
    frozen_reason: null,
    transactions: transactions.reverse(),
  }
  state().wallets.set(userId, wallet)
  return wallet
}

/** Move money in or out of a wallet, as the backend's ledger does. */
export function postToWallet(
  userId: string,
  entry: Omit<WalletTxRec, 'id' | 'balance_after' | 'created_at'>,
): WalletTxRec {
  const wallet = walletFor(userId)
  const amount = round2(entry.amount)
  wallet.balance = round2(wallet.balance + (entry.entry_type === 'credit' ? amount : -amount))
  const record: WalletTxRec = {
    ...entry,
    amount,
    id: randomFor(userId, wallet.transactions.length + 31).uuid(),
    balance_after: wallet.balance,
    created_at: iso(Date.now()),
  }
  wallet.transactions.unshift(record)
  touch()
  return record
}
