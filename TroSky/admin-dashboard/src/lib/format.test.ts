import {
  accraDateKey,
  formatAge,
  formatDate,
  formatDateTime,
  formatMinutes,
  formatMoney,
  formatNumber,
  formatPercent,
  formatPhone,
  formatRelative,
  formatTime,
  humanize,
  maskEmail,
  maskPhone,
} from './format'

describe('money', () => {
  it('is in Ghana cedis, from the API’s decimal strings', () => {
    expect(formatMoney('1234.5')).toBe('GH₵1,234.50')
    expect(formatMoney(8)).toBe('GH₵8.00')
    expect(formatMoney('-20.00')).toBe('-GH₵20.00')
  })

  it('shows a dash when there is no amount', () => {
    expect(formatMoney(null)).toBe('—')
    expect(formatMoney('')).toBe('—')
    expect(formatMoney('not a number')).toBe('—')
  })
})

describe('dates and times', () => {
  const when = '2026-09-30T14:05:00Z'

  it('use the brand formats in Africa/Accra', () => {
    expect(formatDateTime(when)).toBe('30 Sept 2026, 14:05')
    expect(formatDate(when)).toBe('30 Sept 2026')
    expect(formatTime(when)).toBe('14:05')
    expect(accraDateKey(when)).toBe('2026-09-30')
  })

  it('describe live data relative to now', () => {
    const now = Date.parse(when)
    expect(formatRelative(now - 2_000, now)).toBe('just now')
    expect(formatRelative(now - 8_000, now)).toBe('8 s ago')
    expect(formatRelative(now - 3 * 60_000, now)).toBe('3 min ago')
    expect(formatRelative(now - 2 * 3_600_000, now)).toBe('2 h ago')
    expect(formatRelative(now - 5 * 86_400_000, now)).toBe('5 d ago')
    expect(formatRelative(now + 4 * 60_000, now)).toBe('in 4 min')
    expect(formatRelative(null, now)).toBe('—')
  })

  it('give durations and ages', () => {
    expect(formatMinutes(45)).toBe('45 min')
    expect(formatMinutes(95)).toBe('1 h 35 min')
    expect(formatMinutes(120)).toBe('2 h')
    const now = Date.parse(when)
    expect(formatAge(now - 30 * 60_000, now)).toBe('under 1 h')
    expect(formatAge(now - 5 * 3_600_000, now)).toBe('5 h')
    expect(formatAge(now - 3 * 86_400_000, now)).toBe('3 d')
  })

  it('ignore what is not a date', () => {
    expect(formatDateTime('yesterday-ish')).toBe('—')
    expect(formatDate(undefined)).toBe('—')
  })
})

describe('numbers', () => {
  it('group thousands and show ratios as percentages', () => {
    expect(formatNumber(1234567)).toBe('1,234,567')
    expect(formatNumber('12.345', { decimals: true })).toBe('12.35')
    expect(formatPercent(0.125)).toBe('12.5%')
  })
})

describe('phone numbers', () => {
  it('are masked enough to recognise, not to call', () => {
    expect(maskPhone('+233241234567')).toBe('+233 24 ••• 4567')
    expect(maskPhone('+23324•••4567')).toBe('+23324•••4567')
    expect(maskPhone(null)).toBe('—')
  })

  it('are spaced for reading in full', () => {
    expect(formatPhone('+233241234567')).toBe('+233 24 123 4567')
    expect(formatPhone('0241234567')).toBe('0241234567')
  })
})

it('turns codes into words', () => {
  expect(humanize('trip_cancelled')).toBe('Trip cancelled')
  expect(humanize('awaiting-acceptance')).toBe('Awaiting acceptance')
  expect(humanize(null)).toBe('—')
})

it('masks emails down to their start and domain', () => {
  expect(maskEmail('abena.owusu@trosky.test')).toBe('ab•••@trosky.test')
  expect(maskEmail('a@trosky.test')).toBe('a•••@trosky.test')
  expect(maskEmail('not-an-email')).toBe('•••')
  expect(maskEmail(null)).toBe('—')
})
