import { ArrowLeft, BarChart3, Star, UserRound } from 'lucide-react'
import { useState, type ReactNode } from 'react'
import { Link, useParams } from 'react-router'

import { isApiError } from '@/api/errors'
import { useSession } from '@/app/auth/auth-context'
import { DataTable } from '@/components/data-table/DataTable'
import { EmptyState, ErrorState, PageSkeleton } from '@/components/feedback/states'
import { PageHeader, Section } from '@/components/layout/PageHeader'
import { StatusBadge } from '@/components/status/StatusBadge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { useDriverDetail, useVehicleDetail } from '@/features/approvals/api'
import { Documents, Expiry, Facts } from '@/features/approvals/DocumentList'
import {
  formatDate,
  formatDateTime,
  formatMoney,
  formatNumber,
  formatPercent,
  formatPhone,
  formatRelative,
  humanize,
  maskEmail,
  maskPhone,
} from '@/lib/format'
import { isModuleEnabled } from '@/lib/modules'
import { useNow } from '@/lib/use-now'

import { useFleet, type Driver, type Vehicle } from './api'
import { APPROVAL, LIVE } from './labels'

function BackLink({ to, label }: { to: string; label: string }) {
  return (
    <Button asChild variant="ghost" size="sm" className="mb-2 -ml-2">
      <Link to={to}>
        <ArrowLeft aria-hidden /> {label}
      </Link>
    </Button>
  )
}

function Failure({
  error,
  retry,
  what,
  back,
}: {
  error: unknown
  retry: () => void
  what: string
  back: ReactNode
}) {
  return (
    <>
      {back}
      {isApiError(error, 404) ? (
        <EmptyState title={`${what} not found`} description="The link may be wrong or old." />
      ) : (
        <ErrorState error={error} onRetry={retry} />
      )}
    </>
  )
}

function Badges({ status, live }: { status: keyof typeof APPROVAL; live: keyof typeof LIVE }) {
  return (
    <span className="inline-flex flex-wrap items-center gap-2">
      <StatusBadge tone={APPROVAL[status].tone} label={APPROVAL[status].label} />
      <StatusBadge tone={LIVE[live].tone} label={LIVE[live].label} icon={LIVE[live].icon} />
    </span>
  )
}

function Reveal({ phone }: { phone: string }) {
  const [shown, setShown] = useState(false)
  return shown ? (
    <a className="figure link-inline" href={`tel:${phone}`}>
      {formatPhone(phone)}
    </a>
  ) : (
    <button
      type="button"
      className="figure link-inline"
      onClick={() => setShown(true)}
      aria-label="Show the full number"
    >
      {maskPhone(phone)}
    </button>
  )
}

/** A vehicle: who owns and drives it, its documents, what it did lately. */
export function VehiclePage() {
  const { vehicleId = '' } = useParams()
  const { can } = useSession()
  const vehicle = useVehicleDetail(vehicleId)
  const now = useNow(60_000)
  const back = <BackLink to="/fleet/vehicles" label="Vehicles" />
  if (vehicle.isPending) return <PageSkeleton />
  if (vehicle.isError) {
    return (
      <Failure
        error={vehicle.error}
        retry={() => void vehicle.refetch()}
        what="Vehicle"
        back={back}
      />
    )
  }
  const data = vehicle.data
  return (
    <>
      {back}
      <PageHeader
        title={data.registration_number}
        description={
          <span className="inline-flex flex-wrap items-center gap-2">
            <span>{data.make_model ?? humanize(data.vehicle_type)}</span>
            <Badges status={data.status} live={data.live_status} />
          </span>
        }
        actions={
          data.current_trip_id ? (
            <Button asChild variant="outline">
              <Link to={`/trips/${data.current_trip_id}`}>Open its trip</Link>
            </Button>
          ) : null
        }
      />
      <div className="grid gap-6 lg:grid-cols-5">
        <div className="space-y-6 lg:col-span-3">
          <Section title="Documents">
            <Documents
              kind="vehicles"
              documents={data.documents}
              owner={data.registration_number}
            />
          </Section>
        </div>
        <div className="space-y-6 lg:col-span-2">
          <Card>
            <CardContent>
              <Facts
                rows={[
                  ['Type', humanize(data.vehicle_type)],
                  ['Year', data.year ?? '—'],
                  ['Seats', data.capacity],
                  [
                    'Fleet',
                    can('vehicles:approve', 'reports:view') ? (
                      <Link className="link-inline" to={`/fleet/fleets/${data.fleet.id}`}>
                        {data.fleet.name}
                      </Link>
                    ) : (
                      (data.fleet.name ?? '—')
                    ),
                  ],
                  ['Owner', data.fleet_owner.name ?? '—'],
                  [
                    'Driver',
                    data.driver ? (
                      <Link className="link-inline" to={`/fleet/drivers/${data.driver.id}`}>
                        {data.driver.name ?? 'Driver'}
                      </Link>
                    ) : (
                      'None'
                    ),
                  ],
                  ['Insurance', <Expiry key="insurance" date={data.insurance_expiry} now={now} />],
                  [
                    'Roadworthy',
                    <Expiry key="roadworthy" date={data.roadworthy_expiry} now={now} />,
                  ],
                  ['Added', formatDate(data.created_at)],
                ]}
              />
            </CardContent>
          </Card>
          <Card>
            <CardHeader>
              <CardTitle className="text-base">Last 30 days</CardTitle>
            </CardHeader>
            <CardContent>
              <Facts
                rows={[
                  ['Trips', formatNumber(data.last_30_days.trips)],
                  ['Completed', formatNumber(data.last_30_days.completed_trips)],
                  ['Fares', formatMoney(data.last_30_days.revenue)],
                ]}
              />
            </CardContent>
          </Card>
          <Section title="Recent incidents">
            {data.recent_incidents.length ? (
              <ul className="space-y-2 text-sm">
                {data.recent_incidents.map((incident) => (
                  <li key={incident.id} className="flex flex-wrap items-center gap-2">
                    <StatusBadge
                      tone={
                        incident.severity === 'critical' || incident.severity === 'high'
                          ? 'danger'
                          : 'warning'
                      }
                      label={humanize(incident.incident_type)}
                    />
                    <span className="text-muted-foreground">
                      {formatDateTime(incident.created_at)}
                    </span>
                    <Link to={`/trips/${incident.trip_id}`} className="link-inline">
                      Trip
                    </Link>
                  </li>
                ))}
              </ul>
            ) : (
              <p className="text-sm text-muted-foreground">None reported.</p>
            )}
          </Section>
        </div>
      </div>
    </>
  )
}

