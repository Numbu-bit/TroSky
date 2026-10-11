import { useQuery } from '@tanstack/react-query'
import {
  Bus,
  CreditCard,
  Route as RouteIcon,
  Search,
  Ticket,
  UserRound,
  Users,
  type LucideIcon,
} from 'lucide-react'
import { useState } from 'react'
import { useNavigate } from 'react-router'

import { api, unwrap } from '@/api/client'
import type { Schemas } from '@/api/types'
import { useSession, type Session } from '@/app/auth/auth-context'
import { Spinner } from '@/components/feedback/states'
import {
  Command,
  CommandEmpty,
  CommandGroup,
  CommandInput,
  CommandItem,
  CommandList,
} from '@/components/ui/command'
import { Dialog, DialogContent, DialogDescription, DialogTitle } from '@/components/ui/dialog'
import { useAccounts } from '@/features/accounts/api'
import { accountStatus, ROLE_NAMES } from '@/features/accounts/labels'
import { humanize, maskPhone } from '@/lib/format'
import { isModuleEnabled } from '@/lib/modules'
import { useDebounced } from '@/lib/use-debounced'

const NO_FILTERS = { role: '', status: '', sort: '' }

type Kind = 'users' | 'drivers' | 'vehicles' | 'trips' | 'bookings' | 'payments'

const KINDS: { kind: Kind; heading: string; icon: LucideIcon }[] = [
  { kind: 'users', heading: 'Accounts', icon: Users },
  { kind: 'drivers', heading: 'Drivers', icon: UserRound },
  { kind: 'vehicles', heading: 'Vehicles', icon: Bus },
  { kind: 'trips', heading: 'Trips', icon: RouteIcon },
  { kind: 'bookings', heading: 'Bookings', icon: Ticket },
  { kind: 'payments', heading: 'Payments', icon: CreditCard },
]

/** Where a search hit opens, if this admin may see it there. */
function target(
  kind: Kind,
  hit: Schemas['SearchHit'],
  can: Session['can'],
): { to: string; state?: unknown } | null {
  switch (kind) {
    case 'users':
      return can('users:manage', 'users:suspend') ? { to: `/accounts/${hit.id}` } : null
    case 'drivers':
      return isModuleEnabled('fleet') && can('drivers:approve', 'trips:monitor_live')
        ? { to: `/fleet/drivers/${hit.id}` }
        : can('drivers:approve')
          ? { to: `/driver-ratings?driver=${hit.id}` }
          : null
    case 'vehicles':
      return isModuleEnabled('fleet') && can('vehicles:approve', 'trips:monitor_live')
        ? { to: `/fleet/vehicles/${hit.id}` }
        : null
    case 'trips':
      return can('trips:manage', 'trips:monitor_live') ? { to: `/trips/${hit.id}` } : null
    case 'bookings':
      return can('bookings:view_any') ? { to: `/bookings?booking=${hit.id}` } : null
    case 'payments':
      // The payment's reference, found again in the revenue transactions
      // (whose period moves to the payment's day).
      return isModuleEnabled('revenue') && can('payments:review', 'refunds:approve', 'reports:view')
        ? { to: '/revenue', state: { search: hit.title, payment: hit.id } }
        : null
  }
}

