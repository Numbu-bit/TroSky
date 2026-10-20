import createClient from 'openapi-fetch'

import { apiOrigin } from '@/lib/env'

import { ApiError } from './errors'
import type { paths } from './schema'
import { tokenStore, type TokenPair } from './tokens'

/** Endpoints that are answered without (or in place of) an access token. */
const UNAUTHENTICATED = ['/api/v1/auth/login', '/api/v1/auth/refresh', '/api/v1/auth/otp-login']

let sessionEnded: () => void = () => {}

/** Called when the session cannot be renewed: the admin must sign in again. */
export function onSessionEnded(listener: () => void): void {
  sessionEnded = listener
}

function authorize(request: Request): Request {
  const token = tokenStore.access
  if (token) request.headers.set('Authorization', `Bearer ${token}`)
  return request
}

/**
 * What came of renewing the session: a new token pair, the end of the
 * session (no refresh token, or the backend refused it), or no answer for
 * now (offline, a server or gateway error, a rate limit), which keeps the
 * tokens for the next attempt.
 */
export type Renewal = 'renewed' | 'ended' | 'unreachable'

let refreshing: Promise<Renewal> | null = null

async function exchange(refreshToken: string): Promise<Renewal> {
  let response: Response
  try {
    response = await globalThis.fetch(`${apiOrigin}/api/v1/auth/refresh`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ refresh_token: refreshToken }),
    })
  } catch {
    return 'unreachable'
  }
  // Only the backend's verdict on the token ends the session: an admin back
  // from a break, or caught by a restart, is not signed out by a 5xx.
  if (response.status >= 500 || response.status === 429) return 'unreachable'
  if (!response.ok) {
    tokenStore.clear()
    return 'ended'
  }
  tokenStore.set((await response.json()) as TokenPair)
  return 'renewed'
}

/**
 * Trade the refresh token for a new pair. Concurrent callers share one
 * request: refresh tokens rotate, and presenting a spent one would look like
 * token theft to the backend and end every session.
 */
export function refreshSession(): Promise<Renewal> {
  if (refreshing) return refreshing
  const refreshToken = tokenStore.refresh
  if (!refreshToken) return Promise.resolve('ended')
  const attempt = exchange(refreshToken)
  refreshing = attempt
  // Cleared only once this attempt settles, and only if it is still the one
  // in flight -- never left holding a finished answer.
  void attempt.finally(() => {
    if (refreshing === attempt) refreshing = null
  })
  return attempt
}

/**
 * In place of a refused request while the session cannot be renewed for now:
 * a 503, which queries retry and the admin reads as "try again", not as
 * being signed out.
 */
function renewalUnavailable(): Response {
  return Response.json(
    {
      error: {
        code: 'SESSION_RENEWAL_UNAVAILABLE',
        message: 'The server could not be reached to renew your session. Try again in a moment.',
        details: {},
      },
    },
    { status: 503 },
  )
}

/**
 * Every API request: the access token attached, and a 401 answered by one
 * refresh and one retry before the session is treated as over.
 */
async function authFetch(request: Request): Promise<Response> {
  const path = new URL(request.url).pathname
  const retryable = !UNAUTHENTICATED.some((open) => path.endsWith(open))
  const retry = retryable ? request.clone() : null
  const response = await globalThis.fetch(authorize(request))
  if (response.status !== 401 || !retry) return response
  const renewal = await refreshSession()
  if (renewal === 'ended') {
    sessionEnded()
    return response
  }
  if (renewal === 'unreachable') return renewalUnavailable()
  return globalThis.fetch(authorize(retry))
}

// Typed from the JSON responses; CSV exports go through downloadFile().
export const api = createClient<paths, 'application/json'>({ baseUrl: apiOrigin, fetch: authFetch })

type Result<T> = { data?: T; error?: unknown; response: Response }

/** The response body, or an ApiError carrying the backend's message. */
export async function unwrap<T>(request: Promise<Result<T>>): Promise<T> {
  const { data, error, response } = await request
  if (error !== undefined || !response.ok) throw ApiError.from(response.status, error)
  return data as T
}

/**
 * Fetch an export (``format=csv``) and hand it to the browser as a file.
 * Uses the same authentication as every other request.
 */
export async function downloadFile(
  path: string,
  params: Record<string, string | number | boolean | undefined | null>,
  filename: string,
): Promise<void> {
  const url = new URL(`${apiOrigin}${path}`, window.location.origin)
  for (const [key, value] of Object.entries(params)) {
    if (value !== undefined && value !== null && value !== '')
      url.searchParams.set(key, String(value))
  }
  const response = await authFetch(new Request(url))
  if (!response.ok) {
    let body: unknown
    try {
      body = await response.json()
    } catch {
      body = undefined
    }
    throw ApiError.from(response.status, body)
  }
  const blob = await response.blob()
  const link = document.createElement('a')
  link.href = URL.createObjectURL(blob)
  link.download = filename
  document.body.append(link)
  link.click()
  link.remove()
  setTimeout(() => URL.revokeObjectURL(link.href), 1000)
}
