import { sessionStore } from '@/lib/storage'

/**
 * The backend issues an access token and a rotating refresh token in the
 * response body (no httpOnly cookie). The access token lives in memory
 * only. The refresh token is kept in sessionStorage so a reload of this
 * tab stays signed in; it is gone when the tab closes, and never touches
 * localStorage.
 */
const REFRESH_KEY = 'trosky-admin:refresh-token'

let accessToken: string | null = null

export interface TokenPair {
  access_token: string
  refresh_token: string
}

export const tokenStore = {
  get access(): string | null {
    return accessToken
  },
  get refresh(): string | null {
    return sessionStore.get(REFRESH_KEY)
  },
  set(pair: TokenPair): void {
    accessToken = pair.access_token
    sessionStore.set(REFRESH_KEY, pair.refresh_token)
  },
  clear(): void {
    accessToken = null
    sessionStore.remove(REFRESH_KEY)
  },
}
