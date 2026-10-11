import { delay, http, HttpResponse, type JsonBodyType } from 'msw'

import { hasAny, type Permission } from '@/lib/permissions'

import { accountById, type DemoAccount } from './accounts'
import { demoConfig } from './config'
import { beginAudit } from './db/audit'

/** Matches the API path on any origin (dev proxy, absolute base, tests). */
export function apiPath(path: string): string {
  return `*/api/v1${path}`
}

let requestSerial = 0

export function errorResponse(
  status: number,
  code: string,
  message: string,
  details: Record<string, unknown> = {},
): Response {
  requestSerial += 1
  return HttpResponse.json(
    { error: { code, message, details, request_id: `demo-${requestSerial.toString(36)}` } },
    { status },
  )
}

export const noContent = (): Response => new HttpResponse(null, { status: 204 })

async function latency(): Promise<void> {
  const [min, max] = demoConfig.latency
  if (max > 0) await delay(min + Math.random() * (max - min))
}

// ------------------------------------------------------------------ tokens
const ACCESS = 'demo-access'
const REFRESH = 'demo-refresh'

export function issueTokens(account: DemoAccount, sessionId: string) {
  const nonce = Math.random().toString(36).slice(2, 10)
  return {
    access_token: `${ACCESS}.${account.id}.${sessionId}.${nonce}`,
    refresh_token: `${REFRESH}.${account.id}.${sessionId}.${nonce}`,
    token_type: 'bearer',
    expires_in: 900,
    session_id: sessionId,
  }
}

function parseToken(token: string | null | undefined, kind: string) {
  if (!token) return null
  const [prefix, accountId, sessionId] = token.split('.')
  if (prefix !== kind || !accountId || !sessionId) return null
  const account = accountById(accountId)
  return account ? { account, sessionId } : null
}

export function readRefreshToken(token: string | null | undefined) {
  return parseToken(token, REFRESH)
}

function signedIn(request: Request) {
  const header = request.headers.get('Authorization') ?? ''
  return parseToken(header.replace(/^Bearer\s+/i, ''), ACCESS)
}

// --------------------------------------------------------------- handlers
export interface Context {
  request: Request
  url: URL
  params: Record<string, string>
  admin: DemoAccount
  sessionId: string
  /** The JSON body, for POST/PATCH (undefined when there is none). */
  body: unknown
}

/** Who may call it: listed permissions (any one), any admin, or anyone. */
export type Access = readonly Permission[] | 'team' | 'public'

type Answer = JsonBodyType | Response | undefined | void

function handle(
  access: Access,
  resolve: (context: Context) => Answer | Promise<Answer>,
  pattern: string,
) {
  return async ({ request, params }: { request: Request; params: Record<string, unknown> }) => {
    await latency()
    if (demoConfig.failRequests && access !== 'public') {
      return errorResponse(
        503,
        'DEMO_FAILURE',
        'Demo: requests are set to fail. Turn this off in the demo menu.',
      )
    }
    const session = signedIn(request)
    if (access !== 'public') {
      if (!session) return errorResponse(401, 'UNAUTHORIZED', 'Not authenticated.')
      if (access !== 'team' && !hasAny(new Set(session.account.permissions), access)) {
        return errorResponse(
          403,
          'FORBIDDEN',
          'This action requires a permission your account does not have.',
        )
      }
    }
    let body: unknown
    if (request.method !== 'GET' && request.method !== 'DELETE') {
      const text = await request.text()
      body = text ? JSON.parse(text) : undefined
    }
    const values = Object.fromEntries(
      Object.entries(params).map(([key, value]) => [key, String(value)]),
    )
    // Admin changes go in the audit trail, as the backend records them.
    const audited =
      request.method !== 'GET' && pattern.startsWith('/admin') && !pattern.startsWith('/admin/me')
    const audit = audited ? beginAudit(request.method, pattern, values) : null
    let answer: Answer
    try {
      answer = await resolve({
        request,
        url: new URL(request.url),
        params: values,
        admin: session?.account as DemoAccount,
        sessionId: session?.sessionId ?? '',
        body,
      })
      if (audit && session && (!(answer instanceof Response) || answer.ok)) {
        audit.finish(session.account.id, body)
      }
    } catch (error) {
      if (!(error instanceof QueryError)) throw error
      return errorResponse(422, 'VALIDATION_ERROR', 'The submitted data is invalid.', {
        errors: [{ loc: ['query', error.field], msg: error.message, type: 'value_error' }],
      })
    }
    if (answer instanceof Response) return answer
    if (answer === undefined) return noContent()
    return HttpResponse.json(answer)
  }
}