/** Everything an admin may see (the search module), or accounts alone. */
export default function SearchDialog({
  open,
  setOpen,
  global,
}: {
  open: boolean
  setOpen: (open: boolean) => void
  global: boolean
}) {
  const { can } = useSession()
  const navigate = useNavigate()
  const [text, setText] = useState('')
  const search = useDebounced(text, 300).trim()
  const minimum = global ? 2 : 3
  const ready = search.length >= minimum
  const everything = useQuery({
    queryKey: ['search', search],
    queryFn: () =>
      unwrap(api.GET('/api/v1/admin/search', { params: { query: { q: search, limit: 5 } } })),
    enabled: global && ready && open,
  })
  const accounts = useAccounts(search, NO_FILTERS, 1, 6, !global && ready && open)
  const fetching = global
    ? everything.isFetching && !everything.data
    : accounts.isFetching && !accounts.data

  const go = (to: string, state?: unknown) => {
    setOpen(false)
    setText('')
    navigate(to, state ? { state } : undefined)
  }

  return (
    <Dialog
      open={open}
      onOpenChange={(next) => {
        setOpen(next)
        if (!next) setText('')
      }}
    >
      <DialogContent className="overflow-hidden p-0 sm:max-w-lg" showCloseButton={false}>
        <DialogTitle className="sr-only">{global ? 'Search' : 'Find an account'}</DialogTitle>
        <DialogDescription className="sr-only">
          {global
            ? 'Names, phone numbers, emails, plates, booking or payment references, or ids.'
            : 'Type a phone number, an email or a name.'}
        </DialogDescription>
        {/* cmdk names its input by its own label (aria-labelledby). */}
        <Command
          shouldFilter={false}
          label={global ? 'Search' : 'Phone number, email or name'}
          className="[&_[cmdk-item]]:py-2.5"
        >
          <CommandInput
            value={text}
            onValueChange={setText}
            placeholder={
              global ? 'Name, phone, plate, reference or id' : 'Phone number, email or name'
            }
          />
          <CommandList>
            {!ready ? (
              <p className="px-4 py-6 text-center text-sm text-muted-foreground">
                Type at least {minimum} characters.
              </p>
            ) : fetching ? (
              <div className="flex justify-center py-6">
                <Spinner label="Searching" />
              </div>
            ) : global && everything.data ? (
              <>
                <CommandEmpty>Nothing matches.</CommandEmpty>
                {KINDS.map(({ kind, heading, icon: Icon }) => {
                  const hits = everything.data[kind]
                  if (!hits.length) return null
                  return (
                    <CommandGroup key={kind} heading={heading}>
                      {hits.map((hit) => {
                        const where = target(kind, hit, can)
                        return (
                          <CommandItem
                            key={hit.id}
                            value={`${kind}:${hit.id}`}
                            disabled={!where}
                            onSelect={() => where && go(where.to, where.state)}
                          >
                            <Icon aria-hidden />
                            <span className="min-w-0 flex-1">
                              <span className="block truncate">{hit.title}</span>
                              <span className="block truncate text-xs text-muted-foreground">
                                {kind === 'users' && hit.subtitle
                                  ? maskPhone(hit.subtitle.split(' · ')[0])
                                  : hit.subtitle}
                                {hit.status ? ` · ${humanize(hit.status)}` : ''}
                              </span>
                            </span>
                          </CommandItem>
                        )
                      })}
                    </CommandGroup>
                  )
                })}
              </>
            ) : !global && accounts.data ? (
              <>
                <CommandEmpty>Nobody matches.</CommandEmpty>
                {accounts.data.items.length ? (
                  <CommandGroup heading="Accounts">
                    {accounts.data.items.map((account) => {
                      const status = accountStatus(account)
                      return (
                        <CommandItem
                          key={account.id}
                          value={account.id}
                          onSelect={() => go(`/accounts/${account.id}`)}
                        >
                          <UserRound aria-hidden />
                          <span className="min-w-0 flex-1">
                            <span className="block truncate">
                              {account.full_name ?? 'No name given'}
                            </span>
                            <span className="block truncate text-xs text-muted-foreground">
                              {maskPhone(account.phone_number)} ·{' '}
                              {account.roles.map((role) => ROLE_NAMES[role] ?? role).join(', ')}
                              {status.label !== 'Active' ? ` · ${status.label}` : ''}
                            </span>
                          </span>
                        </CommandItem>
                      )
                    })}
                    {accounts.data.total > accounts.data.items.length ? (
                      <CommandItem value="__all__" onSelect={() => go('/accounts', { search })}>
                        <Search aria-hidden /> See all {accounts.data.total} matches
                      </CommandItem>
                    ) : null}
                  </CommandGroup>
                ) : null}
              </>
            ) : null}
          </CommandList>
        </Command>
      </DialogContent>
    </Dialog>
  )
}
