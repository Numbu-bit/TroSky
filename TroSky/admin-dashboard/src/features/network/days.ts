import type { Schemas } from '@/api/types'

export type Day = Schemas['DayOfWeek']

export const DAYS: { value: Day; short: string; label: string }[] = [
  { value: 'monday', short: 'Mon', label: 'Monday' },
  { value: 'tuesday', short: 'Tue', label: 'Tuesday' },
  { value: 'wednesday', short: 'Wed', label: 'Wednesday' },
  { value: 'thursday', short: 'Thu', label: 'Thursday' },
  { value: 'friday', short: 'Fri', label: 'Friday' },
  { value: 'saturday', short: 'Sat', label: 'Saturday' },
  { value: 'sunday', short: 'Sun', label: 'Sunday' },
]

export const WEEKDAYS: Day[] = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday']
export const WEEKEND: Day[] = ['saturday', 'sunday']

/** "Every day", "Mon–Fri", "Weekends" or "Mon, Wed, Fri". */
export function formatDays(days: readonly Day[]): string {
  const set = new Set(days)
  if (set.size === 7) return 'Every day'
  if (set.size === 5 && WEEKDAYS.every((day) => set.has(day))) return 'Mon–Fri'
  if (set.size === 2 && WEEKEND.every((day) => set.has(day))) return 'Weekends'
  return DAYS.filter((day) => set.has(day.value))
    .map((day) => day.short)
    .join(', ')
}
