// Loaded up front: the screens these tests open are lazy, and their first
// load would otherwise eat into the tests' own waiting time.
import './LoginPage'
import '@/features/overview/OverviewPage'
import '@/features/team/MySessionsPage'

import { screen, waitFor } from '@testing-library/react'
import { http, HttpResponse } from 'msw'

import { DEMO_PASSWORD } from '@/api/demo/accounts'
import { tokenStore } from '@/api/tokens'
import { ADMIN, renderApp, STAFF, SUPER_ADMIN } from '@/test/render'
import { server } from '@/test/server'

async function signIn(
  user: ReturnType<typeof renderApp>['user'],
  identifier: string,
  password: string,
) {
  await user.type(await screen.findByLabelText('Phone number or email'), identifier)
  await user.type(screen.getByLabelText('Password'), password)
  await user.click(screen.getByRole('button', { name: 'Sign in' }))
}

describe('signing in', () => {
  it('takes an admin from sign-in to the Overview, with every module in the menu', async () => {
    const { user, router } = renderApp('/')
    expect(await screen.findByRole('heading', { name: 'Sign in' })).toBeInTheDocument()

    await signIn(user, ADMIN.email, DEMO_PASSWORD)

    await waitFor(() => expect(router.state.location.pathname).toBe('/overview'))
    expect(await screen.findByRole('link', { name: 'Payouts' })).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'Fraud & risk' })).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'Admin team' })).toBeInTheDocument()
    expect(tokenStore.refresh).toBeTruthy()
  })

  it('shows staff only the screens their permissions open', async () => {
    renderApp('/overview', { as: STAFF })
    const menu = await screen.findByRole('link', { name: 'Complaints' })
    expect(menu).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'Bookings & refunds' })).toBeInTheDocument()
    expect(screen.queryByRole('link', { name: 'Payouts' })).not.toBeInTheDocument()
    expect(screen.queryByRole('link', { name: 'Approvals' })).not.toBeInTheDocument()
    expect(screen.queryByRole('link', { name: 'Admin team' })).not.toBeInTheDocument()
  })

  it('answers a wrong password with the API’s message', async () => {
    const { user } = renderApp('/login')
    await signIn(user, ADMIN.phone_number, 'not-the-password')
    expect(await screen.findByRole('alert')).toHaveTextContent(
      'The provided credentials are incorrect.',
    )
    expect(screen.getByLabelText('Password')).toHaveValue('')
  })

  it('says the server is waking up when signing in takes a while', async () => {
    vi.useFakeTimers({ shouldAdvanceTime: true })
    try {
      // A server asleep on a free plan: no answer for a long time.
      server.use(http.post('*/api/v1/auth/login', () => new Promise<never>(() => {})))
      const { user } = renderApp('/login')
      await signIn(user, ADMIN.email, DEMO_PASSWORD)
      expect(screen.queryByText(/waking up/)).not.toBeInTheDocument()

      await vi.advanceTimersByTimeAsync(6_000)

      const hint = await screen.findByText(
        'The server is waking up. After a quiet spell this can take up to a minute.',
      )
      // In a live region, so screen readers announce it.
      expect(hint.closest('[aria-live="polite"]')).not.toBeNull()
    } finally {
      vi.useRealTimers()
    }
  })

  it('validates the form before sending it', async () => {
    const { user } = renderApp('/login')
    await user.click(await screen.findByRole('button', { name: 'Sign in' }))
    expect(await screen.findByText('Enter your phone number or email.')).toBeInTheDocument()
    expect(screen.getByText('Enter your password.')).toBeInTheDocument()
  })

  it('turns away an account that is not on the admin team', async () => {
    server.use(
      http.get('*/api/v1/admin/me', () =>
        HttpResponse.json(
          { error: { code: 'FORBIDDEN', message: 'Forbidden', details: {}, request_id: 'x' } },
          { status: 403 },
        ),
      ),
    )
    const { user } = renderApp('/login')
    await signIn(user, ADMIN.email, DEMO_PASSWORD)
    expect(await screen.findByRole('alert')).toHaveTextContent(
      'This account isn’t on the TroSky admin team.',
    )
    expect(tokenStore.access).toBeNull()
  })
})

