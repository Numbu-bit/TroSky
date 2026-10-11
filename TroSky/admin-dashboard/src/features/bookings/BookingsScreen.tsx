import { Navigate, Route, Routes } from 'react-router'

import { useSession } from '@/app/auth/auth-context'
import { NotFoundPage } from '@/app/pages/StatusPages'
import { PageHeader } from '@/components/layout/PageHeader'
import { ScreenTabs } from '@/components/layout/ScreenTabs'
import { useQueueCounts } from '@/features/overview/api'

import { BookingsPanel } from './BookingsPanel'
import { CancellationsPanel } from './CancellationsPanel'
import { RefundsPanel } from './RefundsPanel'

/**
 * Bookings & refunds: every booking (bookings:view_any), and the two
 * queues that move money or seats (refunds:approve).
 */
export default function BookingsScreen() {
  const { can } = useSession()
  const views = can('bookings:view_any')
  const decides = can('refunds:approve')
  const counts = new Map(
    useQueueCounts(['refunds', 'cancellations']).map(({ queue, result }) => [
      queue.key,
      result.data,
    ]),
  )

  return (
    <>
      <PageHeader
        title="Bookings & refunds"
        description="Approving a refund pays the money back at once."
      />
      <ScreenTabs
        label="Bookings & refunds"
        tabs={[
          ...(views ? [{ to: '/bookings', label: 'All bookings', end: true }] : []),
          ...(decides
            ? [
                { to: '/bookings/refunds', label: 'Refunds', count: counts.get('refunds') },
                {
                  to: '/bookings/cancellations',
                  label: 'Cancellations after departure',
                  count: counts.get('cancellations'),
                },
              ]
            : []),
        ]}
      />
      <Routes>
        <Route
          index
          element={views ? <BookingsPanel /> : <Navigate to="/bookings/refunds" replace />}
        />
        {decides ? (
          <>
            <Route path="refunds" element={<RefundsPanel />} />
            <Route path="cancellations" element={<CancellationsPanel />} />
          </>
        ) : null}
        <Route path="*" element={<NotFoundPage />} />
      </Routes>
    </>
  )
}
