import { ArrowLeft, ShieldAlert, Star, UserRound } from 'lucide-react'
import { Link, useParams } from 'react-router'

import { isApiError } from '@/api/errors'
import { useSession } from '@/app/auth/auth-context'
import { BarList } from '@/components/charts/BarList'
import { DailyChart } from '@/components/charts/DailyChart'
import { SeriesChart } from '@/components/charts/SeriesChart'
import { EmptyState, ErrorState, PageSkeleton } from '@/components/feedback/states'
import { PageHeader, Section } from '@/components/layout/PageHeader'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Facts } from '@/features/approvals/DocumentList'
import { usePeriod } from '@/features/shared/period'
import { PeriodControls } from '@/features/shared/PeriodControls'
import { formatDateTime, formatMoney, formatNumber, formatPercent } from '@/lib/format'

import { SCORE_PARTS, useDriverPerformance } from './api'
import { ScoreBar } from './Leaderboard'

const percent = (value: string | null) => (value === null ? '—' : formatPercent(value))

/** One driver's score, its parts, their days, ratings, reviews and earnings. */
export function DriverPerformancePage() {
  const { driverId = '' } = useParams()
  const { can } = useSession()
  const [period] = usePeriod()
  const performance = useDriverPerformance(driverId, period.from, period.to)
  const back = (
    <Button asChild variant="ghost" size="sm" className="mb-2 -ml-2">
      <Link to="/driver-performance">
        <ArrowLeft aria-hidden /> Driver performance
      </Link>
    </Button>
  )
  if (performance.isPending) return <PageSkeleton />
  if (performance.isError) {
    return (
      <>
        {back}
        {isApiError(performance.error, 404) ? (
          <EmptyState title="Driver not found" description="The link may be wrong or old." />
        ) : (
          <ErrorState error={performance.error} onRetry={() => void performance.refetch()} />
        )}
      </>
    )
  }
  const data = performance.data
  const name = data.full_name ?? 'No name given'
  return (
    <>
      {back}
      <PageHeader
        title={name}
        description={period.label}
        actions={
          <>
            <PeriodControls city={false} />
            {can('drivers:approve') ? (
              <Button asChild variant="outline">
                <Link to={`/driver-ratings?driver=${data.driver_id}`}>
                  <Star aria-hidden /> Ratings
                </Link>
              </Button>
            ) : null}
            {can('drivers:approve', 'trips:monitor_live') ? (
              <Button asChild variant="outline">
                <Link to={`/fleet/drivers/${data.driver_id}`}>
                  <UserRound aria-hidden /> Driver profile
                </Link>
              </Button>
            ) : null}
          </>
        }
      />
      {data.at_risk ? (
        <div
          role="status"
          className="mb-4 rounded-lg border border-danger/30 bg-danger-soft p-3 text-sm text-danger-text"
        >
          <p className="flex items-center gap-2 font-semibold">
            <ShieldAlert className="size-4" aria-hidden /> At risk
          </p>
          <ul className="mt-1 list-disc pl-6">
            {data.at_risk_reasons.map((reason) => (
              <li key={reason.code}>{reason.message}</li>
            ))}
          </ul>
        </div>
      ) : null}
      <div className="mb-6 grid gap-6 lg:grid-cols-3">
        <Card>
          <CardHeader>
            <CardTitle className="text-base">Score</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <p className="figure text-4xl">
              {data.score === null ? '—' : formatNumber(data.score, { decimals: true })}
            </p>
            <ul className="space-y-2 text-sm" aria-label="What the score is made of">
              {SCORE_PARTS.map((part) => {
                const value = data.score_breakdown[part.key]
                return (
                  <li key={part.key} className="grid grid-cols-[9rem_1fr] items-center gap-2">
                    <span>
                      {part.label}{' '}
                      <span className="text-xs text-muted-foreground">({part.weight * 100}%)</span>
                    </span>
                    {value === null ? (
                      <span className="text-muted-foreground">No data yet</span>
                    ) : (
                      <ScoreBar score={value} />
                    )}
                  </li>
                )
              })}
            </ul>
          </CardContent>
        </Card>
        <Card>
          <CardHeader>
            <CardTitle className="text-base">In this period</CardTitle>
          </CardHeader>
          <CardContent>
            <Facts
              rows={[
                [
                  'Trips completed',
                  `${formatNumber(data.trips_completed)} of ${formatNumber(data.trips_assigned)}`,
                ],
                [
                  'Cancelled',
                  `${formatNumber(data.trips_cancelled)} (${percent(data.cancellation_rate)})`,
                ],
                ['Left on time', percent(data.on_time_rate)],
                [
                  'Rating',
                  data.average_rating
                    ? `★ ${data.average_rating} from ${data.rating_count}`
                    : 'No ratings',
                ],
                [
                  'Complaints',
                  `${formatNumber(data.complaints)} (${data.complaints_per_100_trips ?? '—'} per 100 trips)`,
                ],
                [
                  'Tickets scanned',
                  `${formatNumber(data.tickets_scanned)} of ${formatNumber(data.tickets_issued)} (${percent(data.qr_scan_rate)})`,
                ],
              ]}
            />
          </CardContent>
        </Card>
        <Card>
          <CardHeader>
            <CardTitle className="text-base">Earnings</CardTitle>
          </CardHeader>
          <CardContent>
            <Facts
              rows={[
                ['Today', formatMoney(data.earnings.today)],
                ['This week', formatMoney(data.earnings.this_week)],
                ['This month', formatMoney(data.earnings.this_month)],
                ['Payouts waiting', formatMoney(data.earnings.pending_withdrawals)],
              ]}
            />
          </CardContent>
        </Card>
      </div>
      <div className="mb-6 grid gap-6 xl:grid-cols-2">
        <DailyChart
          title="Trips completed"
          description="Day by day"
          points={data.daily.map((day) => ({ date: day.date, value: day.trips_completed }))}
          money={false}
          isFetching={performance.isFetching}
          csvName={`trips-${data.driver_id}`}
        />
        <SeriesChart
          title="Left on time"
          description="Share of the day’s completed trips that left within 5 minutes"
          unit="ratio"
          series={[
            {
              key: 'on_time',
              label: 'Left on time',
              points: data.daily.map((day) => ({
                date: day.date,
                value: Number(day.on_time_rate ?? 0),
              })),
            },
          ]}
          isFetching={performance.isFetching}
          csvName={`on-time-${data.driver_id}`}
        />
      </div>
      <div className="grid gap-6 xl:grid-cols-2">
        <BarList
          title="Ratings given"
          description="How many of each, 1 to 5 stars"
          rows={[...data.rating_distribution].reverse().map((row) => ({
            key: String(row.score),
            label: `${row.score} star${row.score === 1 ? '' : 's'}`,
            value: row.count,
          }))}
          valueLabel="Ratings"
          csvName={`rating-spread-${data.driver_id}`}
        />
        <Section title="Latest reviews">
          {data.recent_reviews.length ? (
            <ul className="space-y-3">
              {data.recent_reviews.map((review) => (
                <li key={review.rating_id} className="rounded-lg border bg-card p-3 text-sm">
                  <p className="flex items-center justify-between gap-2">
                    <span aria-label={`${review.score} out of 5`}>
                      {'★'.repeat(review.score)}
                      <span className="text-muted-foreground">{'★'.repeat(5 - review.score)}</span>
                    </span>
                    <span className="text-xs text-muted-foreground">
                      {formatDateTime(review.created_at)}
                    </span>
                  </p>
                  {review.comment ? (
                    <p className="mt-1 whitespace-pre-wrap">{review.comment}</p>
                  ) : null}
                  <Link to={`/trips/${review.trip_id}`} className="link-inline text-xs">
                    The trip
                  </Link>
                </li>
              ))}
            </ul>
          ) : (
            <p className="text-sm text-muted-foreground">No reviews in this period.</p>
          )}
        </Section>
      </div>
    </>
  )
}
