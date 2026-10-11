import { Navigate, Route, Routes } from 'react-router'

import { useSession } from '@/app/auth/auth-context'
import { NotFoundPage } from '@/app/pages/StatusPages'
import { PageHeader } from '@/components/layout/PageHeader'
import { ScreenTabs } from '@/components/layout/ScreenTabs'
import { usePeriod } from '@/features/shared/period'
import { PeriodControls } from '@/features/shared/PeriodControls'

import { FlagPage } from './FlagPage'
import { FlagsPanel } from './FlagsPanel'
import { RulesPanel } from './RulesPanel'

function Frame({ children }: { children: React.ReactNode }) {
  const { can } = useSession()
  const [period] = usePeriod()
  return (
    <>
      <PageHeader
        title="Fraud & risk"
        description={`What the fraud checks found, and the rules they use. Figures: ${period.label.toLowerCase()}.`}
        actions={<PeriodControls city={false} />}
      />
      <ScreenTabs
        label="Fraud & risk"
        tabs={[
          { to: '/fraud', label: 'Flags', end: true },
          ...(can('fraud:manage') ? [{ to: '/fraud/rules', label: 'Rules' }] : []),
        ]}
      />
      {children}
    </>
  )
}

export default function FraudScreen() {
  const { can } = useSession()
  return (
    <Routes>
      <Route
        index
        element={
          <Frame>
            <FlagsPanel />
          </Frame>
        }
      />
      <Route
        path="rules"
        element={
          can('fraud:manage') ? (
            <Frame>
              <RulesPanel />
            </Frame>
          ) : (
            <Navigate to="/fraud" replace />
          )
        }
      />
      <Route path=":flagId" element={<FlagPage />} />
      <Route path="*" element={<NotFoundPage />} />
    </Routes>
  )
}
