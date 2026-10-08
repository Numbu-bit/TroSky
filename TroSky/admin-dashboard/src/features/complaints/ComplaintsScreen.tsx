import { Route, Routes } from 'react-router'

import { NotFoundPage } from '@/app/pages/StatusPages'

import { ComplaintPage } from './ComplaintPage'
import { ComplaintsList } from './ComplaintsList'

export default function ComplaintsScreen() {
  return (
    <Routes>
      <Route index element={<ComplaintsList />} />
      <Route path=":complaintId" element={<ComplaintPage />} />
      <Route path="*" element={<NotFoundPage />} />
    </Routes>
  )
}
