import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { act, render, waitFor } from '@testing-library/react'
import { http, HttpResponse } from 'msw'
import { vi } from 'vitest'

import { tokenStore } from '@/api/tokens'
import { server } from '@/test/server'

import { AuthContext, type AdminMe } from '../auth/auth-context'
import { LiveProvider } from './LiveProvider'

// The stream is only opened against a real backend, never in demo mode.
vi.mock(import('@/lib/env'), async (original) => {
  const actual = await original()
  return { ...actual, env: { ...actual.env, demoMode: false } }
})

/** An EventSource that records each connection and plays the server's part. */
class FakeEventSource {
  static opened: FakeEventSource[] = []
  readonly url: URL
  onopen: (() => void) | null = null
  onerror: (() => void) | null = null
  closed = false
  private readonly listeners = new Map<string, ((event: MessageEvent<string>) => void)[]>()

  constructor(url: string | URL) {
    this.url = new URL(String(url))
    FakeEventSource.opened.push(this)
  }

  addEventListener(type: string, listener: (event: MessageEvent<string>) => void) {
    this.listeners.set(type, [...(this.listeners.get(type) ?? []), listener])
  }

  close() {
    this.closed = true
  }

  emit(type: string, data = '{}') {
    for (const listener of this.listeners.get(type) ?? [])
      listener(new MessageEvent(type, { data }))
  }
}

function tokenOf(source: FakeEventSource | undefined): string | null {
  return source?.url.searchParams.get('token') ?? null
}

function renderLive() {
  const auth = {
    state: { status: 'signed-in' as const, me: {} as AdminMe, permissions: new Set<string>() },
    login: async () => {},
    logout: async () => {},
  }
  return render(
    <QueryClientProvider client={new QueryClient()}>
      <AuthContext value={auth}>
        <LiveProvider>{null}</LiveProvider>
      </AuthContext>
    </QueryClientProvider>,
  )
}

function renewsTo(access: string, refresh: string, counter?: { calls: number }) {
  server.use(
    http.post('*/api/v1/auth/refresh', () => {
      if (counter) counter.calls += 1
      return HttpResponse.json({
        access_token: access,
        refresh_token: refresh,
        token_type: 'bearer',
        expires_in: 900,
        session_id: 's',
      })
    }),
  )
}

beforeEach(() => {
  FakeEventSource.opened = []
  vi.stubGlobal('EventSource', FakeEventSource)
})

afterEach(() => {
  vi.unstubAllGlobals()
})

describe('the live feed', () => {
  it('reconnects with a renewed token when the server ends it', async () => {
    // The server ends the stream once the access token has expired; the
    // dashboard used to stop there and poll for the rest of the session.
    tokenStore.set({ access_token: 'a1', refresh_token: 'r1' })
    renewsTo('a2', 'r2')
    renderLive()
    await waitFor(() => expect(FakeEventSource.opened).toHaveLength(1))
    expect(tokenOf(FakeEventSource.opened[0])).toBe('a1')

    act(() => FakeEventSource.opened[0]?.emit('end', '{"reason": "Token has expired."}'))

    await waitFor(() => expect(FakeEventSource.opened).toHaveLength(2))
    expect(FakeEventSource.opened[0]?.closed).toBe(true)
    expect(tokenOf(FakeEventSource.opened[1])).toBe('a2')
  })

  it('uses a token the requests already renewed, without renewing again', async () => {
    tokenStore.set({ access_token: 'a1', refresh_token: 'r1' })
    const refresh = { calls: 0 }
    renewsTo('a3', 'r3', refresh)
    renderLive()
    await waitFor(() => expect(FakeEventSource.opened).toHaveLength(1))
    tokenStore.set({ access_token: 'a2', refresh_token: 'r2' })

    act(() => FakeEventSource.opened[0]?.emit('end'))

    await waitFor(() => expect(FakeEventSource.opened).toHaveLength(2))
    expect(tokenOf(FakeEventSource.opened[1])).toBe('a2')
    expect(refresh.calls).toBe(0)
  })
})
