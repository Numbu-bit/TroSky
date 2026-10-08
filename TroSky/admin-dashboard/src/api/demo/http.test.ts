import { api } from '@/api/client'

/** The demo answers as the backend would, refusals included. */
describe('the demo API', () => {
  it('refuses pages bigger than the backend allows, as FastAPI does', async () => {
    const { error, response } = await api.GET('/api/v1/stops', {
      params: { query: { limit: 101, offset: 0 } },
    })
    expect(response.status).toBe(422)
    expect(error).toMatchObject({
      error: {
        code: 'VALIDATION_ERROR',
        details: { errors: [{ loc: ['query', 'limit'], msg: expect.stringContaining('100') }] },
      },
    })
  })

  it('refuses a stop search shorter than two characters', async () => {
    const { response, error } = await api.GET('/api/v1/stops', {
      params: { query: { q: 'k', limit: 20 } },
    })
    expect(response.status).toBe(422)
    expect(error).toMatchObject({
      error: { details: { errors: [{ loc: ['query', 'q'] }] } },
    })
  })

  it('searches stops by name only', async () => {
    const { data } = await api.GET('/api/v1/stops', { params: { query: { q: 'ka', limit: 50 } } })
    expect(data?.items.length).toBeGreaterThan(0)
    for (const stop of data!.items) expect(stop.name.toLowerCase()).toContain('ka')
    expect(data?.offset).toBe(0)
  })
})
