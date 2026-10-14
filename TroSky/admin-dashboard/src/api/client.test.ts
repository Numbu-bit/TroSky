import { http, HttpResponse } from 'msw'

import { server } from '@/test/server'

import { refreshSession } from './client'
import { tokenStore } from './tokens'

describe('refreshing the session', () => {
  it('can renew after an earlier attempt found no refresh token', async () => {
    // Landing signed out: nothing to refresh.
    expect(await refreshSession()).toBe('ended')

    // Later, signed in: the token is renewed, not refused from memory.
    tokenStore.set({ access_token: 'old', refresh_token: 'demo-refresh.x.y.z' })
    server.use(
      http.post('*/api/v1/auth/refresh', () =>
        HttpResponse.json({
          access_token: 'new-access',
          refresh_token: 'new-refresh',
          token_type: 'bearer',
          expires_in: 900,
          session_id: 's',
        }),
      ),
    )
    expect(await refreshSession()).toBe('renewed')
    expect(tokenStore.access).toBe('new-access')
  })

  it('shares one request between callers, as refresh tokens rotate', async () => {
    tokenStore.set({ access_token: 'old', refresh_token: 'r1' })
    let calls = 0
    server.use(
      http.post('*/api/v1/auth/refresh', async () => {
        calls += 1
        return HttpResponse.json({
          access_token: `a${calls}`,
          refresh_token: `r${calls + 1}`,
          token_type: 'bearer',
          expires_in: 900,
          session_id: 's',
        })
      }),
    )
    const results = await Promise.all([refreshSession(), refreshSession(), refreshSession()])
    expect(results).toEqual(['renewed', 'renewed', 'renewed'])
    expect(calls).toBe(1)
  })

  it('clears the tokens when the refresh token is refused', async () => {
    tokenStore.set({ access_token: 'old', refresh_token: 'revoked' })
    server.use(
      http.post('*/api/v1/auth/refresh', () =>
        HttpResponse.json(
          { error: { code: 'TOKEN_INVALID', message: 'No', details: {} } },
          { status: 401 },
        ),
      ),
    )
    expect(await refreshSession()).toBe('ended')
    expect(tokenStore.refresh).toBeNull()
  })

  it('keeps the tokens when the server cannot be reached', async () => {
    tokenStore.set({ access_token: 'old', refresh_token: 'still-good' })
    server.use(http.post('*/api/v1/auth/refresh', () => HttpResponse.error()))

    expect(await refreshSession()).toBe('unreachable')
    expect(tokenStore.refresh).toBe('still-good')
  })

  // A gateway or server error, or a rate limit, is no verdict on the token.
  it.each([500, 502, 503, 429])('keeps the tokens when the refresh gets a %i', async (status) => {
    tokenStore.set({ access_token: 'old', refresh_token: 'still-good' })
    server.use(
      http.post('*/api/v1/auth/refresh', () => new HttpResponse('Bad Gateway', { status })),
    )

    expect(await refreshSession()).toBe('unreachable')
    expect(tokenStore.refresh).toBe('still-good')
  })
})
