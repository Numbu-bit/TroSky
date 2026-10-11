import type { Schemas } from '@/api/types'

import {
  accountByIdentifier,
  DEMO_PASSWORD,
  onTeam,
  recordSignIn,
  type DemoAccount,
} from '../accounts'
import { endpoint, errorResponse, issueTokens, notFound, readRefreshToken } from '../http'

interface DemoSession {
  id: string
  accountId: string
  device: string
  userAgent: string
  ip: string
  createdAt: string
  lastSeenAt: string
}

let sessions: DemoSession[] = []
let sessionSerial = 0

/** Earlier devices, so "Where I'm signed in" has something to show. */
function seedSessions(account: DemoAccount): void {
  if (sessions.some((session) => session.accountId === account.id)) return
  const day = 86_400_000
  sessions.push({
    id: `5e55a000-0000-4000-8000-${account.id.slice(-6)}000001`,
    accountId: account.id,
    device: 'Samsung Galaxy A54',
    userAgent: 'Mozilla/5.0 (Linux; Android 14; SM-A546E) Chrome/129.0 Mobile',
    ip: '102.176.65.14',
    createdAt: new Date(Date.now() - 6 * day).toISOString(),
    lastSeenAt: new Date(Date.now() - 2 * day).toISOString(),
  })
}

function newSession(account: DemoAccount, userAgent: string): DemoSession {
  sessionSerial += 1
  const now = new Date().toISOString()
  const session: DemoSession = {
    id: `5e55a000-0000-4000-8000-${String(sessionSerial).padStart(12, '0')}`,
    accountId: account.id,
    device: /Mobile/.test(userAgent) ? 'Mobile browser' : 'Desktop browser',
    userAgent,
    ip: '41.215.162.8',
    createdAt: now,
    lastSeenAt: now,
  }
  sessions.push(session)
  return session
}

/** Tests start from a clean slate. */
export function resetDemoSessions(): void {
  sessions = []
  sessionSerial = 0
}

export const authHandlers = [
  endpoint.post('/auth/login', 'public', ({ body, request }) => {
    const { identifier = '', password = '' } = (body ?? {}) as {
      identifier?: string
      password?: string
    }
    const account = accountByIdentifier(identifier)
    if (!account || password !== DEMO_PASSWORD) {
      return errorResponse(401, 'INVALID_CREDENTIALS', 'The provided credentials are incorrect.')
    }
    seedSessions(account)
    const session = newSession(account, request.headers.get('User-Agent') ?? 'Browser')
    recordSignIn(account.id)
    return issueTokens(account, session.id) satisfies Schemas['TokenPairResponse']
  }),

  endpoint.post('/auth/refresh', 'public', ({ body, request }) => {
    const token = (body as { refresh_token?: string } | undefined)?.refresh_token
    const parsed = readRefreshToken(token)
    if (!parsed) {
      return errorResponse(401, 'TOKEN_INVALID', 'Your session has expired. Sign in again.')
    }
    // The demo server lives in the page, so a reload forgets its sessions:
    // a valid token for a known account picks its session up again.
    let session = sessions.find((candidate) => candidate.id === parsed.sessionId)
    if (!session) {
      session = newSession(parsed.account, request.headers.get('User-Agent') ?? 'Browser')
      session.id = parsed.sessionId
    }
    session.lastSeenAt = new Date().toISOString()
    return issueTokens(parsed.account, session.id) satisfies Schemas['TokenPairResponse']
  }),

  endpoint.post('/auth/logout', 'team', ({ sessionId }) => {
    sessions = sessions.filter((session) => session.id !== sessionId)
  }),

  endpoint.get('/admin/me', 'team', ({ admin }) =>
    onTeam(admin.id)
      ? ({
          id: admin.id,
          full_name: admin.full_name,
          phone_number: admin.phone_number,
          email: admin.email,
          role: admin.role,
          permissions: [...admin.permissions].sort(),
        } satisfies Schemas['AdminMeResponse'])
      : errorResponse(403, 'FORBIDDEN', 'You are not on the admin team.'),
  ),

  endpoint.get('/admin/me/sessions', 'team', ({ admin, sessionId }): Schemas['SessionResponse'][] =>
    sessions
      .filter((session) => session.accountId === admin.id)
      .sort((a, b) => b.lastSeenAt.localeCompare(a.lastSeenAt))
      .map((session) => ({
        id: session.id,
        device_name: session.device,
        ip_address: session.ip,
        user_agent: session.userAgent,
        created_at: session.createdAt,
        last_seen_at: session.lastSeenAt,
        is_current: session.id === sessionId,
      })),
  ),

  endpoint.delete('/admin/me/sessions/:sessionId', 'team', ({ admin, params }) => {
    const found = sessions.find(
      (session) => session.id === params.sessionId && session.accountId === admin.id,
    )
    if (!found) return notFound('Session not found.')
    sessions = sessions.filter((session) => session !== found)
  }),
]
