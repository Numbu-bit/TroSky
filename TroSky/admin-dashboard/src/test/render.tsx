import { QueryClient } from '@tanstack/react-query'
import { render } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { createMemoryRouter, RouterProvider } from 'react-router'
import { onTestFinished } from 'vitest'

import { DEMO_ACCOUNTS, type DemoAccount } from '@/api/demo/accounts'
import { issueTokens } from '@/api/demo/http'
import { tokenStore } from '@/api/tokens'
import { AppProviders } from '@/app/App'
import type { Permission } from '@/lib/permissions'
import { routes } from '@/app/router'

export const [SUPER_ADMIN, ADMIN, STAFF] = DEMO_ACCOUNTS as [DemoAccount, DemoAccount, DemoAccount]

/** A staff account holding just ``permissions``, for this test only. */
export function staffWith(...permissions: Permission[]): DemoAccount {
  const account: DemoAccount = {
    id: `0b6f0f8e-5d0a-4c1e-9a51-${String(Date.now()).slice(-6)}${String(DEMO_ACCOUNTS.length).padStart(6, '0')}`,
    full_name: 'Yaw Test',
    phone_number: '+233240000099',
    email: 'yaw.test@trosky.test',
    role: 'staff',
    permissions,
    summary: 'Test account',
  }
  DEMO_ACCOUNTS.push(account)
  onTestFinished(() => {
    DEMO_ACCOUNTS.splice(DEMO_ACCOUNTS.indexOf(account), 1)
  })
  return account
}

/** Start the test already signed in as ``account`` (a demo admin). */
export function signInAs(account: DemoAccount): void {
  tokenStore.set(issueTokens(account, `5e55a000-0000-4000-8000-${account.id.slice(-12)}`))
}

/** The whole app at ``path``, on a memory router, against the demo API. */
export function renderApp(path = '/', { as }: { as?: DemoAccount } = {}) {
  if (as) signInAs(as)
  const queryClient = new QueryClient({
    defaultOptions: {
      queries: { retry: false, gcTime: Infinity, staleTime: Infinity },
      mutations: { retry: false },
    },
  })
  const router = createMemoryRouter(routes, { initialEntries: [path] })
  const user = userEvent.setup()
  const view = render(
    <AppProviders queryClient={queryClient}>
      <RouterProvider router={router} />
    </AppProviders>,
  )
  return { ...view, router, queryClient, user }
}
