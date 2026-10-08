import type { components, paths } from './schema'

/** Response and request bodies, by their OpenAPI schema name. */
export type Schemas = components['schemas']

export type { paths }

/** The backend's list envelope: ``{items, total, limit, offset}``. */
export interface Page<T> {
  items: T[]
  total: number
  limit: number
  offset: number
}
