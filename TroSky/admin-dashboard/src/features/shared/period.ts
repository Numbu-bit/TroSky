import { accraDateKey, formatDate } from '@/lib/format'
import { useUrlState } from '@/lib/url-state'

export const CITIES = ['Accra', 'Kumasi', 'Tema', 'Kasoa', 'Cape Coast', 'Takoradi'] as const

export const PRESETS = ['7', '30', '90'] as const

export interface PeriodSelection {
  from: string
  to: string
  city: string
  /** "Last 30 days" or "1 Sept 2026 – 30 Sept 2026". */
  label: string
}

const DAY = 86_400_000

/** The period and city in the URL (?days=30, or ?from=&to=, and ?city=). */
export function usePeriod(): [
  PeriodSelection,
  ReturnType<typeof useUrlState<'days' | 'from' | 'to' | 'city'>>[1],
] {
  const [state, update] = useUrlState({ days: '30', from: '', to: '', city: '' })
  const today = accraDateKey()
  if (state.days === 'custom' && state.from && state.to) {
    return [
      {
        from: state.from,
        to: state.to,
        city: state.city,
        label: `${formatDate(state.from)} – ${formatDate(state.to)}`,
      },
      update,
    ]
  }
  const days = PRESETS.includes(state.days as (typeof PRESETS)[number]) ? Number(state.days) : 30
  return [
    {
      from: accraDateKey(Date.parse(`${today}T00:00:00Z`) - (days - 1) * DAY),
      to: today,
      city: state.city,
      label: `Last ${days} days`,
    },
    update,
  ]
}
