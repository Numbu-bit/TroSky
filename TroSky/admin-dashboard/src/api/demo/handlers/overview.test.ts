import { resolvePeriod } from './overview'

const at = (query: string) => new URL(`http://localhost/api/v1/admin/reports/overview${query}`)

describe('the overview period', () => {
  it('is the last 30 Ghana days by default, against the 30 before', () => {
    const period = resolvePeriod(at(''))
    if (period instanceof Response) throw new Error('expected a period')
    expect(period.dates).toHaveLength(30)
    expect(period.response.days).toBe(30)
    expect(period.response.to_date).toBe(new Date().toISOString().slice(0, 10))
    expect(period.previous.at(-1)! < period.dates[0]!).toBe(true)
  })

  it('takes a custom range', () => {
    const period = resolvePeriod(at('?from=2026-09-01&to=2026-09-07&city=Accra'))
    if (period instanceof Response) throw new Error('expected a period')
    expect(period.response).toEqual({
      from_date: '2026-09-01',
      to_date: '2026-09-07',
      previous_from_date: '2026-08-25',
      previous_to_date: '2026-08-31',
      days: 7,
      city: 'Accra',
    })
  })

  it('refuses a backwards range or more than 366 days, as the API does', async () => {
    const backwards = resolvePeriod(at('?from=2026-09-07&to=2026-09-01'))
    expect(backwards).toBeInstanceOf(Response)
    expect((backwards as Response).status).toBe(422)
    const long = resolvePeriod(at('?from=2024-01-01&to=2026-01-01'))
    expect((long as Response).status).toBe(422)
    expect(await (long as Response).json()).toMatchObject({ error: { code: 'VALIDATION_ERROR' } })
  })
})
