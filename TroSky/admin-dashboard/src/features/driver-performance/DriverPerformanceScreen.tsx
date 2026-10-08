import { Route, Routes } from 'react-router'

import { NotFoundPage } from '@/app/pages/StatusPages'

import { DriverPerformancePage } from './DriverPerformancePage'
import { Leaderboard } from './Leaderboard'

export default function DriverPerformanceScreen() {
  return (
    <Routes>
      <Route index element={<Leaderboard />} />
      <Route path=":driverId" element={<DriverPerformancePage />} />
      <Route path="*" element={<NotFoundPage />} />
    </Routes>
  )
}
