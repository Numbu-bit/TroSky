import { useQuery } from '@tanstack/react-query'
import { Star, UserRound } from 'lucide-react'
import { useId } from 'react'
import { Link } from 'react-router'

import { api, unwrap } from '@/api/client'
import type { Schemas } from '@/api/types'
import { useSession } from '@/app/auth/auth-context'
import { ChartCard } from '@/components/charts/ChartCard'
import { EmptyState, ErrorState } from '@/components/feedback/states'
import { PageHeader } from '@/components/layout/PageHeader'
import { DriverPicker } from '@/components/pickers/pickers'
import { Button } from '@/components/ui/button'
import { Label } from '@/components/ui/label'
import { Skeleton } from '@/components/ui/skeleton'
import { useDriverDetail } from '@/features/approvals/api'
import { formatNumber } from '@/lib/format'
import { isModuleEnabled } from '@/lib/modules'
import { useUrlState } from '@/lib/url-state'

type Summary = Schemas['DriverRatingSummaryResponse']

/** The four things passengers rate, out of 5 (FR-011). */
const CATEGORIES = [
  { key: 'safety_average', label: 'Safety' },
  { key: 'cleanliness_average', label: 'Cleanliness' },
  { key: 'professionalism_average', label: 'Professionalism' },
  { key: 'timeliness_average', label: 'Timeliness' },
] as const

interface Row {
  label: string
  score: number | null
}

function useRatingSummary(driverId: string) {
  return useQuery({
    queryKey: ['driver-ratings', driverId],
    queryFn: () =>
      unwrap(
        api.GET('/api/v1/admin/drivers/{driver_id}/rating-summary', {
          params: { path: { driver_id: driverId } },
        }),
      ),
    enabled: Boolean(driverId),
  })
}

function Stars({ score }: { score: number }) {
  return (
    <span className="inline-flex" role="img" aria-label={`${score.toFixed(1)} out of 5`}>
      {[1, 2, 3, 4, 5].map((step) => (
        <Star
          key={step}
          className={
            score >= step - 0.25
              ? 'size-5 fill-gold text-gold'
              : score >= step - 0.75
                ? 'size-5 fill-gold/50 text-gold'
                : 'size-5 text-muted-foreground'
          }
          aria-hidden
        />
      ))}
    </span>
  )
}

function Ratings({ summary, name }: { summary: Summary; name: string }) {
  if (!summary.rating_count) {
    return (
      <EmptyState
        icon={Star}
        title="No ratings yet"
        description={`Passengers rate ${name} after a completed trip.`}
      />
    )
  }
  const rows: Row[] = CATEGORIES.map((category) => ({
    label: category.label,
    score: summary[category.key] ? Number(summary[category.key]) : null,
  }))
  const overall = summary.average_score ? Number(summary.average_score) : null
  return (
    <div className="grid gap-6 lg:grid-cols-3">
      <div className="rounded-xl border bg-card p-6">
        <p className="text-sm text-muted-foreground">Overall</p>
        <p className="figure mt-1 text-4xl">{overall === null ? '—' : overall.toFixed(2)}</p>
        {overall !== null ? <Stars score={overall} /> : null}
        <p className="mt-2 text-sm text-muted-foreground">
          From {formatNumber(summary.rating_count)} rating{summary.rating_count === 1 ? '' : 's'}
        </p>
      </div>
      <ChartCard
        className="lg:col-span-2"
        title="By what passengers rated"
        description="Average out of 5"
        rows={rows}
        columns={[
          { key: 'label', label: 'Rated for', value: (row) => row.label },
          {
            key: 'score',
            label: 'Average (1-5)',
            value: (row) => (row.score === null ? '' : row.score.toFixed(2)),
            align: 'right',
          },
        ]}
        csvName={`ratings-${name.toLowerCase().replace(/\W+/g, '-')}`}
      >
        <ul className="space-y-3" aria-label="Averages out of 5">
          {rows.map((row) => (
            <li
              key={row.label}
              className="grid grid-cols-[8rem_1fr_3rem] items-center gap-3 text-sm"
            >
              <span>{row.label}</span>
              <span className="h-3 rounded-full bg-muted" aria-hidden>
                <span
                  className="block h-3 rounded-full bg-chart-1"
                  style={{ width: `${((row.score ?? 0) / 5) * 100}%` }}
                />
              </span>
              <span className="figure text-right">
                {row.score === null ? '—' : row.score.toFixed(2)}
              </span>
            </li>
          ))}
        </ul>
      </ChartCard>
    </div>
  )
}

/** A driver's rating summary: overall and per category, out of 5. */
export default function DriverRatingsPage() {
  const { can } = useSession()
  const [{ driver }, update] = useUrlState({ driver: '' })
  const detail = useDriverDetail(driver || null)
  const summary = useRatingSummary(driver)
  const pickerId = useId()
  const name = detail.data?.full_name ?? 'this driver'

  return (
    <>
      <PageHeader
        title="Driver ratings"
        description="What passengers think of a driver: safety, cleanliness, professionalism and timeliness, 1 to 5 stars."
      />
      <div className="mb-6 flex flex-wrap items-end gap-3">
        <div className="grid w-full max-w-sm gap-1.5">
          <Label htmlFor={pickerId}>Driver</Label>
          <DriverPicker
            id={pickerId}
            value={driver || null}
            selectedLabel={detail.data?.full_name ?? undefined}
            onChange={(option) => update({ driver: option?.value ?? null })}
            placeholder="Choose a driver"
          />
        </div>
        {driver && detail.data ? (
          <div className="flex flex-wrap gap-2">
            {can('users:manage', 'users:suspend') ? (
              <Button asChild variant="outline" size="sm">
                <Link to={`/accounts/${detail.data.user_id}`}>
                  <UserRound aria-hidden /> Account
                </Link>
              </Button>
            ) : null}
            {isModuleEnabled('driver-performance') && can('reports:view', 'drivers:approve') ? (
              <Button asChild variant="outline" size="sm">
                <Link to={`/driver-performance/${driver}`}>Performance</Link>
              </Button>
            ) : null}
          </div>
        ) : null}
      </div>
      {!driver ? (
        <EmptyState
          icon={Star}
          title="Choose a driver"
          description="Or open one from a trip, an approval or an account."
        />
      ) : summary.isPending ? (
        <Skeleton className="h-48" />
      ) : summary.isError ? (
        <ErrorState error={summary.error} onRetry={() => void summary.refetch()} />
      ) : (
        <Ratings summary={summary.data} name={name} />
      )}
    </>
  )
}
