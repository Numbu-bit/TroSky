import { Search } from 'lucide-react'
import { lazy, Suspense, useEffect, useState } from 'react'

import { useSession } from '@/app/auth/auth-context'
import { Button } from '@/components/ui/button'
import { isModuleEnabled } from '@/lib/modules'

const SearchDialog = lazy(() => import('./SearchDialog'))

/** Who may use the global search (the API's own list). */
const SEARCHERS = [
  'bookings:view_any',
  'drivers:approve',
  'payments:review',
  'refunds:approve',
  'trips:manage',
  'trips:monitor_live',
  'users:manage',
  'users:suspend',
  'vehicles:approve',
] as const

/**
 * Search from any page (Ctrl+K): everything the admin may see when the
 * search module is on, otherwise accounts by phone, email or name. What
 * is typed is never put in the address.
 */
export function AccountSearch() {
  const { can } = useSession()
  const global = isModuleEnabled('alerts') && can(...SEARCHERS)
  const allowed = global || can('users:manage', 'users:suspend')
  const [open, setOpen] = useState(false)
  // Mounted on first use, then kept, so it opens at once the next time.
  const [used, setUsed] = useState(false)
  const show = (next: boolean) => {
    if (next) setUsed(true)
    setOpen(next)
  }

  useEffect(() => {
    if (!allowed) return
    const onKey = (event: KeyboardEvent) => {
      if (event.key.toLowerCase() === 'k' && (event.ctrlKey || event.metaKey)) {
        event.preventDefault()
        setUsed(true)
        setOpen((current) => !current)
      }
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [allowed])

  if (!allowed) return null

  return (
    <>
      <Button
        variant="outline"
        size="sm"
        className="h-8 gap-2 text-muted-foreground"
        onClick={() => show(true)}
        aria-label={global ? 'Search' : 'Find an account'}
        aria-keyshortcuts="Control+K"
      >
        <Search aria-hidden />
        <span className="hidden lg:inline">{global ? 'Search' : 'Find an account'}</span>
        <kbd className="hidden rounded border bg-muted px-1 text-[10px] lg:inline">Ctrl K</kbd>
      </Button>
      {used ? (
        <Suspense fallback={null}>
          <SearchDialog open={open} setOpen={show} global={global} />
        </Suspense>
      ) : null}
    </>
  )
}