/** A driver: licence, documents, vehicle, and where to see how they do. */
export function DriverPage() {
  const { driverId = '' } = useParams()
  const { can } = useSession()
  const driver = useDriverDetail(driverId)
  const now = useNow(60_000)
  const back = <BackLink to="/fleet/drivers" label="Drivers" />
  if (driver.isPending) return <PageSkeleton />
  if (driver.isError) {
    return (
      <Failure error={driver.error} retry={() => void driver.refetch()} what="Driver" back={back} />
    )
  }
  const data = driver.data
  const name = data.full_name ?? 'No name given'
  return (
    <>
      {back}
      <PageHeader
        title={name}
        description={<Badges status={data.status} live={data.live_status} />}
        actions={
          <>
            {data.current_trip_id ? (
              <Button asChild variant="outline">
                <Link to={`/trips/${data.current_trip_id}`}>Open their trip</Link>
              </Button>
            ) : null}
            {can('drivers:approve') ? (
              <Button asChild variant="outline">
                <Link to={`/driver-ratings?driver=${data.id}`}>
                  <Star aria-hidden /> Ratings
                </Link>
              </Button>
            ) : null}
            {isModuleEnabled('driver-performance') && can('reports:view', 'drivers:approve') ? (
              <Button asChild variant="outline">
                <Link to={`/driver-performance/${data.id}`}>
                  <BarChart3 aria-hidden /> Performance
                </Link>
              </Button>
            ) : null}
            {can('users:manage', 'users:suspend') ? (
              <Button asChild variant="outline">
                <Link to={`/accounts/${data.user_id}`}>
                  <UserRound aria-hidden /> Account
                </Link>
              </Button>
            ) : null}
          </>
        }
      />
      <div className="grid gap-6 lg:grid-cols-5">
        <div className="space-y-6 lg:col-span-3">
          <Section title="Documents">
            <Documents kind="drivers" documents={data.documents} owner={name} />
          </Section>
        </div>
        <Card className="lg:col-span-2">
          <CardContent>
            <Facts
              rows={[
                ['Phone', <Reveal key="phone" phone={data.phone_number} />],
                ['Email', maskEmail(data.email)],
                [
                  'Licence',
                  <span key="licence" className="figure">
                    {data.license_number}
                  </span>,
                ],
                ['Class', data.license_class ?? '—'],
                ['Expires', <Expiry key="expiry" date={data.license_expiry} now={now} />],
                [
                  'Experience',
                  data.years_of_experience !== null ? `${data.years_of_experience} years` : '—',
                ],
                ['Fleet', data.fleet?.name ?? 'Independent'],
                [
                  'Vehicle',
                  data.vehicle ? (
                    <Link className="link-inline" to={`/fleet/vehicles/${data.vehicle.id}`}>
                      {data.vehicle.registration_number}
                    </Link>
                  ) : (
                    'None'
                  ),
                ],
                [
                  'Rating',
                  data.average_rating
                    ? `★ ${data.average_rating} from ${data.rating_count}`
                    : 'None yet',
                ],
                [
                  'Last active',
                  data.last_active_at ? formatRelative(data.last_active_at, now) : 'Never',
                ],
                ['Joined', formatDate(data.created_at)],
              ]}
            />
          </CardContent>
        </Card>
      </div>
    </>
  )
}