export const endpoint = {
  get: (path: string, access: Access, resolve: (context: Context) => Answer | Promise<Answer>) =>
    http.get(apiPath(path), handle(access, resolve, path)),
  post: (path: string, access: Access, resolve: (context: Context) => Answer | Promise<Answer>) =>
    http.post(apiPath(path), handle(access, resolve, path)),
  patch: (path: string, access: Access, resolve: (context: Context) => Answer | Promise<Answer>) =>
    http.patch(apiPath(path), handle(access, resolve, path)),
  delete: (path: string, access: Access, resolve: (context: Context) => Answer | Promise<Answer>) =>
    http.delete(apiPath(path), handle(access, resolve, path)),
}

// ------------------------------------------------------------------ lists
/** A query parameter the backend would refuse: answered with its 422. */
export class QueryError extends Error {
  constructor(
    readonly field: string,
    message: string,
  ) {
    super(message)
  }
}

/** ``limit`` and ``offset``, refused past the backend's cap (100 for most lists). */
export function pageParams(url: URL, defaultLimit = 20, maxLimit = 100) {
  const limit = Number(url.searchParams.get('limit') ?? defaultLimit)
  const offset = Number(url.searchParams.get('offset') ?? 0)
  if (!Number.isInteger(limit) || limit < 1) {
    throw new QueryError('limit', 'Input should be greater than or equal to 1')
  }
  if (limit > maxLimit) {
    throw new QueryError('limit', `Input should be less than or equal to ${maxLimit}`)
  }
  if (!Number.isInteger(offset) || offset < 0) {
    throw new QueryError('offset', 'Input should be greater than or equal to 0')
  }
  return { limit, offset }
}

/** The backend's list envelope, for ``items`` already filtered and sorted. */
export function paginate<T>(items: T[], url: URL, defaultLimit = 20, maxLimit = 100) {
  const { limit, offset } = pageParams(url, defaultLimit, maxLimit)
  return { items: items.slice(offset, offset + limit), total: items.length, limit, offset }
}

/** ``format=csv``: the rows as a CSV attachment, as the backend sends them. */
export function csvAnswer(rows: Record<string, unknown>[], name: string): Response {
  const columns = [...new Set(rows.flatMap((row) => Object.keys(row)))]
  const cell = (value: unknown) => {
    const text =
      value === null || value === undefined
        ? ''
        : typeof value === 'object'
          ? JSON.stringify(value)
          : String(value)
    return /[",\n]/.test(text) ? `"${text.replace(/"/g, '""')}"` : text
  }
  const lines = [
    columns.join(','),
    ...rows.map((row) => columns.map((key) => cell(row[key])).join(',')),
  ]
  return new HttpResponse(lines.join('\n'), {
    headers: {
      'Content-Type': 'text/csv; charset=utf-8',
      'Content-Disposition': `attachment; filename="${name}.csv"`,
    },
  })
}

export function notFound(what = 'Not found.'): Response {
  return errorResponse(404, 'NOT_FOUND', what)
}

export function conflict(code: string, message: string, details: Record<string, unknown> = {}) {
  return errorResponse(409, code, message, details)
}
