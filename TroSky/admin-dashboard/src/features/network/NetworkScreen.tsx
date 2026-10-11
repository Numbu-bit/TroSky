import { Route, Routes } from 'react-router'

import { NotFoundPage } from '@/app/pages/StatusPages'
import { PageHeader } from '@/components/layout/PageHeader'
import { ScreenTabs } from '@/components/layout/ScreenTabs'

import { RoutePage } from './RoutePage'
import { RoutesPanel } from './RoutesPanel'
import { StopsPanel } from './StopsPanel'

function NetworkTabs({ children }: { children: React.ReactNode }) {
  return (
    <>
      <PageHeader
        title="Network"
        description="The stops buses call at and the routes through them, with their timetables."
      />
      <ScreenTabs
        label="Network"
        tabs={[
          { to: '/network', label: 'Routes', end: true },
          { to: '/network/stops', label: 'Stops' },
        ]}
      />
      {children}
    </>
  )
}

export default function NetworkScreen() {
  return (
    <Routes>
      <Route
        index
        element={
          <NetworkTabs>
            <RoutesPanel />
          </NetworkTabs>
        }
      />
      <Route
        path="stops"
        element={
          <NetworkTabs>
            <StopsPanel />
          </NetworkTabs>
        }
      />
      <Route path="routes/:routeId" element={<RoutePage />} />
      <Route path="*" element={<NotFoundPage />} />
    </Routes>
  )
}