/** A fleet: its owner, figures, and its vehicles and drivers. */
export function FleetPage() {
  const { fleetId = '' } = useParams()
  const fleet = useFleet(fleetId)
  const now = useNow(60_000)
  const back = <BackLink to="/fleet/fleets" label="Fleets" />
  if (fleet.isPending) return <PageSkeleton />
  if (fleet.isError) {
    return (
      <Failure error={fleet.error} retry={() => void fleet.refetch()} what="Fleet" back={back} />
    )
  }
  const data = fleet.data
  const live = (row: Vehicle | Driver) => (
    <StatusBadge
      tone={LIVE[row.live_status].tone}
      label={LIVE[row.live_status].label}
      icon={LIVE[row.live_status].icon}
    />
  )
  return (
    <>
      {back}
      <PageHeader
        title={data.name}
        description={
          <span className="inline-flex flex-wrap items-center gap-2">
            <span>{data.owner.business_name}</span>
            <StatusBadge
              tone={APPROVAL[data.owner.status].tone}
              label={`Owner ${APPROVAL[data.owner.status].label.toLowerCase()}`}
            />
          </span>
        }
      />
      <div className="mb-6 grid gap-3 sm:grid-cols-3 lg:grid-cols-6">
        {[
          [
            'Vehicles approved',
            `${formatNumber(data.approved_vehicles)} of ${formatNumber(data.vehicle_count)}`,
          ],
          ['On a trip now', formatNumber(data.active_now)],
          ['Drivers', formatNumber(data.driver_count)],
          ['Used, 7 days', data.utilization_7d === null ? '—' : formatPercent(data.utilization_7d)],
          ['Fares, 30 days', formatMoney(data.revenue_30d)],
          ['Rating', data.average_rating ? `★ ${data.average_rating}` : '—'],
        ].map(([label, value]) => (
          <div key={label} className="rounded-xl border bg-card p-4">
            <p className="text-sm text-muted-foreground">{label}</p>
            <p className="figure mt-1 text-xl">{value}</p>
          </div>
        ))}
      </div>
      <p className="mb-6 text-sm text-muted-foreground">
        Owner: {data.owner.name ?? data.owner.business_name} ·{' '}
        <Reveal phone={data.owner.phone_number} />
      </p>
      <div className="grid gap-6 xl:grid-cols-2">
        <Section title="Vehicles">
          <DataTable<Vehicle>
            caption="The fleet’s vehicles"
            rows={data.vehicles}
            getRowId={(row) => row.id}
            isPending={false}
            isError={false}
            columns={[
              {
                header: 'Plate',
                cell: ({ row }) => (
                  <Link
                    to={`/fleet/vehicles/${row.original.id}`}
                    className="figure font-medium hover:underline"
                  >
                    {row.original.registration_number}
                  </Link>
                ),
              },
              { header: 'Now', cell: ({ row }) => live(row.original) },
              {
                header: 'Insurance',
                cell: ({ row }) => <Expiry date={row.original.insurance_expiry} now={now} />,
              },
              {
                header: 'Status',
                cell: ({ row }) => (
                  <StatusBadge
                    tone={APPROVAL[row.original.status].tone}
                    label={APPROVAL[row.original.status].label}
                  />
                ),
              },
            ]}
            empty={<EmptyState title="No vehicles yet" />}
          />
        </Section>
        <Section title="Drivers">
          <DataTable<Driver>
            caption="The fleet’s drivers"
            rows={data.drivers}
            getRowId={(row) => row.id}
            isPending={false}
            isError={false}
            columns={[
              {
                header: 'Driver',
                cell: ({ row }) => (
                  <Link
                    to={`/fleet/drivers/${row.original.id}`}
                    className="font-medium hover:underline"
                  >
                    {row.original.full_name ?? 'No name given'}
                  </Link>
                ),
              },
              { header: 'Now', cell: ({ row }) => live(row.original) },
              {
                header: 'Licence',
                cell: ({ row }) => <Expiry date={row.original.license_expiry} now={now} />,
              },
              {
                header: 'Rating',
                cell: ({ row }) =>
                  row.original.average_rating ? `★ ${row.original.average_rating}` : '—',
              },
            ]}
            empty={<EmptyState title="No drivers yet" />}
          />
        </Section>
      </div>
    </>
  )
}
