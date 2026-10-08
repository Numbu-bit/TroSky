import { buildDemoDb, DAY, HISTORY_DAYS } from './build'
import { getDb, index, resetDemoDb, tripPosition } from './index'

describe('the demo platform', () => {
  const now = Date.parse('2026-10-04T10:00:00Z')
  const db = buildDemoDb(now)

  it('is the same on every build', () => {
    const again = buildDemoDb(now)
    expect(again.trips.map((trip) => trip.id)).toEqual(db.trips.map((trip) => trip.id))
    expect(again.bookings.length).toBe(db.bookings.length)
  })

  it('dates nothing that was done in the future', () => {
    const later = (when: string | null) => when !== null && Date.parse(when) > now
    expect(db.bookings.filter((booking) => later(booking.created_at))).toEqual([])
    expect(db.payments.filter((payment) => later(payment.created_at))).toEqual([])
    expect(db.complaints.filter((complaint) => later(complaint.created_at))).toEqual([])
    expect(db.withdrawals.filter((payout) => later(payout.created_at))).toEqual([])
  })

  it('has a realistic size', () => {
    expect(db.stops).toHaveLength(25)
    expect(db.routes).toHaveLength(20)
    expect(db.drivers.length).toBe(64)
    expect(db.users.filter((user) => user.roles.includes('passenger')).length).toBe(420)
    expect(db.trips.length).toBeGreaterThan(3000)
    expect(db.bookings.length).toBeGreaterThan(10_000)
  })

  it('has buses on the road, and things waiting for an admin', () => {
    const live = db.trips.filter(
      (trip) => trip.status === 'in_progress' || trip.status === 'paused',
    )
    expect(live.length).toBeGreaterThanOrEqual(20)
    expect(db.drivers.filter((driver) => driver.status === 'pending').length).toBe(6)
    expect(db.vehicles.filter((vehicle) => vehicle.status === 'pending').length).toBe(4)
    expect(db.sosAlerts.filter((alert) => alert.status === 'active')).toHaveLength(1)
    expect(db.withdrawals.filter((withdrawal) => withdrawal.status === 'pending')).toHaveLength(6)
    expect(db.refunds.some((refund) => refund.status === 'pending')).toBe(true)
    expect(db.complaints.some((complaint) => complaint.status === 'open')).toBe(true)
  })

  it('pays for every confirmed or completed booking', () => {
    const paid = new Set(
      db.payments
        .filter((payment) => payment.status === 'successful' || payment.status === 'refunded')
        .map((payment) => payment.booking_id),
    )
    const unpaid = db.bookings.filter(
      (booking) => ['confirmed', 'completed'].includes(booking.status) && !paid.has(booking.id),
    )
    expect(unpaid).toHaveLength(0)
  })

  it('keeps every trip within the 90 days of history (and tomorrow)', () => {
    const earliest = Math.floor(now / DAY) * DAY - (HISTORY_DAYS - 1) * DAY
    for (const trip of db.trips) {
      expect(Date.parse(trip.scheduled_departure_at)).toBeGreaterThanOrEqual(earliest - DAY)
      expect(Date.parse(trip.scheduled_departure_at)).toBeLessThan(now + 2 * DAY + DAY)
    }
  })

  it('only uses values the API knows', () => {
    const statuses = new Set(db.bookings.map((booking) => booking.status))
    for (const status of statuses) {
      expect([
        'awaiting_acceptance',
        'pending',
        'payment_pending',
        'confirmed',
        'cancelled',
        'expired',
        'completed',
        'refund_pending',
        'refunded',
      ]).toContain(status)
    }
    expect(new Set(db.vehicles.map((vehicle) => vehicle.vehicle_type))).toEqual(
      new Set(['minibus', 'bus']),
    )
  })
})

describe('live positions', () => {
  afterEach(() => resetDemoDb())

  it('move with the clock along the route, and only for buses on the road', () => {
    const live = getDb().trips.find((trip) => trip.live && trip.status === 'in_progress')!
    const first = tripPosition(live, Date.now())!
    const later = tripPosition(live, Date.now() + 60_000)!
    expect(first).not.toEqual(later)
    expect(first.latitude).toBeGreaterThan(4)
    expect(first.latitude).toBeLessThan(8)
    const done = getDb().trips.find((trip) => trip.status === 'completed')!
    expect(tripPosition(done)).toBeNull()
  })

  it('are indexed for lookups', () => {
    const trip = getDb().trips[0]!
    expect(index().trips.get(trip.id)).toBe(trip)
    expect(index().routes.get(trip.route_id)).toBeDefined()
  })
})
