import { useCallback, useMemo } from 'react'
import { useSearchParams } from 'react-router'

/**
 * View state that belongs in the URL (filters, tabs, the page, an open
 * record) so a view can be shared. Only ids and codes go in it -- never
 * phone numbers, emails or names.
 */
export function useUrlState<K extends string>(
  defaults: Record<K, string>,
): [
  Record<K, string>,
  (patch: Partial<Record<K, string | null>>, options?: { keepPage?: boolean }) => void,
] {
  const [params, setParams] = useSearchParams()
  // Call sites pass a fresh literal each render: key on its content.
  const defaultsKey = JSON.stringify(defaults)
  const stable = useMemo(() => JSON.parse(defaultsKey) as Record<K, string>, [defaultsKey])

  const values = useMemo(() => {
    const read = {} as Record<K, string>
    for (const key of Object.keys(stable) as K[]) {
      read[key] = params.get(key) ?? stable[key]
    }
    return read
  }, [params, stable])

  const update = useCallback(
    (patch: Partial<Record<K, string | null>>, { keepPage = false } = {}) => {
      setParams(
        (previous) => {
          const next = new URLSearchParams(previous)
          for (const [key, value] of Object.entries(patch) as [K, string | null | undefined][]) {
            if (value === null || value === undefined || value === '' || value === stable[key]) {
              next.delete(key)
            } else {
              next.set(key, value)
            }
          }
          // A new filter shows its first page.
          if (!keepPage && !('page' in patch)) next.delete('page')
          return next
        },
        { replace: true },
      )
    },
    [setParams, stable],
  )

  return [values, update]
}

export const PAGE_SIZE = 20

/** ``?page=`` (1-based) as the API's limit and offset. */
export function usePage(pageSize = PAGE_SIZE) {
  const [{ page }, update] = useUrlState({ page: '1' })
  const current = Math.max(1, Number(page) || 1)
  return {
    page: current,
    limit: pageSize,
    offset: (current - 1) * pageSize,
    setPage: (next: number) =>
      update({ page: next <= 1 ? null : String(next) }, { keepPage: true }),
  }
}
