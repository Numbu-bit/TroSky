// Loaded up front: the screens these tests open are lazy, and their first
// load would otherwise eat into the tests' own waiting time.
import './MySessionsPage'

import { screen, waitFor, within } from '@testing-library/react'

import { DEMO_PASSWORD } from '@/api/demo/accounts'
import { tokenStore } from '@/api/tokens'
import { ADMIN, renderApp } from '@/test/render'

/** Sign in through the demo API, as the browser would, from two devices. */
async function signInTwice() {
  const signIn = async (agent: string) => {
    const response = await fetch('http://localhost/api/v1/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'User-Agent': agent },
      body: JSON.stringify({ identifier: ADMIN.email, password: DEMO_PASSWORD }),
    })
    return (await response.json()) as { access_token: string; refresh_token: string }
  }
  await signIn('Mozilla/5.0 (Android) Mobile')
  tokenStore.set(await signIn('Mozilla/5.0 (Windows NT 10.0)'))
}

describe('Where you’re signed in', () => {
  it('lists the admin’s devices and signs another one out', async () => {
    await signInTwice()
    const { user } = renderApp('/me/sessions')

    expect(await screen.findByText('This device')).toBeInTheDocument()
    const items = within(screen.getByRole('main')).getAllByRole('listitem')
    expect(items).toHaveLength(3) // the seeded phone, plus two sign-ins

    const other = items.find((item) => within(item).queryByText('Mobile browser'))!
    await user.click(within(other).getByRole('button', { name: 'Sign out' }))
    await user.click(await screen.findByRole('button', { name: 'Sign out' }))

    expect(await screen.findByText('That device is signed out.')).toBeInTheDocument()
    await waitFor(() => expect(screen.queryByText('Mobile browser')).not.toBeInTheDocument())
  })

  it('signs the admin out when they sign out this device', async () => {
    await signInTwice()
    const { user, router } = renderApp('/me/sessions')
    const current = (await screen.findByText('This device')).closest('li')!
    await user.click(within(current).getByRole('button', { name: 'Sign out' }))
    await user.click(await screen.findByRole('button', { name: 'Sign out' }))
    await waitFor(() => expect(router.state.location.pathname).toBe('/login'))
  })
})
