/**
 * The backend answers every failure with one envelope:
 * ``{"error": {"code", "message", "details", "request_id"}}``.
 * Its message is written for people, so it is what the admin sees.
 */

interface ErrorEnvelope {
  error: {
    code?: string
    message?: string
    details?: Record<string, unknown>
    request_id?: string
  }
}

const STATUS_MESSAGES: Record<number, string> = {
  400: 'That request could not be processed.',
  401: 'Your session has ended. Sign in again.',
  403: 'You don’t have permission to do that.',
  404: 'That could not be found.',
  409: 'That conflicts with how things stand now. Refresh and try again.',
  422: 'Some of the details are not valid.',
  423: 'This account is locked for now.',
  429: 'Too many requests. Wait a moment and try again.',
  500: 'The server ran into a problem. Try again shortly.',
  502: 'A service the platform depends on did not answer. Try again shortly.',
  503: 'The service is unavailable right now. Try again shortly.',
  504: 'The server took too long to answer. Try again.',
}

function isEnvelope(body: unknown): body is ErrorEnvelope {
  return (
    typeof body === 'object' &&
    body !== null &&
    'error' in body &&
    typeof (body as { error: unknown }).error === 'object' &&
    (body as { error: unknown }).error !== null
  )
}

export class ApiError extends Error {
  readonly status: number
  readonly code: string
  readonly details: Record<string, unknown>
  readonly requestId: string | undefined

  constructor(
    status: number,
    message: string,
    code = 'HTTP_ERROR',
    details: Record<string, unknown> = {},
    requestId?: string,
  ) {
    super(message)
    this.name = 'ApiError'
    this.status = status
    this.code = code
    this.details = details
    this.requestId = requestId
  }

  static from(status: number, body: unknown): ApiError {
    if (isEnvelope(body)) {
      const { code, message, details, request_id } = body.error
      return new ApiError(
        status,
        message || STATUS_MESSAGES[status] || 'Something went wrong.',
        code || 'HTTP_ERROR',
        details ?? {},
        request_id,
      )
    }
    return new ApiError(status, STATUS_MESSAGES[status] ?? `Request failed (${status}).`)
  }
}

export function isApiError(error: unknown, status?: number): error is ApiError {
  return error instanceof ApiError && (status === undefined || error.status === status)
}

/** What to tell the admin about any failure. */
export function errorMessage(error: unknown, fallback = 'Something went wrong.'): string {
  if (error instanceof ApiError) return error.message
  if (error instanceof TypeError)
    return 'Can’t reach the server. Check your connection and try again.'
  if (error instanceof Error && error.message) return error.message
  return fallback
}

/** Field messages from a 422 (``details.errors``), keyed by field name. */
export function fieldErrors(error: unknown): Record<string, string> {
  if (!(error instanceof ApiError) || error.status !== 422) return {}
  const errors = error.details.errors
  if (!Array.isArray(errors)) return {}
  const found: Record<string, string> = {}
  for (const entry of errors) {
    if (typeof entry !== 'object' || entry === null) continue
    const { loc, msg } = entry as { loc?: unknown; msg?: unknown }
    if (!Array.isArray(loc) || typeof msg !== 'string') continue
    const field = loc.filter((part) => part !== 'body' && part !== 'query').join('.')
    if (field && !(field in found)) found[field] = msg
  }
  return found
}
