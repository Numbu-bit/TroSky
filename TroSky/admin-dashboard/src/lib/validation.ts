import { z } from 'zod'

/** Cedis with at most two decimals, as the API takes them ("12.50"). */
export const cedis = z
  .string()
  .trim()
  .min(1, 'Enter an amount.')
  .regex(/^\d{1,10}(\.\d{1,2})?$/, 'Enter an amount in cedis, like 12.50.')

/** Optional text: blank becomes undefined, so it is left out of the request. */
export function optionalText(max: number) {
  return z
    .string()
    .trim()
    .max(max, `At most ${max} characters.`)
    .transform((value) => value || undefined)
}

/** A coordinate typed as text, checked against its range. */
export function coordinate(label: string, limit: number) {
  return z
    .string()
    .trim()
    .min(1, `Enter the ${label}, or click the map.`)
    .refine((value) => {
      const number = Number(value)
      return Number.isFinite(number) && Math.abs(number) <= limit
    }, `The ${label} must be a number between -${limit} and ${limit}.`)
}
