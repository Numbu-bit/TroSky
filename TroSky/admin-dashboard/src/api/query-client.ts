import { QueryClient } from '@tanstack/react-query'

import { ApiError } from './errors'

export function createQueryClient(): QueryClient {
  return new QueryClient({
    defaultOptions: {
      queries: {
        staleTime: 20_000,
        gcTime: 5 * 60_000,
        // A 4xx will not change on retry; network and 5xx failures might.
        retry: (failures, error) =>
          !(error instanceof ApiError && error.status >= 400 && error.status < 500) && failures < 2,
        refetchOnWindowFocus: true,
      },
      mutations: { retry: false },
    },
  })
}
