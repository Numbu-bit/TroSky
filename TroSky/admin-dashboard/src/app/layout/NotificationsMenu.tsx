import { Bell, ChevronRight } from 'lucide-react'
import { Link } from 'react-router'

import { Spinner } from '@/components/feedback/states'
import { Button } from '@/components/ui/button'
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover'
import { useQueueCounts } from '@/features/overview/api'
import { formatNumber } from '@/lib/format'
import { cn } from '@/lib/utils'

/** What is waiting on this admin, from the queues' own list endpoints. */
export function NotificationsMenu() {
  const queues = useQueueCounts()
  if (queues.length === 0) return null
  const total = queues.reduce((sum, { result }) => sum + (result.data ?? 0), 0)
  const urgent = queues.some(({ queue, result }) => queue.urgent && (result.data ?? 0) > 0)
  return (
    <Popover>
      <PopoverTrigger asChild>
        <Button
          variant="ghost"
          size="icon"
          className="relative"
          aria-label={total ? `${total} items waiting for you` : 'Nothing waiting for you'}
        >
          <Bell aria-hidden />
          {total > 0 ? (
            <span
              className={cn(
                'absolute -top-0.5 -right-0.5 min-w-4 rounded-full px-1 text-center text-[10px] leading-4 font-bold',
                urgent ? 'bg-danger text-danger-foreground' : 'bg-gold text-gold-foreground',
              )}
              aria-hidden
            >
              {total > 99 ? '99+' : total}
            </span>
          ) : null}
        </Button>
      </PopoverTrigger>
      <PopoverContent align="end" className="w-80 p-0">
        <p className="border-b px-4 py-2 text-sm font-semibold">Waiting for you</p>
        <ul className="py-1">
          {queues.map(({ queue, result }) => (
            <li key={queue.key}>
              <Link
                to={queue.to}
                className="flex items-center justify-between gap-3 px-4 py-2 text-sm hover:bg-accent focus-visible:bg-accent focus-visible:outline-none"
              >
                <span>{queue.label}</span>
                <span className="flex items-center gap-1">
                  {result.isPending ? (
                    <Spinner label={`Counting ${queue.label}`} />
                  ) : result.isError ? (
                    <span className="text-xs text-muted-foreground">unavailable</span>
                  ) : (
                    <span
                      className={cn(
                        'figure rounded-full px-2 py-0.5 text-xs',
                        (result.data ?? 0) > 0
                          ? queue.urgent
                            ? 'bg-danger text-danger-foreground'
                            : 'bg-muted font-semibold'
                          : 'text-muted-foreground',
                      )}
                    >
                      {formatNumber(result.data ?? 0)}
                    </span>
                  )}
                  <ChevronRight className="size-4 text-muted-foreground" aria-hidden />
                </span>
              </Link>
            </li>
          ))}
        </ul>
      </PopoverContent>
    </Popover>
  )
}
