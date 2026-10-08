import { BellOff } from 'lucide-react'
import { Link } from 'react-router'

import { EmptyState, QueryState } from '@/components/feedback/states'
import { PageHeader } from '@/components/layout/PageHeader'
import { StatusBadge } from '@/components/status/StatusBadge'
import { ToggleGroup, ToggleGroupItem } from '@/components/ui/toggle-group'
import { useAlertsFeed } from '@/features/overview/api'
import { formatNumber, formatRelative, humanize } from '@/lib/format'
import { useUrlState } from '@/lib/url-state'
import { useNow } from '@/lib/use-now'

import { ALERT_TYPES, alertLink, SEVERITY_TONE, type Alert } from './links'

const SEVERITIES = ['critical', 'high', 'medium', 'low'] as const

/**
 * Everything that needs an admin, in one feed: SOS first, then by severity
 * and how long it has waited. Each opens where it is dealt with.
 */
export default function AlertsPage() {
  const [filters, update] = useUrlState({ type: '', severity: '' })
  const feed = useAlertsFeed(true, 200)
  const now = useNow(30_000)
  const types = filters.type ? filters.type.split(',') : []
  const severities = filters.severity ? filters.severity.split(',') : []
  const shown = (alert: Alert) =>
    (!types.length || types.includes(alert.type)) &&
    (!severities.length || severities.includes(alert.severity))

  return (
    <>
      <PageHeader
        title="Alerts"
        description="What needs attention now: open SOS alerts, overdue complaints, documents running out, approvals waiting, high-risk fraud."
      />
      <QueryState
        query={feed}
        isEmpty={(data) => data.total === 0}
        empty={
          <EmptyState
            icon={BellOff}
            title="Nothing needs attention"
            description="When something does, it shows here and in the bell at the top."
          />
        }
      >
        {(data) => {
          const items = data.items.filter(shown)
          return (
            <div className="space-y-4">
              <div className="flex flex-wrap gap-4" role="group" aria-label="Filters">
                <div className="grid gap-1.5">
                  <span className="text-sm font-medium">Kind</span>
                  <ToggleGroup
                    type="multiple"
                    variant="outline"
                    value={types}
                    onValueChange={(value: string[]) => update({ type: value.join(',') || null })}
                    aria-label="Kind of alert"
                    className="flex-wrap"
                  >
                    {(Object.keys(ALERT_TYPES) as Alert['type'][])
                      .filter((type) => type in data.counts)
                      .map((type) => (
                        <ToggleGroupItem key={type} value={type} className="h-auto px-3 py-1.5">
                          {ALERT_TYPES[type]}
                          <span className="figure ml-1 text-muted-foreground">
                            {formatNumber(data.counts[type] ?? 0)}
                          </span>
                        </ToggleGroupItem>
                      ))}
                  </ToggleGroup>
                </div>
                <div className="grid gap-1.5">
                  <span className="text-sm font-medium">Severity</span>
                  <ToggleGroup
                    type="multiple"
                    variant="outline"
                    value={severities}
                    onValueChange={(value: string[]) =>
                      update({ severity: value.join(',') || null })
                    }
                    aria-label="Severity"
                  >
                    {SEVERITIES.map((severity) => (
                      <ToggleGroupItem key={severity} value={severity}>
                        {humanize(severity)}
                      </ToggleGroupItem>
                    ))}
                  </ToggleGroup>
                </div>
              </div>
              {data.total > data.items.length ? (
                <p className="text-xs text-muted-foreground">
                  The {formatNumber(data.items.length)} most urgent of {formatNumber(data.total)}.
                </p>
              ) : null}
              {items.length ? (
                <ul className="divide-y rounded-xl border bg-card" aria-label="Alerts">
                  {items.map((alert) => (
                    <li key={`${alert.type}-${alert.entity_id}`}>
                      <Link
                        to={alertLink(alert)}
                        className="flex flex-wrap items-center gap-3 px-4 py-3 hover:bg-accent focus-visible:bg-accent focus-visible:outline-none"
                      >
                        <StatusBadge
                          tone={SEVERITY_TONE[alert.severity] ?? 'neutral'}
                          label={humanize(alert.severity)}
                        />
                        <span className="min-w-0 flex-1">
                          <span className="block truncate text-sm font-medium">{alert.title}</span>
                          <span className="block text-xs text-muted-foreground">
                            {ALERT_TYPES[alert.type]}
                          </span>
                        </span>
                        <span className="text-xs whitespace-nowrap text-muted-foreground">
                          {alert.type === 'document_expiring'
                            ? `${Date.parse(alert.since) > now ? 'Runs out' : 'Ran out'} ${formatRelative(alert.since, now)}`
                            : formatRelative(alert.since, now)}
                        </span>
                      </Link>
                    </li>
                  ))}
                </ul>
              ) : (
                <EmptyState title="None of this kind" description="Try other filters." />
              )}
            </div>
          )
        }}
      </QueryState>
    </>
  )
}
