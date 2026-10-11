import { ArrowLeft, BadgeCheck, Bus, UserRound } from 'lucide-react'
import { Link } from 'react-router'

import { useSession } from '@/app/auth/auth-context'
import { EmptyState, QueryState, TableSkeleton } from '@/components/feedback/states'
import { PageHeader } from '@/components/layout/PageHeader'
import { ScreenTabs } from '@/components/layout/ScreenTabs'
import { Button } from '@/components/ui/button'
import { formatAge, humanize } from '@/lib/format'
import { useUrlState } from '@/lib/url-state'
import { useMediaQuery } from '@/lib/use-media-query'
import { useNow } from '@/lib/use-now'
import { cn } from '@/lib/utils'

import { usePendingDrivers, usePendingVehicles, type QueueKind } from './api'
import { Review } from './Review'

interface QueueItem {
  id: string
  title: string
  detail: string
  createdAt: string
}

const DAY = 86_400_000

function ageTone(createdAt: string, now: number) {
  const days = (now - Date.parse(createdAt)) / DAY
  return days >= 5 ? 'text-danger-text' : days >= 2 ? 'text-warning-text' : 'text-muted-foreground'
}

function Queue({
  kind,
  items,
  selected,
}: {
  kind: QueueKind
  items: QueueItem[]
  selected: string
}) {
  const now = useNow(60_000)
  const Icon = kind === 'drivers' ? UserRound : Bus
  return (
    <ol
      className="space-y-1"
      aria-label={kind === 'drivers' ? 'Drivers waiting' : 'Vehicles waiting'}
    >
      {items.map((item, position) => {
        const active = item.id === selected
        return (
          <li key={item.id}>
            <Link
              to={`?queue=${kind}&id=${item.id}`}
              aria-current={active ? 'true' : undefined}
              className={cn(
                'flex items-center gap-3 rounded-lg border bg-card px-3 py-2 text-sm transition-colors hover:bg-muted',
                active && 'border-brand ring-2 ring-brand/30',
              )}
            >
              <span className="figure w-5 shrink-0 text-xs text-muted-foreground">
                {position + 1}
              </span>
              <Icon className="size-4 shrink-0 text-muted-foreground" aria-hidden />
              <span className="min-w-0 flex-1">
                <span className="block truncate font-medium">{item.title}</span>
                <span className="block truncate text-xs text-muted-foreground">{item.detail}</span>
              </span>
              <span className={cn('figure shrink-0 text-xs', ageTone(item.createdAt, now))}>
                {formatAge(item.createdAt, now)}
              </span>
            </Link>
          </li>
        )
      })}
    </ol>
  )
}

/**
 * Drivers and vehicles waiting for approval, oldest first. Each review
 * shows the documents beside a checklist; after a decision the next one
 * opens. On narrow screens the queue and the review take turns.
 */
export default function ApprovalsScreen() {
  const { can } = useSession()
  const kinds = (['drivers', 'vehicles'] as const).filter((kind) =>
    can(kind === 'drivers' ? 'drivers:approve' : 'vehicles:approve'),
  )
  const [{ queue, id }, update] = useUrlState({ queue: kinds[0] ?? 'drivers', id: '' })
  const kind: QueueKind = (kinds as readonly string[]).includes(queue)
    ? (queue as QueueKind)
    : (kinds[0] ?? 'drivers')
  const wide = useMediaQuery('(min-width: 1024px)')
  const drivers = usePendingDrivers(kinds.includes('drivers'))
  const vehicles = usePendingVehicles(kinds.includes('vehicles'))

  const items: QueueItem[] =
    kind === 'drivers'
      ? (drivers.data?.items ?? []).map((driver) => ({
          id: driver.id,
          title: driver.full_name ?? 'Unnamed applicant',
          detail: `Licence ${driver.license_number}`,
          createdAt: driver.created_at,
        }))
      : (vehicles.data?.items ?? []).map((vehicle) => ({
          id: vehicle.id,
          title: vehicle.registration_number,
          detail: [
            [vehicle.make, vehicle.model].filter(Boolean).join(' ') ||
              humanize(vehicle.vehicle_type),
            `${vehicle.capacity} seats`,
          ].join(' · '),
          createdAt: vehicle.created_at,
        }))
  const list = kind === 'drivers' ? drivers : vehicles
  const queueState = {
    data: list.data ? { total: list.data.total, shown: list.data.items.length } : undefined,
    isPending: list.isPending,
    isError: list.isError,
    error: list.error,
    refetch: list.refetch,
  }
  // On a wide screen the oldest opens by itself; on a phone the queue shows first.
  const selected = id || (wide ? (items[0]?.id ?? '') : '')

  function next() {
    const position = items.findIndex((item) => item.id === selected)
    const following = items[position + 1] ?? items[position - 1]
    update({ queue: kind, id: following && following.id !== selected ? following.id : null })
  }

  const queuePane = (
    <QueryState
      query={queueState}
      skeleton={<TableSkeleton rows={5} columns={2} />}
      isEmpty={(page) => page.shown === 0}
      empty={
        <EmptyState
          icon={BadgeCheck}
          title="Nothing waiting"
          description={`Every ${kind === 'drivers' ? 'driver' : 'vehicle'} application has been decided.`}
        />
      }
    >
      {(page) => (
        <>
          <Queue kind={kind} items={items} selected={selected} />
          {page.total > page.shown ? (
            <p className="mt-2 text-xs text-muted-foreground">
              Showing the oldest {page.shown} of {page.total}.
            </p>
          ) : null}
        </>
      )}
    </QueryState>
  )

  return (
    <>
      <PageHeader
        title="Approvals"
        description="Only approved drivers and vehicles can be put on trips. Oldest applications first."
      />
      <ScreenTabs
        label="Queues"
        tabs={kinds.map((option) => ({
          to: `?queue=${option}`,
          label: option === 'drivers' ? 'Drivers' : 'Vehicles',
          count: (option === 'drivers' ? drivers : vehicles).data?.total,
          active: option === kind,
        }))}
      />
      {wide ? (
        <div className="grid grid-cols-[18rem_1fr] gap-6">
          <div>{queuePane}</div>
          <div>
            {selected ? (
              <Review kind={kind} id={selected} onDecided={next} />
            ) : queueState.data?.shown === 0 ? null : (
              <EmptyState title="Choose an application" />
            )}
          </div>
        </div>
      ) : selected ? (
        <div className="space-y-3">
          <Button variant="ghost" size="sm" className="-ml-2" onClick={() => update({ id: null })}>
            <ArrowLeft aria-hidden /> Back to the queue
          </Button>
          <Review kind={kind} id={selected} onDecided={next} />
        </div>
      ) : (
        queuePane
      )}
    </>
  )
}
