import { Route, Routes } from 'react-router'

import { NotFoundPage } from '@/app/pages/StatusPages'

import { AccountPage } from './AccountPage'
import { AccountsList } from './AccountsList'

export default function AccountsScreen() {
  return (
    <Routes>
      <Route index element={<AccountsList />} />
      <Route path=":userId" element={<AccountPage />} />
      <Route path="*" element={<NotFoundPage />} />
    </Routes>
  )
}
