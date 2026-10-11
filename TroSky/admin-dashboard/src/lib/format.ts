/**
 * Display formats (brand guide): GH₵1,234.50 · 30 Sept 2026, 14:05 in
 * Africa/Accra · relative time for live data ("8 s ago").
 *
 * Money arrives from the API as decimal strings ("8.00"); it is only ever
 * turned into a number here, for display.
 */

export const TIME_ZONE = 'Africa/Accra'

const money = new Intl.NumberFormat('en-GH', { style: 'currency', currency: 'GHS' })
const integer = new Intl.NumberFormat('en-GH', { maximumFractionDigits: 0 })
const decimal = new Intl.NumberFormat('en-GH', { maximumFractionDigits: 2 })
const percent = new Intl.NumberFormat('en-GH', { style: 'percent', maximumFractionDigits: 1 })

const dateTime = new Intl.DateTimeFormat('en-GB', {
  day: 'numeric',
  month: 'short',
  year: 'numeric',
  hour: '2-digit',
  minute: '2-digit',
  hourCycle: 'h23',
  timeZone: TIME_ZONE,
})
const dateOnly = new Intl.DateTimeFormat('en-GB', {
  day: 'numeric',
  month: 'short',
  year: 'numeric',
  timeZone: TIME_ZONE,
})
const timeOnly = new Intl.DateTimeFormat('en-GB', {
  hour: '2-digit',
  minute: '2-digit',
  hourCycle: 'h23',
  timeZone: TIME_ZONE,
})
const clock = new Intl.DateTimeFormat('en-GB', {
  hour: '2-digit',
  minute: '2-digit',
  second: '2-digit',
  hourCycle: 'h23',
  timeZone: TIME_ZONE,
})
const dayMonth = new Intl.DateTimeFormat('en-GB', {
  day: 'numeric',
  month: 'short',
  timeZone: TIME_ZONE,
})

const EMPTY = '—'

type Amount = string | number | null | undefined
type When = string | number | Date | null | undefined

function toNumber(value: Amount): number | null {
  if (value === null || value === undefined || value === '') return null
  const parsed = typeof value === 'number' ? value : Number(value)
  return Number.isFinite(parsed) ? parsed : null
}

function toDate(value: When): Date | null {
  if (value === null || value === undefined || value === '') return null
  const date = value instanceof Date ? value : new Date(value)
  return Number.isNaN(date.getTime()) ? null : date
}

/** "GH₵1,234.50" */
export function formatMoney(value: Amount): string {
  const amount = toNumber(value)
  return amount === null ? EMPTY : money.format(amount)
}

export function formatNumber(value: Amount, { decimals = false } = {}): string {
  const amount = toNumber(value)
  if (amount === null) return EMPTY
  return (decimals ? decimal : integer).format(amount)
}

/** 0.125 -> "12.5%" */
export function formatPercent(ratio: Amount): string {
  const amount = toNumber(ratio)
  return amount === null ? EMPTY : percent.format(amount)
}

/** "30 Sept 2026, 14:05" (Africa/Accra) */
export function formatDateTime(value: When): string {
  const date = toDate(value)
  return date ? dateTime.format(date) : EMPTY
}

/** "30 Sept 2026" */
export function formatDate(value: When): string {
  const date = toDate(value)
  return date ? dateOnly.format(date) : EMPTY
}

/** "14:05" */
export function formatTime(value: When): string {
  const date = toDate(value)
  return date ? timeOnly.format(date) : EMPTY
}

/** "14:05:09" -- to the second, for replays. */
export function formatClock(value: When): string {
  const date = toDate(value)
  return date ? clock.format(date) : EMPTY
}

/** "30 Sept" */
export function formatDayMonth(value: When): string {
  const date = toDate(value)
  return date ? dayMonth.format(date) : EMPTY
}

/** "8 s ago", "3 min ago", "2 h ago", "5 d ago"; "in 4 min" for the future. */
export function formatRelative(value: When, now: number = Date.now()): string {
  const date = toDate(value)
  if (!date) return EMPTY
  const seconds = Math.round((now - date.getTime()) / 1000)
  const future = seconds < 0
  const span = Math.abs(seconds)
  let text: string
  if (span < 5) return 'just now'
  if (span < 60) text = `${span} s`
  else if (span < 3600) text = `${Math.floor(span / 60)} min`
  else if (span < 86_400) text = `${Math.floor(span / 3600)} h`
  else text = `${Math.floor(span / 86_400)} d`
  return future ? `in ${text}` : `${text} ago`
}

/** 95 -> "1 h 35 min" */
export function formatMinutes(minutes: Amount): string {
  const total = toNumber(minutes)
  if (total === null) return EMPTY
  const rounded = Math.round(total)
  if (rounded < 60) return `${rounded} min`
  const hours = Math.floor(rounded / 60)
  const rest = rounded % 60
  return rest ? `${hours} h ${rest} min` : `${hours} h`
}

/** How long ago, in whole days and hours: an approval's age. */
export function formatAge(value: When, now: number = Date.now()): string {
  const date = toDate(value)
  if (!date) return EMPTY
  const hours = Math.max(0, Math.floor((now - date.getTime()) / 3_600_000))
  if (hours < 1) return 'under 1 h'
  if (hours < 48) return `${hours} h`
  return `${Math.floor(hours / 24)} d`
}

/**
 * "+233 24 ••• 4567": enough to recognise a number, not to call it. Numbers
 * the API already masked are returned as they are.
 */
export function maskPhone(phone: string | null | undefined): string {
  if (!phone) return EMPTY
  if (phone.includes('•') || phone.includes('*')) return phone
  const digits = phone.replace(/[^\d+]/g, '')
  const match = /^\+233(\d{2})\d*(\d{4})$/.exec(digits)
  if (match) return `+233 ${match[1]} ••• ${match[2]}`
  if (digits.length > 6) return `${digits.slice(0, 3)} ••• ${digits.slice(-4)}`
  return '•••'
}

/** "ab•••@trosky.test": the start and the domain, enough to recognise it. */
export function maskEmail(email: string | null | undefined): string {
  if (!email) return EMPTY
  const at = email.lastIndexOf('@')
  if (at < 1) return '•••'
  return `${email.slice(0, Math.min(2, at))}•••${email.slice(at)}`
}

/** "+233 24 123 4567" */
export function formatPhone(phone: string | null | undefined): string {
  if (!phone) return EMPTY
  const match = /^\+233(\d{2})(\d{3})(\d{4})$/.exec(phone.replace(/\s/g, ''))
  return match ? `+233 ${match[1]} ${match[2]} ${match[3]}` : phone
}

/** "trip_cancelled" -> "Trip cancelled" */
export function humanize(value: string | null | undefined): string {
  if (!value) return EMPTY
  const text = value.replace(/[_-]+/g, ' ').trim()
  return text.charAt(0).toUpperCase() + text.slice(1)
}

/** The Accra calendar date of a moment, as YYYY-MM-DD. */
export function accraDateKey(value: When = new Date()): string {
  const date = toDate(value) ?? new Date()
  // Accra is UTC+0 all year (no DST), so its calendar date is the UTC one.
  return date.toISOString().slice(0, 10)
}
