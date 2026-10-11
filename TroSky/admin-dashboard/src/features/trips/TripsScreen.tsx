import { Route, Routes } from 'react-router'

import { NotFoundPage } from '@/app/pages/StatusPages'

import { TripPage } from './TripPage'
import { TripsList } from './TripsList'

export default function TripsScreen() {
  return (
    <Routes>
      <Route index element={<TripsList />} />
      <Route path=":tripId" element={<TripPage />} />
      <Route path="*" element={<NotFoundPage />} />
    </Routes>
  )
}
