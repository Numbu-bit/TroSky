import { Navigate, Route, Routes } from 'react-router'

import { useSession } from '@/app/auth/auth-context'
import { NotFoundPage } from '@/app/pages/StatusPages'
import { PageHeader } from '@/components/layout/PageHeader'
import { ScreenTabs } from '@/components/layout/ScreenTabs'

import { DriversPanel } from './DriversPanel'
import { FleetsPanel } from './FleetsPanel'
import { DriverPage, FleetPage, VehiclePage } from './RecordPages'
import { VehiclesPanel } from './VehiclesPanel'

/** Every vehicle, driver and fleet (not just those waiting for approval). */
export default function FleetScreen() {
  const { can } = useSession()
  const tabs = [
    {
      to: '/fleet/vehicles',
      label: 'Vehicles',
      show: can('vehicles:approve', 'trips:monitor_live'),
    },
    { to: '/fleet/drivers', label: 'Drivers', show: can('drivers:approve', 'trips:monitor_live') },
    { to: '/fleet/fleets', label: 'Fleets', show: can('vehicles:approve', 'reports:view') },
  ].filter((tab) => tab.show)
  const panel = (element: React.ReactNode) => (
    <>
      <PageHeader
        title="Fleet"
        description="Every vehicle, driver and fleet: what each is doing now, and documents running out."
      />
      <ScreenTabs label="Fleet" tabs={tabs} />
      {element}
    </>
  )
  const allowed = new Set(tabs.map((tab) => tab.to))
  return (
    <Routes>
      <Route index element={tabs[0] ? <Navigate to={tabs[0].to} replace /> : <NotFoundPage />} />
      {allowed.has('/fleet/vehicles') ? (
        <>
          <Route path="vehicles" element={panel(<VehiclesPanel />)} />
          <Route path="vehicles/:vehicleId" element={<VehiclePage />} />
        </>
      ) : null}
      {allowed.has('/fleet/drivers') ? (
        <>
          <Route path="drivers" element={panel(<DriversPanel />)} />
          <Route path="drivers/:driverId" element={<DriverPage />} />
        </>
      ) : null}
      {allowed.has('/fleet/fleets') ? (
        <>
          <Route path="fleets" element={panel(<FleetsPanel />)} />
          <Route path="fleets/:fleetId" element={<FleetPage />} />
        </>
      ) : null}
      <Route path="*" element={<NotFoundPage />} />
    </Routes>
  )
}
