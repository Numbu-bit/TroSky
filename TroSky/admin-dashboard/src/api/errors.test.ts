import { ApiError, errorMessage, fieldErrors, isApiError } from './errors'

describe('ApiError', () => {
  it('carries the backend’s envelope', () => {
    const error = ApiError.from(409, {
      error: {
        code: 'SEAT_NOT_AVAILABLE',
        message: 'The selected seat is no longer available.',
        details: { seat_id: 's1' },
        request_id: 'req-1',
      },
    })
    expect(error.status).toBe(409)
    expect(error.code).toBe('SEAT_NOT_AVAILABLE')
    expect(error.message).toBe('The selected seat is no longer available.')
    expect(error.details).toEqual({ seat_id: 's1' })
    expect(error.requestId).toBe('req-1')
    expect(isApiError(error, 409)).toBe(true)
    expect(isApiError(error, 404)).toBe(false)
  })

  it('falls back to a plain message for each status', () => {
    expect(ApiError.from(403, undefined).message).toMatch(/permission/)
    expect(ApiError.from(503, 'Service Unavailable').message).toMatch(/unavailable/)
    expect(ApiError.from(418, null).message).toBe('Request failed (418).')
  })
})

describe('errorMessage', () => {
  it('says what to tell the admin', () => {
    expect(errorMessage(new ApiError(400, 'Nope.'))).toBe('Nope.')
    expect(errorMessage(new TypeError('Failed to fetch'))).toMatch(/connection/)
    expect(errorMessage(new Error('Boom'))).toBe('Boom')
    expect(errorMessage('weird', 'Fallback')).toBe('Fallback')
  })
})

describe('fieldErrors', () => {
  it('maps a 422’s errors to their fields', () => {
    const error = ApiError.from(422, {
      error: {
        code: 'VALIDATION_ERROR',
        message: 'Invalid input.',
        details: {
          errors: [
            { loc: ['body', 'reason'], msg: 'String should have at least 3 characters' },
            { loc: ['body', 'reason'], msg: 'Second message ignored' },
            { loc: ['query', 'limit'], msg: 'Input should be less than 500' },
            { nonsense: true },
          ],
        },
      },
    })
    expect(fieldErrors(error)).toEqual({
      reason: 'String should have at least 3 characters',
      limit: 'Input should be less than 500',
    })
  })

  it('is empty for anything else', () => {
    expect(fieldErrors(new ApiError(400, 'x'))).toEqual({})
    expect(fieldErrors(new Error('x'))).toEqual({})
  })
})
