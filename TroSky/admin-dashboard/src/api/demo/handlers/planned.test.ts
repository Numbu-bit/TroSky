import { api } from '@/api/client'
import { getDb } from '@/api/demo/db'
import { SUPER_ADMIN, signInAs } from '@/test/render'

/** The planned modules' endpoints, in demo mode: each answers, shaped like the API. */
describe('the demo’s planned-module endpoints', () => {
  beforeEach(() => signInAs(SUPER_ADMIN))

  it('list fleets and one fleet with its vehicles and drivers', async () => {
    const { data } = await api.GET('/api/v1/admin/fleets', { params: { query: { limit: 50 } } })
    expect(data!.items.length).toBeGreaterThan(3)
    const fleet = data!.items[0]!
    const detail = await api.GET('/api/v1/admin/fleets/{fleet_id}', {
      params: { path: { fleet_id: fleet.id } },
    })
    expect(detail.data!.vehicles.length).toBe(fleet.vehicle_count)
    const bad = await api.GET('/api/v1/admin/fleets', { params: { query: { sort: 'colour' } } })
    expect(bad.response.status).toBe(422)
  })

  it('score drivers as the backend does, worst first', async () => {
    const { data } = await api.GET('/api/v1/admin/drivers/performance', {
      params: { query: { limit: 100 } },
    })
    const scores = data!.items.filter((row) => row.score !== null).map((row) => Number(row.score))
    expect(scores.length).toBeGreaterThan(10)
    expect([...scores].sort((a, b) => a - b)).toEqual(scores)
    for (const row of data!.items) {
      expect(row.at_risk).toBe(row.at_risk_reasons.length > 0)
    }
    const driver = data!.items[0]!
    const detail = await api.GET('/api/v1/admin/drivers/{driver_id}/performance', {
      params: { path: { driver_id: driver.driver_id } },
    })
    expect(detail.data!.daily).toHaveLength(30)
    expect(detail.data!.rating_distribution.map((row) => row.score)).toEqual([1, 2, 3, 4, 5])
  })

  it('report revenue, users, the funnel and demand for a period', async () => {
    const revenue = await api.GET('/api/v1/admin/analytics/revenue')
    expect(Number(revenue.data!.gross.value)).toBeGreaterThan(0)
    expect(revenue.data!.by_hour).toHaveLength(24)
    expect(Number(revenue.data!.net.value)).toBeCloseTo(
      Number(revenue.data!.gross.value) - Number(revenue.data!.refunds.value),
      1,
    )

    const users = await api.GET('/api/v1/admin/analytics/users')
    expect(users.data!.daily_active).toHaveLength(30)
    expect(users.data!.cohorts.length).toBeGreaterThan(0)

    const funnel = await api.GET('/api/v1/admin/analytics/funnel')
    expect(funnel.data!.stages.map((stage) => stage.stage)).toEqual([
      'searches',
      'reserved',
      'paid',
      'boarded',
    ])
    const values = funnel.data!.stages.map((stage) => stage.value)
    expect([...values].sort((a, b) => b - a)).toEqual(values)

    const demand = await api.GET('/api/v1/admin/analytics/demand', {
      params: { query: { type: 'bookings' } },
    })
    expect(demand.data!.cells.length).toBeGreaterThan(5)
    expect(demand.data!.by_day_and_hour).toHaveLength(7)
    const wrong = await api.GET('/api/v1/admin/analytics/demand', {
      params: { query: { days: 'funday' } },
    })
    expect(wrong.response.status).toBe(422)
  })

  it('give every report its columns, rows and totals', async () => {
    for (const report of [
      'daily_rides',
      'revenue',
      'peak_hours',
      'route_popularity',
      'passenger_growth',
      'cancellation_rates',
    ] as const) {
      const { data } = await api.GET('/api/v1/admin/reports/{report}', {
        params: { path: { report }, query: { granularity: 'week' } },
      })
      expect(data!.columns.length).toBeGreaterThan(3)
      expect(data!.rows.length).toBeGreaterThan(0)
      for (const row of data!.rows) {
        for (const column of data!.columns) expect(row).toHaveProperty(column.key)
      }
    }
  })

  it('review fraud flags: a reason to confirm one, actions on the account', async () => {
    const { data } = await api.GET('/api/v1/admin/fraud/flags', {
      params: { query: { status: 'open,investigating', limit: 50 } },
    })
    const flag = data!.items.find((item) => item.subject_user_id)!
    const refused = await api.PATCH('/api/v1/admin/fraud/flags/{flag_id}', {
      params: { path: { flag_id: flag.id } },
      body: { status: 'confirmed' },
    })
    expect(refused.response.status).toBe(422)
    const frozen = await api.POST('/api/v1/admin/fraud/flags/{flag_id}/actions', {
      params: { path: { flag_id: flag.id } },
      body: { action: 'freeze_wallet', reason: 'Looking into shared numbers.' },
    })
    expect(frozen.response.status).toBe(201)
    const detail = await api.GET('/api/v1/admin/fraud/flags/{flag_id}', {
      params: { path: { flag_id: flag.id } },
    })
    expect(detail.data!.users.find((user) => user.id === flag.subject_user_id)!.wallet_frozen).toBe(
      true,
    )
    expect(detail.data!.timeline.at(-1)!.kind).toBe('action')
    const scan = await api.POST('/api/v1/admin/fraud/scan')
    expect(scan.data!.raised).toBe(1)
  })

  it('record admin actions in the audit log, with what changed', async () => {
    const driver = getDb().drivers.find((candidate) => candidate.status === 'pending')!
    await api.POST('/api/v1/admin/drivers/{driver_id}/approve', {
      params: { path: { driver_id: driver.id } },
      body: {},
    })
    const { data } = await api.GET('/api/v1/admin/audit-logs', {
      params: { query: { entity_id: driver.id } },
    })
    const entry = data!.items[0]!
    expect(entry.action).toBe('approve_driver')
    expect(entry.path).toBe('/api/v1/admin/drivers/{driver_id}/approve')
    expect(entry.before).toMatchObject({ status: 'pending' })
    expect(entry.after).toMatchObject({ status: 'approved' })
    expect(entry.actor_name).toBe(SUPER_ADMIN.full_name)
  })

  it('keep settings within the backend’s limits, and flags platform-wide', async () => {
    const bad = await api.PATCH('/api/v1/admin/settings', {
      body: { reservation_hold_seconds: 30 },
    })
    expect(bad.response.status).toBe(422)
    const good = await api.PATCH('/api/v1/admin/settings', {
      body: { reservation_hold_seconds: 900, reason: 'Slow MoMo.' },
    })
    expect(good.data!.find((setting) => setting.key === 'reservation_hold_seconds')).toMatchObject({
      value: 900,
      overridden: true,
    })
    const reset = await api.PATCH('/api/v1/admin/settings', {
      body: { reservation_hold_seconds: null },
    })
    expect(reset.data!.find((setting) => setting.key === 'reservation_hold_seconds')).toMatchObject(
      { value: 600, overridden: false },
    )
    const flag = await api.PATCH('/api/v1/admin/feature-flags/{key}', {
      params: { path: { key: 'fare_sharing' } },
      body: { rollout_percent: 50 },
    })
    expect(flag.response.status).toBe(422)
  })

  it('adjust a wallet, never below zero', async () => {
    const user = getDb().users.find((candidate) => candidate.roles.includes('passenger'))!
    const before = await api.GET('/api/v1/admin/wallets/{user_id}', {
      params: { path: { user_id: user.id } },
    })
    const balance = Number(before.data!.balance)
    const tooMuch = await api.POST('/api/v1/admin/wallets/{user_id}/adjustments', {
      params: { path: { user_id: user.id } },
      body: {
        direction: 'debit',
        amount: (balance + 10).toFixed(2),
        reason: 'Correcting a double top-up.',
      },
    })
    expect(tooMuch.response.status).toBe(402)
    const credit = await api.POST('/api/v1/admin/wallets/{user_id}/adjustments', {
      params: { path: { user_id: user.id } },
      body: { direction: 'credit', amount: '25.00', reason: 'Goodwill for a broken-down bus.' },
    })
    expect(Number(credit.data!.balance)).toBeCloseTo(balance + 25, 2)
  })

  it('search everything an admin may see', async () => {
    const booking = getDb().bookings[0]!
    const { data } = await api.GET('/api/v1/admin/search', {
      params: { query: { q: booking.reference } },
    })
    expect(data!.bookings[0]!.id).toBe(booking.id)
    expect(data!.searched).toContain('users')
    const short = await api.GET('/api/v1/admin/search', { params: { query: { q: 'a' } } })
    expect(short.response.status).toBe(422)
  })

  it('invite to and change the admin team by the backend’s rules', async () => {
    const added = await api.POST('/api/v1/admin/admins', {
      body: {
        full_name: 'Kofi Annan',
        phone_number: '0240009999',
        role: 'staff',
        permissions: ['reports:view'],
      },
    })
    expect(added.response.status).toBe(201)
    expect(added.data!.member.permissions).toEqual(['reports:view'])
    const again = await api.POST('/api/v1/admin/admins', {
      body: { full_name: 'Kofi Annan', phone_number: '+233240009999', role: 'staff' },
    })
    expect(again.response.status).toBe(409)
    const self = await api.PATCH('/api/v1/admin/admins/{admin_id}', {
      params: { path: { admin_id: SUPER_ADMIN.id } },
      body: { role: 'staff' },
    })
    expect(self.response.status).toBe(403)
    const removed = await api.PATCH('/api/v1/admin/admins/{admin_id}', {
      params: { path: { admin_id: added.data!.member.id } },
      body: { active: false },
    })
    expect(removed.data).toEqual({ on_team: false, member: null })
  })
})
