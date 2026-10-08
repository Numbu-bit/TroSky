import { setupServer } from 'msw/node'

import { resetDemoTeam } from '@/api/demo/accounts'
import { resetDemoDb } from '@/api/demo/db'
import { resetDemoSessions } from '@/api/demo/handlers/auth'
import { handlers } from '@/api/demo/handlers'

/** The demo API, for tests: the same handlers demo mode uses. */
export const server = setupServer(...handlers)

export function resetDemo(): void {
  resetDemoSessions()
  resetDemoDb()
  resetDemoTeam()
}