describe('guarded pages', () => {
  it('send a signed-out admin to sign in, then back to where they were', async () => {
    const { user, router } = renderApp('/me/sessions')
    await waitFor(() => expect(router.state.location.pathname).toBe('/login'))
    expect(router.state.location.search).toBe(`?next=${encodeURIComponent('/me/sessions')}`)

    await signIn(user, SUPER_ADMIN.email, DEMO_PASSWORD)

    await waitFor(() => expect(router.state.location.pathname).toBe('/me/sessions'))
  })

  it('say “no access” when the permission is missing', async () => {
    renderApp('/payouts', { as: STAFF })
    expect(
      await screen.findByRole('heading', { name: 'You don’t have access to this page' }),
    ).toBeInTheDocument()
  })

  it('say “not found” for an unknown page', async () => {
    renderApp('/no-such-page', { as: ADMIN })
    expect(await screen.findByRole('heading', { name: 'Page not found' })).toBeInTheDocument()
  })
})

describe('an ended session', () => {
  it('signs the admin out with a way back once the token cannot be renewed', async () => {
    const { router } = renderApp('/overview', { as: ADMIN })
    expect(await screen.findByRole('heading', { name: 'Overview' })).toBeInTheDocument()

    // The access token is now refused, and so is the refresh token.
    server.use(
      http.get('*/api/v1/admin/me/sessions', () =>
        HttpResponse.json(
          { error: { code: 'UNAUTHORIZED', message: 'Expired', details: {}, request_id: 'x' } },
          { status: 401 },
        ),
      ),
      http.post('*/api/v1/auth/refresh', () =>
        HttpResponse.json(
          { error: { code: 'TOKEN_INVALID', message: 'Expired', details: {}, request_id: 'y' } },
          { status: 401 },
        ),
      ),
    )
    tokenStore.set({ access_token: 'stale', refresh_token: 'stale-refresh' })
    await router.navigate('/me/sessions')

    await waitFor(() => expect(router.state.location.pathname).toBe('/login'))
    expect(router.state.location.search).toContain(encodeURIComponent('/me/sessions'))
    expect(await screen.findByText(/Your session ended/)).toBeInTheDocument()
  })

  it('carries on unnoticed when the token is renewed', async () => {
    const { router } = renderApp('/overview', { as: ADMIN })
    await screen.findByRole('heading', { name: 'Overview' })
    // A spent access token: the refresh token still works, so the request
    // is retried with a new one.
    let refused = false
    server.use(
      http.get('*/api/v1/admin/me/sessions', ({ request }) => {
        if (!refused && request.headers.get('Authorization') === 'Bearer spent') {
          refused = true
          return HttpResponse.json(
            { error: { code: 'UNAUTHORIZED', message: 'Expired', details: {}, request_id: 'x' } },
            { status: 401 },
          )
        }
        return undefined
      }),
    )
    // A real refresh token for a real demo session: sign in through the API.
    const login = await fetch('http://localhost/api/v1/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ identifier: ADMIN.email, password: DEMO_PASSWORD }),
    })
    const pair = (await login.json()) as { refresh_token: string }
    tokenStore.set({ access_token: 'spent', refresh_token: pair.refresh_token })

    await router.navigate('/me/sessions')

    expect(
      await screen.findByRole('heading', { name: 'Where you’re signed in' }),
    ).toBeInTheDocument()
    expect(refused).toBe(true)
    expect(router.state.location.pathname).toBe('/me/sessions')
  })
})

describe('signing out', () => {
  it('ends the session and returns to sign-in', async () => {
    const { user, router } = renderApp('/overview', { as: SUPER_ADMIN })
    await user.click(await screen.findByRole('button', { name: 'Your account' }))
    await user.click(await screen.findByRole('menuitem', { name: 'Sign out' }))
    await waitFor(() => expect(router.state.location.pathname).toBe('/login'))
    expect(router.state.location.search).toBe('')
    expect(tokenStore.refresh).toBeNull()
  })
})
