import { Download } from 'lucide-react'
import { useId, useState } from 'react'
import { Navigate, Route, Routes } from 'react-router'
import { toast } from 'sonner'

import { downloadFile } from '@/api/client'
import { errorMessage } from '@/api/errors'
import { useSession } from '@/app/auth/auth-context'
import { PageHeader } from '@/components/layout/PageHeader'
import { ScreenTabs } from '@/components/layout/ScreenTabs'
import { DriverPicker } from '@/components/pickers/pickers'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import { usePage, useUrlState } from '@/lib/url-state'

import { useBookingRequests, useDriverActions, type ActedAs, type ActionKind } from './api'
import { BookingRequests, DriverActionsTable } from './components'
import { ACTED_AS, ACTION_KINDS } from './labels'

const ANY = 'any'

function DriverFilter({
  value,
  onChange,
}: {
  value: string
  onChange: (driverId: string | null) => void
}) {
  const { can } = useSession()
  const id = useId()
  if (!can('drivers:approve', 'trips:monitor_live')) return null
  return (
    <div className="grid gap-1.5">
      <Label htmlFor={id}>Driver</Label>
      <DriverPicker
        id={id}
        value={value || null}
        selectedLabel="The chosen driver"
        onChange={(option) => onChange(option?.value ?? null)}
        placeholder="Every driver"
        allowClear
      />
    </div>
  )
}

function RequestsPanel() {
  const [{ driver }, update] = useUrlState({ driver: '' })
  return (
    <>
      <div
        className="mb-4 grid gap-3 sm:grid-cols-2 lg:grid-cols-4"
        role="group"
        aria-label="Filters"
      >
        <DriverFilter value={driver} onChange={(next) => update({ driver: next })} />
      </div>
      <BookingRequests driverId={driver || undefined} />
    </>
  )
}

function ActionsPanel() {
  const [filters, update] = useUrlState({
    driver: '',
    kind: '',
    actedAs: '',
    since: '',
    until: '',
  })
  const { page, limit, setPage } = usePage(50)
  const actions = useDriverActions(filters, page, limit)
  const [downloading, setDownloading] = useState(false)
  const ids = { kind: useId(), actedAs: useId(), since: useId(), until: useId() }

  async function download() {
    setDownloading(true)
    try {
      await downloadFile(
        '/api/v1/admin/driver-actions',
        {
          format: 'csv',
          driver_id: filters.driver,
          kind: filters.kind,
          acted_as: filters.actedAs,
          since: filters.since ? `${filters.since}T00:00:00Z` : undefined,
          until: filters.until ? `${filters.until}T23:59:59Z` : undefined,
        },
        'driver-actions.csv',
      )
    } catch (error) {
      toast.error(errorMessage(error))
    } finally {
      setDownloading(false)
    }
  }

  return (
    <>
      <div
        className="mb-4 grid gap-3 sm:grid-cols-2 lg:grid-cols-[repeat(5,minmax(0,1fr))_auto] lg:items-end"
        role="group"
        aria-label="Filters"
      >
        <DriverFilter value={filters.driver} onChange={(driver) => update({ driver })} />
        <div className="grid gap-1.5">
          <Label htmlFor={ids.kind}>What</Label>
          <Select
            value={filters.kind || ANY}
            onValueChange={(kind) => update({ kind: kind === ANY ? null : kind })}
          >
            <SelectTrigger id={ids.kind}>
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value={ANY}>Anything</SelectItem>
              {(Object.keys(ACTION_KINDS) as ActionKind[]).map((kind) => (
                <SelectItem key={kind} value={kind}>
                  {ACTION_KINDS[kind].label}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
        <div className="grid gap-1.5">
          <Label htmlFor={ids.actedAs}>Done by</Label>
          <Select
            value={filters.actedAs || ANY}
            onValueChange={(actedAs) => update({ actedAs: actedAs === ANY ? null : actedAs })}
          >
            <SelectTrigger id={ids.actedAs}>
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value={ANY}>Anyone</SelectItem>
              {(Object.keys(ACTED_AS) as ActedAs[]).map((actedAs) => (
                <SelectItem key={actedAs} value={actedAs}>
                  {ACTED_AS[actedAs]}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
        <div className="grid gap-1.5">
          <Label htmlFor={ids.since}>From</Label>
          <Input
            id={ids.since}
            type="date"
            value={filters.since}
            max={filters.until || undefined}
            onChange={(event) => update({ since: event.target.value })}
          />
        </div>
        <div className="grid gap-1.5">
          <Label htmlFor={ids.until}>To</Label>
          <Input
            id={ids.until}
            type="date"
            value={filters.until}
            min={filters.since || undefined}
            onChange={(event) => update({ until: event.target.value })}
          />
        </div>
        <Button variant="outline" onClick={() => void download()} disabled={downloading}>
          <Download aria-hidden /> CSV
        </Button>
      </div>
      <DriverActionsTable
        rows={actions.data?.items}
        total={actions.data?.total}
        page={page}
        pageSize={limit}
        onPageChange={setPage}
        query={actions}
      />
    </>
  )
}

/**
 * Dispatch: bookings waiting for a driver's yes, and everything drivers
 * did (or an admin did for them, or the system did when they didn't).
 */
export default function DispatchPage() {
  const waiting = useBookingRequests()
  return (
    <>
      <PageHeader
        title="Dispatch"
        description="Every booking needs its driver’s yes before the passenger pays. Unanswered ones move to another vehicle going the same way."
      />
      <ScreenTabs
        label="Dispatch"
        tabs={[
          { to: '/dispatch', label: 'Waiting for drivers', end: true, count: waiting.data?.total },
          { to: '/dispatch/actions', label: 'What drivers did' },
        ]}
      />
      <Routes>
        <Route index element={<RequestsPanel />} />
        <Route path="actions" element={<ActionsPanel />} />
        <Route path="*" element={<Navigate to="/dispatch" replace />} />
      </Routes>
    </>
  )
}
